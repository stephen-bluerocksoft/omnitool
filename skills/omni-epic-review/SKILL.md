---
name: omni-epic-review
description: Review the code a devbot epic run produced, one workplan unit at a time. Slices the epic branch back into its units (from manifest.yaml and the specs/<slug>/ paths each commit touches), dispatches one full brs-review per slice in a worktree at that slice's own commit, re-verifies every finding against the branch head, adds one bounded cross-cutting pass, and prints a single report -- every surviving finding listed, with a per-unit sizing table and severity tally -- saved to temp/ as well. Use on an epic branch before opening its pull request, or on any branch too large for one review -- phrases like "review this epic", "review the epic branch unit by unit", "this PR is too big to review". Text only; never posts to GitHub. Not the pre-launch plan audit (that is /devbot-review) and not a single-change review (use brs-review).
compatibility: Requires brs-review (BRS Codex) installed at ~/.claude/skills/brs-review, and git 2.17+ (worktree add/remove)
---

# omni.epic.review

A devbot epic runs on one branch and lands as one pull request, and an epic-sized diff -- six units, 244 files, 30,000 lines -- is past what any single reviewer can hold, whether a review bot or a person. This skill reviews the branch the way a reviewer works through a stack of unit-sized pull requests: it slices the branch back into the workplan units the run built, dispatches one full `brs-review` per slice in a worktree checked out at that slice's own commit, re-verifies every finding against the branch head so nothing a later unit already fixed is reported, adds one bounded cross-cutting pass for what slicing cannot see, and prints one report.

**Confirm before dispatching.** The slice plan is the cost: one full `brs-review` per slice plus one cross-cutting pass, each its own subagent. Print the plan (Step 2) and confirm the user wants to spend that now. Skip this confirmation only when the user explicitly invoked `/omni-epic-review`.

**Text only.** The deliverable is the report, printed in the terminal and saved to one gitignored file, `temp/epic-review-<head-short>.md`, so it survives scrollback, context compaction, and a fix session started fresh. This skill never posts to GitHub, never runs `gh`, never commits, and never changes a tracked file. The worktrees it creates under `temp/` are removed before it ends.

**Once.** `brs-review` documents that repeated runs sample different judgment-based findings rather than converging, and every slice here inherits that. Run this skill once, fix the Must Fix findings, and stop.

## Runtime note

This skill drives **`brs-review`** (BRS Codex, `~/.claude/skills/brs-review/SKILL.md`) through subagents. That skill's six phases, confidence scoring, and 7/10 reporting threshold are what every slice gets. This skill adds the slicing, the worktrees, the HEAD verification, and the cross-cutting pass; it changes nothing about how a slice is judged.

Where it sits:

```text
/devbot-plan -> /devbot-review -> /devbot-launch -> run -> [this skill] -> fix -> /omni-pr-create
```

Not `/devbot-review`: that audits the plan before launch. This reviews the code after the run. Not `brs-review` on the whole branch either: that is the single-diff review this skill exists to avoid.

**Base branch**: throughout this skill, `<base>` means the repository's main integration branch. Detect it once and reuse it everywhere: try `git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p'`, and if that is empty fall back to whichever of `main` or `master` exists (`git rev-parse --verify main` / `git rev-parse --verify master`).

## Automation Safety

This skill is model-invocable. A session is **non-interactive** whenever nobody is there to answer a question -- an unattended runner, a scheduled job, a cloud trigger.

- **Never commit, push, tag, or run `gh`.** Every subagent dispatch restates this.
- **The plan confirmation is the only routine question**, and it is governed by the gate above: an explicit `/omni-epic-review` invocation is the answer. Every other choice has a non-interactive branch named in the step that makes it (manifest ambiguity falls back to per-commit slicing and says so in the report; a dirty tree is a precondition failure, not a question; an existing report for the same head stops the run).
- **Worktrees are removed on every exit path** -- after the report, after a precondition failure in Step 3 or later, and after a subagent failure. Step 1 also prunes leftovers from an earlier run that did not get that far.
- **Nothing leaves the machine.**

## Step 1: Gate and resolve

1. `git branch --show-current`. If it prints `main` or `master`, **STOP**: this skill reviews an epic branch. Record the name as `<branch>`.
2. `git status --porcelain --untracked-files=no`. Any output means tracked files carry uncommitted changes that belong to no slice, and Step 4's "still true at HEAD" check would be ambiguous against them. **STOP** and tell the user to commit or stash first. Untracked files are fine; they are in no diff.
3. `ls ~/.claude/skills/brs-review/SKILL.md ~/.claude/skills/brs-review/references/cross-cutting.md`. Either missing: **STOP** and tell the user to install BRS Codex (`make install` in its repo). Do not substitute a hand-rolled review.
4. Detect `<base>` (Runtime note). Record `<head>` as `git rev-parse HEAD` and `<merge-base>` as `git merge-base <base> HEAD`. If `git rev-list --count <merge-base>..HEAD` is 0, there is nothing to review; say so and stop.
5. Prune leftovers: `git worktree prune`, then if `temp/epic-review/` exists, `git worktree remove --force` each subdirectory that is still a worktree and delete the rest.
6. `git check-ignore -q temp || echo "temp/ is not gitignored"`. Continue either way; if it is not ignored, Step 7 skips the report file and the report says so. Then `ls temp/epic-review-<head-short>.md`: if a report for this exact head already exists, this branch state was already reviewed (see **Once**) -- say so and point at the file. Interactively, ask whether to review again anyway; non-interactively, stop.
7. Locate the epic manifest, in this order, and stop at the first hit:
   - The invocation names a manifest path or an epic slug -- use that path, or `<docs-root>/<slug>/manifest.yaml`.
   - `grep -n "devbot program conventions" CLAUDE.md AGENTS.md 2>/dev/null` names the epic docs root; list `<docs-root>/*/manifest.yaml`.
   - Otherwise list `docs/epics/*/manifest.yaml`.

   Among the candidates, prefer the one whose `devbot.runs[].branch` equals `<branch>`; else a single candidate; else, interactively, ask which; non-interactively, use none. With no manifest, slicing falls back to per-commit (references/slicing.md) and the report says so.
8. From the manifest read `epic:` and every `units[]` entry: `id`, `summary`, `speckit` (a spec slug or `null`). These are the labels the slicer maps commits onto.

## Step 2: Build and print the slice plan

Read [references/slicing.md](references/slicing.md) and follow it exactly. It walks `<merge-base>..HEAD` in order, maps each commit to a unit by the `specs/<slug>/` paths it touches (and, second, by the slug or unit id in its message), merges consecutive commits of one unit into one slice, groups the rest as cross-cutting, and sizes each slice on total and on code lines.

Print the plan:

```text
Slice plan: <branch> (base <base>, N commits, M slices)

#  Slice          Unit  Spec                   Commits           Files  +Lines  Code files  Code +lines  Note
1  docs-only      --    --                     b0c4763..7e82841      6    1266           0            0
2  U1             U1    025-intake-foundation  ce18ef7              45    5061          32         3664
7  U6             U6    030-intake-ui          86d4b82              67    7493          54         5864  OVER BUDGET
8  cross-cutting  --    --                     d0c69e8..43ddfbc    128    3605          50         2094  15 commits

Cost: M slice reviews + 1 cross-cutting pass = M+1 subagents.
```

Then apply the confirmation gate from the top of this skill. Oversized slices are reviewed, not split: a split inside a unit reintroduces the half-a-feature false positives slicing exists to avoid. They are flagged here and in the report.

## Step 3: Review each slice (subagents, in parallel)

For every slice create a detached worktree at its end commit:

```sh
git worktree add --detach temp/epic-review/<slice-id> <end-sha>
```

Then dispatch one subagent per slice. All slices are independent -- dispatch them together so they run concurrently. Each dispatch prompt is the **dispatch contract** below plus the slice's task.

### Dispatch contract

Every subagent prompt in Steps 3 and 5 includes this preamble verbatim:

> Invoke the `brs-review` skill through the Skill tool and follow it exactly. If the skill is not available to you, read `~/.claude/skills/brs-review/SKILL.md` and follow it verbatim -- never paraphrase it or substitute your own methodology. You are read-only: change no file, create no commit, run no `gh`. Never ask a question; if something is undecidable, say so in your output and continue. Return the skill's complete output verbatim -- every finding with its file, line, severity, confidence score, issue, and proposed fix, plus the Checklist and Verdict sections.

### Slice task

> Work in `<absolute worktree path>`, a detached worktree at `<end-sha>`; `git branch --show-current` prints nothing there, so do not use it or brs-review's default branch detection. Review the commit range `<start-sha>..<end-sha>` using brs-review's explicit base-ref mode: the base ref is `<start-sha>` -- use it directly, do not detect one. This range is unit `<id>` of the `<epic>` epic: "`<summary>`". Its governing specification is `specs/<slug>/` in the worktree -- read it as the intended behavior. Cite every finding as `path:line` relative to the worktree root.

For a cross-cutting or docs-only slice, replace the unit sentence with: "This range is the `<label>` slice of the `<epic>` epic -- commits that belong to no single unit (`git log <start-sha>..<end-sha> --oneline` lists them). There is no single governing spec; the specs under `specs/` that the diff touches apply."

Collect every slice's output. A subagent that fails or returns nothing is recorded as an unreviewed slice in the report -- never re-dispatched silently, never filled in by the orchestrator reviewing that slice itself.

**Wait for everything before reporting.** Do not write the Step 7 report until every subagent from Steps 3 and 5 has returned and every background command you started (a test run you kicked off to settle a caveat, for example) has exited. A report written while work is still in flight is buried by the completion notices that arrive after it, and anything it lists as "not run" may be stale by the time it is read.

## Step 4: Verify every finding against HEAD

A slice was reviewed at its own commit, so a reviewer of an early unit cannot see the fix a later unit or the preflight pass already landed. Every finding must be re-established against the real branch head before it is reported. The orchestrator does this; when a slice returned more than about fifteen findings, dispatch one verify subagent for that slice with the same instructions (read-only, no questions).

For each finding cited at `path:line` in slice S (end commit `<end-sha>`):

1. `git diff --quiet <end-sha> HEAD -- <path>`. Exit 0 means the file is byte-identical at HEAD: keep the finding, line number unchanged.
2. Otherwise, `git cat-file -e HEAD:<path>` failing means the file is gone: drop it, count it as resolved in-branch.
3. Otherwise read the HEAD version of the file and locate the cited code by its content, not its old line number. Re-articulate the issue against what is there now. If it still holds at 7/10 or above, keep it with the HEAD line number; if not, drop it and count it as resolved in-branch. A finding you cannot re-establish against HEAD is not reported.

Findings without a single location (a missing test, a missing migration) are re-checked the same way against HEAD's tree -- grep for the test, list the migrations.

Then dedupe across slices: two slices that flag the same issue at the same HEAD location keep the earlier slice's finding only.

## Step 5: Cross-cutting pass (one subagent at HEAD)

Slicing loses exactly what `brs-review`'s Phase 4 exists for -- checks that need the whole changeset in view. One subagent at HEAD runs those checks and nothing else. Prompt: the dispatch contract, then:

> Work in `<repository root>` on branch `<branch>` at `<head>`. The base ref is `<base>` -- use it directly. This branch is the `<epic>` epic, already reviewed slice by slice; the slices were: `<the plan table>`. Do NOT perform a full brs-review of this diff. Apply exactly the checks in `~/.claude/skills/brs-review/references/cross-cutting.md` over `git diff <base>...HEAD`, working from `--name-only`, `--stat`, and targeted reads -- do not read the full diff. Add one seam check: for each function, class, endpoint, or type that one slice's diff introduces and a later slice's diff imports or calls, verify the contract at that seam (argument shapes, return types, error types, nullability). Score each finding 1-10 as brs-review defines and report only 7 and above, in brs-review's finding format, cited as `path:line` at HEAD.

These findings are already at HEAD and skip Step 4, but they are deduped against the slice findings the same way.

## Step 6: Remove the worktrees

```sh
git worktree remove --force temp/epic-review/<slice-id>   # each slice
git worktree prune
rmdir temp/epic-review 2>/dev/null
```

This runs before the report is written, and on any exit after Step 3 began.

## Step 7: Report

**Tone**: direct and terse, as `brs-review` specifies. State what is wrong, where, and what to do. No praise, no description of what was checked; silence on a topic means it passed. Every location is `path:line` **at HEAD**, so the reader can open it on the checked-out branch.

**Every surviving finding is listed.** Terse applies to each entry, never to the list. Every finding that survived Step 4 and the dedupe -- from every slice and from the cross-cutting pass -- appears as its own entry under its slice, Minor included. Do not filter, sample, regroup by theme, or collapse findings into a count; a recommendation of which to fix first is never a substitute for the list. Before printing, count the entries: the number must equal the Summary's K and the Tally's total. If they differ, the report is wrong -- fix it before printing.

```text
Epic review: <epic> on <branch> (base <base>, <head-short>)

Summary
  <1-2 sentences: N commits in M slices, K findings after HEAD verification, verdict.>

Sizing
  #  Slice          Unit  Commits  Files  +Lines  Code files  Code +lines  Note
  1  docs-only      --          2      6    1266           0            0
  2  U1             U1          1     45    5061          32         3664
  7  U6             U6          1     67    7493          54         5864  OVER BUDGET -- split next time
  8  cross-cutting  --         15    128    3605          50         2094

Tally
  Slice          Blocker  Critical  Major  Minor
  U1                   0         1      3      2
  U6                   0         0      4      1
  Cross-cutting        0         0      1      4
  Total                0         1      8      7

Findings by slice
  ## U1 -- 025-intake-foundation
  [Critical] path/to/file.py:164 (9/10) -- <issue>. Fix: <proposed fix>
  [Major] path/to/other.py:397 (8/10) -- <issue>. Fix: <proposed fix>
  ...

  ## U6 -- 030-intake-ui
  ...

  ## Cross-cutting
  <Step 5 findings, same entry format>

Suggested order
  <optional: which entries to fix first and why, citing them by path:line>

Not reviewed
  <slices whose subagent failed, or "none">

Resolved in-branch: <count> findings dropped because a later slice fixed them.

Verdict: CHANGES NEEDED | PASS
```

Within a slice, order entries Blocker, Critical, Major, Minor. An entry may run past one line when the failure scenario needs it, but each finding is exactly one entry. Omit any section that would be empty except Sizing, Tally, and Verdict. The verdict follows `brs-review`'s rule -- **CHANGES NEEDED** when any Blocker or Critical finding survived Step 4, otherwise **PASS** -- and is advice to the author, never a GitHub review state.

Close with three lines: fix the Must Fix findings, then `/omni-pr-create`; where the report was saved; and, when any slice was over budget, that the sizing table is input for the next `/devbot-review` -- a unit that produced an over-budget slice should be two units.

**Save the report.** Write the exact report you printed to `temp/epic-review-<head-short>.md`. It sits directly in `temp/`, not under `temp/epic-review/`, which Step 6 removes. If Step 1 found `temp/` not gitignored, skip the file and say in the closing lines that the report was not saved and why -- an unignored report is one `git add` away from a commit. Never delete an earlier run's report; the head in each filename marks which branch state it describes.

**After the report.** The report is the last substantial message. If a notification arrives afterward (a subagent follow-up, a late message), answer it in one line -- whether it changes any finding, and if so, which -- and point back at the saved report. Do not re-summarize the review in chat; a restatement pushes the report out of view and drifts from the file.

## Do not

- Do not review the branch as one diff, and do not let a subagent do it "for completeness". The slice is the unit of review.
- Do not split an oversized slice. Flag it.
- Do not re-dispatch a failed slice silently, and do not review it in the orchestrator's own context. Report it as not reviewed.
- Do not report a finding you could not re-establish at HEAD.
- Do not report findings by count or theme in place of listing them. A number in the Summary with fewer entries under it is an incomplete report.
- Do not write the report while a subagent or background command is still running.
- Do not run this skill twice on the same branch state.
- Do not post, comment, commit, push, or run `gh`.
