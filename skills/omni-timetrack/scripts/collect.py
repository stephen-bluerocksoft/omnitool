#!/usr/bin/env python3
"""Collect one person's work activity for a date range into a single events file.

GitHub's commit search indexes only each repository's default branch, so a
timetrack built from it alone misses work merged into another branch, work on
open pull request branches, and work never pushed, and it dates a squash merge
by the day someone merged it. This collector joins every source that records
the work -- commit search, pull request branches, reviews, comments, issues,
local clones on every branch, and Claude Code session transcripts -- and
buckets each event into a day in the person's own timezone.

Writes two files to --out:
  events.tsv     one row per event: date, time, kind, repo, ref, title, detail
  coverage.txt   which sources ran, what each found or why it failed, and the
                 gaps the summary must disclose

Uses only the standard library, plus the gh and git command-line tools.

Usage:
  collect.py --since 2026-10-01 --until 2026-10-31 --tz America/Los_Angeles \\
             --out /path/to/dir [--root ~/Work --root ~] [--email a@example.com]
"""

import argparse
import collections
import concurrent.futures
import datetime as dt
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from zoneinfo import ZoneInfo

GH_TIMEOUT = 60
GIT_TIMEOUT = 120
SEARCH_PAUSE = 2.5  # the search API allows 30 requests a minute
SEARCH_CAP = 1000  # the search API returns at most this many results per query
SKIP_DIRS = {"node_modules", "venv", "__pycache__", "dist", "build"}
SQUASH_SUFFIX = re.compile(r"\(#(\d+)\)$")
MERGE_SUBJECT = re.compile(r"^Merge pull request #(\d+) from ")

Event = tuple[str, str, str, str, str, str, str]
Thread = tuple[str, int, bool, str, str, str, str]


class GhError(RuntimeError):
    """A gh call failed after its retries."""


def gh_json(args: list[str], retries: int = 4) -> object:
    """Run `gh api` and return parsed JSON, backing off on rate limits."""
    for attempt in range(retries):
        proc = subprocess.run(  # noqa: S603 -- fixed gh binary, argument list never passes through a shell
            ["gh", "api", *args],  # noqa: S607 -- gh is resolved from PATH like any CLI the skill runs
            capture_output=True,
            text=True,
            timeout=GH_TIMEOUT,
        )
        if proc.returncode == 0:
            return json.loads(proc.stdout or "null")
        err = proc.stderr.strip()
        if "rate limit" in err.lower() and attempt < retries - 1:
            # Not polling: GitHub asks clients to wait out a secondary rate limit.
            time.sleep(60 * (attempt + 1))
            continue
        raise GhError(err.splitlines()[-1] if err else f"gh api {args[0]} failed")
    raise GhError(f"gh api {args[0]} still rate limited after {retries} attempts")


def rest_list(path: str) -> list[dict]:
    """Fetch every page of a REST list endpoint."""
    items: list[dict] = []
    page = 1
    sep = "&" if "?" in path else "?"
    while True:
        batch = gh_json([f"{path}{sep}per_page=100&page={page}"])
        items.extend(batch)
        if len(batch) < 100:
            return items
        page += 1


def search(kind: str, query: str, field: str, start: dt.date, end: dt.date) -> list[dict]:
    """Search GitHub over [start, end], splitting the range when it passes the result cap."""

    def page(number: int) -> dict:
        result = gh_json(
            [
                "-X",
                "GET",
                f"search/{kind}",
                "-f",
                f"q={query} {field}:{start}..{end}",
                "-F",
                "per_page=100",
                "-F",
                f"page={number}",
            ]
        )
        time.sleep(SEARCH_PAUSE)
        return result

    first = page(1)
    if first["total_count"] > SEARCH_CAP and start < end:
        mid = start + (end - start) / 2
        return search(kind, query, field, start, mid) + search(kind, query, field, mid + dt.timedelta(days=1), end)
    items = list(first["items"])
    number = 1
    while len(items) < min(first["total_count"], SEARCH_CAP):
        number += 1
        batch = page(number)["items"]
        if not batch:
            break
        items.extend(batch)
    return items


def git(repo: Path | str, *args: str) -> str:
    """Run git in a repository and return stdout; a timeout is reported like any other git failure."""
    try:
        proc = subprocess.run(  # noqa: S603 -- fixed git binary, argument list never passes through a shell
            ["git", "-C", str(repo), *args],  # noqa: S607 -- git is resolved from PATH like any CLI the skill runs
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"git {args[0]} timed out after {GIT_TIMEOUT}s in {repo}") from exc
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"git {args[0]} failed in {repo}")
    return proc.stdout


def main_clone(path: Path) -> Path:
    """Return the main clone for a clone or worktree, whose refs every worktree shares."""
    return Path(git(path, "rev-parse", "--path-format=absolute", "--git-common-dir").strip()).parent


def remote_name(repo: Path) -> str:
    """Return owner/name for a clone's origin, or a local label when it has none."""
    try:
        url = git(repo, "remote", "get-url", "origin").strip()
    except RuntimeError:
        return f"local:{repo.name}"
    match = re.search(r"[:/]([^/:]+/[^/]+?)(?:\.git)?$", url)
    return match.group(1) if match else url


class Collector:
    """Gathers events from every source and records what each source covered."""

    def __init__(self, args: argparse.Namespace) -> None:
        self.tz = ZoneInfo(args.tz)
        self.since = dt.date.fromisoformat(args.since)
        self.until = dt.date.fromisoformat(args.until)
        self.start = dt.datetime.combine(self.since, dt.time.min, self.tz)
        self.end = dt.datetime.combine(self.until + dt.timedelta(days=1), dt.time.min, self.tz)
        # Searches run on UTC days, so start one day early and keep only local-day matches.
        # They end today: work done in the range is often committed, rebased or merged after it.
        self.search_start = self.since - dt.timedelta(days=1)
        self.today = dt.date.today()
        self.roots = [Path(r).expanduser() for r in args.root]
        self.depth = args.depth
        self.transcripts = not args.no_transcripts
        self.login = ""
        self.emails = {e.lower() for e in args.email}
        self.events: list[Event] = []
        self.coverage: list[str] = []
        self.commits: dict[tuple[str, str, int], dict] = {}  # (repo, subject, author epoch) -> commit
        self.prs: set[tuple[str, int]] = set()
        self.squashes: set[tuple[str, int]] = set()
        self.threads: dict[str, set[Thread]] = collections.defaultdict(set)
        self.offsets: collections.Counter[str] = collections.Counter()

    # ---- helpers -------------------------------------------------------------

    def local(self, stamp: str | float) -> dt.datetime:
        """Convert an ISO timestamp or epoch seconds to an aware datetime in the chosen timezone."""
        if isinstance(stamp, (int, float)):
            return dt.datetime.fromtimestamp(stamp, self.tz)
        return dt.datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone(self.tz)

    def emit(self, moment: dt.datetime, kind: str, repo: str, ref: str, title: str, detail: str = "") -> None:
        """Add an event when it falls inside the range."""
        if self.start <= moment < self.end:
            title, detail = (v.replace("\t", " ").replace("\n", " ") for v in (title, detail))
            self.events.append((f"{moment:%Y-%m-%d}", f"{moment:%H:%M}", kind, repo, ref, title, detail))

    def note(self, source: str, status: str, detail: str) -> None:
        """Record what a source covered for coverage.txt."""
        self.coverage.append(f"{source:<22} {status:<8} {detail}")

    def add_commit(self, repo: str, sha: str, epoch: float, subject: str, source: str, pushed: bool = True) -> None:
        """Record a commit once, however many sources and rebased copies report it."""
        record = self.commits.setdefault(
            (repo, subject, int(epoch)),
            {"repo": repo, "sha": sha[:9], "epoch": epoch, "subject": subject, "sources": set(), "pushed": False},
        )
        record["sources"].add(source)
        record["pushed"] = record["pushed"] or pushed

    # ---- sources ---------------------------------------------------------------

    def identity(self) -> None:
        """Find the GitHub login and every email the person commits under."""
        user = gh_json(["user"])
        self.login = user["login"]
        self.emails.add(f"{user['id']}+{self.login}@users.noreply.github.com".lower())
        self.emails.add(f"{self.login}@users.noreply.github.com".lower())
        configured = subprocess.run(
            ["git", "config", "--global", "user.email"],  # noqa: S607 -- git is resolved from PATH
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT,
        )
        if configured.stdout.strip():
            self.emails.add(configured.stdout.strip().lower())
        self.note("identity", "ok", f"login {self.login}; emails {', '.join(sorted(self.emails))}")

    def commit_search(self) -> None:
        """Commits on default branches, with squash merges set aside to be dated by their PR."""
        items = search("commits", f"author:{self.login}", "committer-date", self.search_start, self.today)
        for item in items:
            commit = item["commit"]
            subject = commit["message"].split("\n", 1)[0]
            repo = item["repository"]["full_name"]
            squash = SQUASH_SUFFIX.search(subject)
            if squash and commit["committer"]["name"] == "GitHub":
                self.squashes.add((repo, int(squash.group(1))))
                continue
            self.add_commit(repo, item["sha"], self.local(commit["author"]["date"]).timestamp(), subject, "search")
        self.note(
            "commit search",
            "ok",
            f"{len(items)} commits on default branches, {len(self.squashes)} of "
            "them squash merges dated by their pull request's own commits instead",
        )

    def thread_search(self) -> None:
        """Pull requests and issues the person authored, reviewed or commented on, in any repository."""
        queries = {
            "authored": (f"author:{self.login} type:pr", "updated"),
            "reviewed": (f"reviewed-by:{self.login} type:pr", "updated"),
            "commented": (f"commenter:{self.login}", "updated"),
            "issues": (f"author:{self.login} type:issue", "created"),
        }
        for label, (query, field) in queries.items():
            items = search("issues", query, field, self.search_start, self.today)
            for item in items:
                repo = "/".join(item["repository_url"].split("/")[-2:])
                self.threads[label].add(
                    (
                        repo,
                        item["number"],
                        "pull_request" in item,
                        item["user"]["login"],
                        item["title"],
                        item["created_at"],
                        item["state"],
                    )
                )
            self.note(f"search: {label}", "ok", f"{len(items)} threads")
        for repo, number, _, _, title, created, state in self.threads["issues"]:
            self.emit(self.local(created), "issue-filed", repo, f"#{number}", title, f"state={state}")

    def pull_requests(self) -> None:
        """Read each pull request's own commits, reviews and merge."""
        wanted = {
            (r, n)
            for label in ("authored", "reviewed", "commented")
            for r, n, is_pr, *_ in self.threads[label]
            if is_pr
        }
        wanted |= self.squashes
        failures = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            futures = {pool.submit(self.read_pull, r, n): (r, n) for r, n in sorted(wanted)}
            for future in concurrent.futures.as_completed(futures):
                try:
                    future.result()
                except GhError as exc:
                    failures.append(f"{futures[future][0]}#{futures[future][1]}: {exc}")
        unmatched = [f"{r}#{n}" for r, n in self.squashes if (r, n) not in self.prs]
        self.note(
            "pull requests",
            "partial" if failures or unmatched else "ok",
            f"{len(self.prs)} read with commits and reviews"
            + (f"; failed: {'; '.join(failures)}" if failures else "")
            + (f"; squash merges whose PR could not be read: {', '.join(unmatched)}" if unmatched else ""),
        )

    def read_pull(self, repo: str, number: int) -> None:
        """Turn one pull request into opened, merged, review and commit events."""
        pull = gh_json([f"repos/{repo}/pulls/{number}"])
        author = pull["user"]["login"]
        mine = author == self.login
        base = pull["base"]["ref"]
        if mine:
            self.emit(
                self.local(pull["created_at"]),
                "pr-opened",
                repo,
                f"#{number}",
                pull["title"],
                f"base={base} state={pull['state']}",
            )
            for c in rest_list(f"repos/{repo}/pulls/{number}/commits"):
                login = (c.get("author") or {}).get("login")
                if login == self.login or c["commit"]["author"]["email"].lower() in self.emails:
                    self.add_commit(
                        repo,
                        c["sha"],
                        self.local(c["commit"]["author"]["date"]).timestamp(),
                        c["commit"]["message"].split("\n", 1)[0],
                        f"pr#{number}",
                    )
        merger = (pull.get("merged_by") or {}).get("login", "")
        if pull.get("merged_at") and (mine or merger == self.login):
            self.emit(
                self.local(pull["merged_at"]),
                "pr-merged",
                repo,
                f"#{number}",
                pull["title"],
                f"author={author} merged_by={merger} base={base}",
            )
        if not mine:
            self.emit_reviews(repo, number, pull["title"], author)
        self.prs.add((repo, number))

    def emit_reviews(self, repo: str, number: int, title: str, author: str) -> None:
        """One review event per pull request per day: each inline comment is its own submission."""
        days: dict[str, list] = collections.defaultdict(list)
        for review in rest_list(f"repos/{repo}/pulls/{number}/reviews"):
            if (review.get("user") or {}).get("login") == self.login and review.get("submitted_at"):
                moment = self.local(review["submitted_at"])
                days[f"{moment:%Y-%m-%d}"].append((moment, review["state"]))
        for submissions in days.values():
            states = collections.Counter(state for _, state in submissions)
            verdicts = " ".join(f"{state}x{count}" for state, count in sorted(states.items()))
            self.emit(min(submissions)[0], "review", repo, f"#{number}", title, f"author={author} {verdicts}")

    def comments(self) -> None:
        """The person's own comments, dated individually, on every thread they commented on."""
        since = self.start.astimezone(dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
        count, failures = 0, []
        for repo, number, is_pr, author, title, *_ in sorted(self.threads["commented"]):
            try:
                rows = rest_list(f"repos/{repo}/issues/{number}/comments?since={since}")
            except GhError as exc:
                failures.append(f"{repo}#{number}: {exc}")
                continue
            for row in rows:
                if (row.get("user") or {}).get("login") == self.login:
                    self.emit(
                        self.local(row["created_at"]),
                        "pr-comment" if is_pr else "issue-comment",
                        repo,
                        f"#{number}",
                        title,
                        f"author={author}",
                    )
                    count += 1
        self.note(
            "comments",
            "partial" if failures else "ok",
            f"{count} comments in {len(self.threads['commented'])} threads"
            + (f"; failed: {'; '.join(failures)}" if failures else ""),
        )

    def find_clones(self) -> list[Path]:
        """Find clones under each root, without descending into a clone's own tree."""
        found: set[Path] = set()
        for root in self.roots:
            for path, dirs, files in os.walk(root):
                current = Path(path)
                if ".git" in dirs or ".git" in files:
                    found.add(current)
                    dirs[:] = []
                elif len(current.relative_to(root).parts) >= self.depth:
                    dirs[:] = []
                else:
                    dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith(".")]
        mains = set()
        for clone in found:
            try:
                mains.add(main_clone(clone))
            except RuntimeError:
                continue
        return sorted(mains)

    def local_clones(self) -> None:
        """Every branch of every clone, marking commits that are on no remote."""
        clones = self.find_clones()
        # git filters on committer date, which a rebase moves later but never earlier than the author date.
        since = (self.start - dt.timedelta(days=1)).isoformat()
        authors = [f"--author={e}" for e in sorted(self.emails)]
        unpushed_total, dirty, failed, unchecked = 0, [], [], []
        for clone in clones:
            repo = remote_name(clone)
            try:
                unpushed = set(git(clone, "rev-list", "--all", "--not", "--remotes").split())
                log = git(clone, "log", "--all", *authors, f"--since={since}", "--format=%H%x09%at%x09%ai%x09%cn%x09%s")
                trees = [
                    line.split(" ", 1)[1]
                    for line in git(clone, "worktree", "list", "--porcelain").splitlines()
                    if line.startswith("worktree ")
                ]
            except RuntimeError as exc:
                failed.append(f"{clone}: {exc}")
                continue
            for line in log.splitlines():
                sha, epoch, iso, committer, subject = line.split("\t", 4)
                squash = SQUASH_SUFFIX.search(subject)
                if squash and committer == "GitHub":
                    self.squashes.add((repo, int(squash.group(1))))  # dated by its pull request instead
                    continue
                self.offsets[iso.rsplit(" ", 1)[-1]] += 1
                pushed = sha not in unpushed
                unpushed_total += not pushed
                self.add_commit(repo, sha, int(epoch), subject, "local", pushed=pushed)
            dirty.extend(self.dirty_trees(repo, trees, unchecked))
        self.note(
            "local clones",
            "partial" if failed else "ok",
            f"{len(clones)} clones under {', '.join(map(str, self.roots))}; {unpushed_total} commits on no "
            "remote, judged from each clone's last fetch" + (f"; failed: {'; '.join(failed)}" if failed else ""),
        )
        if dirty:
            self.note("uncommitted changes", "found", "; ".join(dirty))
        if unchecked:
            self.note("uncommitted changes", "partial", "could not check: " + "; ".join(unchecked))

    def dirty_trees(self, repo: str, trees: list[str], unchecked: list[str]) -> list[str]:
        """Name the worktrees that hold uncommitted changes, adding any that could not be checked to unchecked."""
        dirty = []
        for tree in trees:
            try:
                # Tracked files only: scanning untracked files in a large tree can take minutes.
                if git(tree, "status", "--porcelain", "--untracked-files=no").strip():
                    dirty.append(f"{repo} ({git(tree, 'branch', '--show-current').strip() or 'detached'}) at {tree}")
            except RuntimeError as exc:
                unchecked.append(str(exc))  # a deleted worktree folder, or one too large to scan in time
        return dirty

    def sessions(self) -> None:
        """Claude Code sessions per day and repository: counts and branches, never prompt text."""
        base = Path("~/.claude/projects").expanduser()
        if not self.transcripts or not base.is_dir():
            self.note(
                "transcripts",
                "skipped",
                "disabled by --no-transcripts" if not self.transcripts else f"{base} not found",
            )
            return
        repo_of: dict[str, str] = {}
        days: dict[tuple[str, str], dict] = collections.defaultdict(
            lambda: {"sessions": set(), "prompts": 0, "branches": set(), "first": None, "last": None}
        )
        for transcript in base.glob("*/*.jsonl"):  # top-level sessions only; subagent files nest deeper
            if dt.datetime.fromtimestamp(transcript.stat().st_mtime, self.tz) < self.start:
                continue
            for row in self.user_rows(transcript):
                moment = self.local(row["timestamp"])
                if not self.start <= moment < self.end:
                    continue
                cwd = row["cwd"]
                if cwd not in repo_of:
                    repo_of[cwd] = self.repo_for_path(Path(cwd))
                day = days[(f"{moment:%Y-%m-%d}", repo_of[cwd])]
                day["sessions"].add(row.get("sessionId"))
                # Transcript rows are external data: a typed prompt is a string, a tool result a list.
                day["prompts"] += isinstance((row.get("message") or {}).get("content"), str)
                if row.get("gitBranch"):
                    day["branches"].add(row["gitBranch"])
                day["first"] = moment if day["first"] is None else min(day["first"], moment)
                day["last"] = moment if day["last"] is None else max(day["last"], moment)
        for (_, repo), day in days.items():
            self.emit(
                day["first"],
                "session",
                repo,
                f"{len(day['sessions'])} sessions",
                "branches: " + (", ".join(sorted(day["branches"])) or "none"),
                f"prompts={day['prompts']} span={day['first']:%H:%M}-{day['last']:%H:%M}",
            )
        self.note("transcripts", "ok", f"{len(days)} repo-days of Claude Code sessions (repo and branch only)")

    def user_rows(self, transcript: Path) -> list[dict]:
        """Read the user rows of one transcript, skipping lines that are not JSON."""
        rows = []
        with transcript.open(errors="replace") as handle:
            for line in handle:
                if '"type":"user"' not in line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue  # a line cut short by a session that was killed mid-write
                if row.get("timestamp") and row.get("cwd"):
                    rows.append(row)
        return rows

    def repo_for_path(self, path: Path) -> str:
        """Map a session's working folder to the repository it belongs to."""
        for candidate in (path, *path.parents):
            if (candidate / ".git").exists():
                try:
                    return remote_name(main_clone(candidate))
                except RuntimeError:
                    return f"local:{candidate.name}"
        return f"folder:{path}"

    # ---- output ---------------------------------------------------------------

    def finish(self, out: Path) -> None:
        """Write events.tsv and coverage.txt."""
        for record in self.commits.values():
            merge = MERGE_SUBJECT.match(record["subject"])
            if merge and (record["repo"], int(merge.group(1))) in self.prs:
                continue  # the pr-merged event already records this merge, with who merged it
            kind = "merge-commit" if merge else ("commit" if record["pushed"] else "commit-unpushed")
            self.emit(
                self.local(record["epoch"]),
                kind,
                record["repo"],
                record["sha"],
                record["subject"],
                "sources=" + ",".join(sorted(record["sources"])),
            )
        self.events.sort()
        out.mkdir(parents=True, exist_ok=True)
        with (out / "events.tsv").open("w") as handle:
            handle.write("date\ttime\tkind\trepo\tref\ttitle\tdetail\n")
            handle.writelines("\t".join(row) + "\n" for row in self.events)
        active = {row[0] for row in self.events}
        span = (self.until - self.since).days + 1
        empty = [
            f"{d:%Y-%m-%d (%A)}"
            for d in (self.since + dt.timedelta(days=i) for i in range(span))
            if f"{d:%Y-%m-%d}" not in active
        ]
        kinds = collections.Counter(row[2] for row in self.events)
        offsets = ", ".join(f"{k} x{v}" for k, v in self.offsets.most_common()) or "none"
        lines = [
            f"Range {self.since} to {self.until}, bucketed in {self.tz.key}",
            f"Timezone offsets on the person's local commits: {offsets}",
            "",
            *self.coverage,
            "",
            "Events by kind: " + ", ".join(f"{k}={v}" for k, v in sorted(kinds.items())),
            "Days with no events: " + (", ".join(empty) or "none"),
            "Not covered: repositories with no local clone, pull request or issue in the range; "
            "Slack, email, meetings and other work outside git and GitHub.",
        ]
        (out / "coverage.txt").write_text("\n".join(lines) + "\n")


def main() -> None:
    """Parse arguments, run every source, and write the output files."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--since", required=True, help="first day, YYYY-MM-DD")
    parser.add_argument("--until", required=True, help="last day, YYYY-MM-DD (inclusive)")
    parser.add_argument("--tz", required=True, help="IANA timezone to bucket days in, e.g. America/Los_Angeles")
    parser.add_argument("--out", required=True, help="directory for events.tsv and coverage.txt")
    parser.add_argument("--root", action="append", default=[], help="folder to search for clones (repeatable)")
    parser.add_argument("--depth", type=int, default=4, help="how many folders deep to search each root")
    parser.add_argument("--email", action="append", default=[], help="extra commit author email (repeatable)")
    parser.add_argument("--no-transcripts", action="store_true", help="skip Claude Code session transcripts")
    args = parser.parse_args()
    args.root = args.root or ["~"]

    collector = Collector(args)
    collector.identity()
    steps = [
        ("commit search", collector.commit_search),
        ("issue and PR search", collector.thread_search),
        ("local clones", collector.local_clones),  # before pull requests: it finds squash merges to date
        ("pull requests", collector.pull_requests),
        ("comments", collector.comments),
        ("transcripts", collector.sessions),
    ]
    for name, step in steps:
        print(f"collecting: {name}", file=sys.stderr)
        try:
            step()
        except (GhError, RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
            # Record the gap and keep going: the summary must say what it could not see.
            collector.note(name, "FAILED", str(exc))
    collector.finish(Path(args.out))
    sys.stdout.write((Path(args.out) / "coverage.txt").read_text())


if __name__ == "__main__":
    main()
