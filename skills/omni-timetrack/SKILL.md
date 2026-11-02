---
name: omni-timetrack
description: Generate a timetrack entry summarizing work for upper management, for one day or any date range, across every repository, branch, pull request, review and issue the person touched. Use when reporting daily, weekly or monthly work to management.
---

## Outline

The work is in more places than any one source shows. GitHub's commit search covers only each repository's default branch, so on its own it misses:

- repositories that merge into another branch, such as `dev`
- open pull request branches
- work that was never pushed
- issues filed and comments
- the real dates behind squash merges, which it dates by the day someone merged them

`scripts/collect.py` joins every source into one events file. This skill runs it, adds Slack where it is connected, and writes the summary.

### Phase 1: Determine the range and timezone

1. **Parse the date or range** from the user's message. Default to **today**. Resolve phrases into first and last days, inclusive:

   - "today", "yesterday" -- that one day
   - "this week" -- Monday of the current week through today
   - "October", "last month" -- the first through the last day of that month
   - "2026-02-10 to 2026-02-14" -- that range

2. **Settle the timezone** the days are counted in. Machines often run on UTC while the person works elsewhere, and a wrong timezone moves late-evening work to the next day.

   - Use a timezone the user named.
   - Otherwise read the system timezone (`timedatectl show -p Timezone --value`, or `readlink /etc/localtime` on macOS).
   - If it is UTC, or unknown, compare it with the offsets on the person's recent commits (`git log -20 --format=%ai` in any of their clones). If they disagree, ask the user which timezone to use, as an IANA name such as `America/Los_Angeles`.

### Phase 2: Collect

3. **Run the collector** from this skill's directory. It takes a few minutes for a month, because GitHub's search API allows 30 requests a minute. Run it in the background when the range is longer than a week.

   ```sh
   python3 -I <skill-dir>/scripts/collect.py --since <first-day> --until <last-day> \
     --tz <timezone> --out <scratch-dir>/timetrack --root ~/Work --root ~
   ```

   - `--root` names folders to search for clones, four levels deep by default (`--depth`). Pass the folders where the person keeps repositories; the default is the home folder.
   - `--email` adds a commit email the person uses that is not their global `git config user.email`.
   - `--no-transcripts` skips Claude Code session transcripts if the user asks.

   It needs `gh` (signed in) and `git`, and Python 3.11 or newer.

4. **Read `coverage.txt` first.**
   - Every source is listed as `ok`, `partial`, `FAILED` or `skipped`, with the reason. A `FAILED` or `partial` source is a gap to report to the user, never one to fill by guessing.
   - Check that the timezone offsets seen on local commits match the chosen timezone. If they don't, return to step 2.

5. **Read `events.tsv`.** It has one row per event, with these columns: `date`, `time`, `kind`, `repo`, `ref`, `title`, `detail`. For ranges longer than a week, read it one week at a time (for example `awk -F'\t' '$1 >= "2026-10-01" && $1 <= "2026-10-07"'`). The kinds:

   | Kind | What it is | Dated by |
   | ---- | ---------- | -------- |
   | `commit` | A commit by the person that is on a remote, from any branch | When it was written (author date) |
   | `commit-unpushed` | A commit that exists only in a local clone | When it was written |
   | `merge-commit` | A merge commit by the person with no matching pull request record | When it was made |
   | `pr-opened` | A pull request the person opened; `detail` gives its base branch and state | When it was opened |
   | `pr-merged` | A pull request that landed; `detail` names its author and who merged it | When it merged |
   | `review` | A review the person submitted on someone else's pull request; `detail` gives the author and the verdict | When it was submitted |
   | `pr-comment`, `issue-comment` | A comment by the person; `detail` names the thread's author | When it was posted |
   | `issue-filed` | An issue the person opened | When it was opened |
   | `session` | A day's Claude Code sessions in one repository: session count, branches, typed prompts, time span | The first message that day |

   The collector has already removed duplicate copies left by rebases, and leaves out commits by bots and by other people. A squash merge appears as a `pr-merged` event on its merge day, while its own commits carry the days the work was done.

6. **Search Slack** when a Slack search tool is available. Search for the person's own messages in the range (`from:<their user id>` with `after:`/`before:` or `during:`). Use them only for coordination and decisions that leave no GitHub record: a blocking issue raised with the team, a plan shared, a question settled. Summarize; never quote direct messages. If no Slack tool is connected, say so in the coverage note.

### Phase 3: Attribute

7. **Match the wording to the person's role** before writing about any pull request:

   | Evidence | How to phrase (plain text) |
   | -------- | -------------------------- |
   | The person is the PR author, or their commits are the substantive change | Delivery language is OK: what shipped, outcomes, "in PR #N" if helpful. |
   | A `review` or `pr-comment` event, and the person is not the author | **Must** lead with the review role: "Code review on PR #N:" or "Reviewed PR #N (repo name):", then summarize what the PR changes without implying the person wrote it. Never "Merged PR #N to..." for review-only work. |
   | `pr-merged` where `merged_by` is the person and `author` is not | Say **merged** or **integrated**, and name the contributor when known. Do not describe the feature as the person's work unless their commits are in that PR. |
   | `pr-merged` where `author` is the person and `merged_by` is someone else | The work is the person's; on the merge day it **landed** ("PR #N landed"). Describe the work itself on the days its commits were written. |

   **Anti-pattern to avoid**: phrases like "Merged PR 45 to strengthen CI..." when the person's role was reviewer. That reads as if they shipped the change.

8. **Weigh the softer evidence.**
   - **`session` rows:** a session shows work happened in a repository on a branch, never that something shipped. Use one to describe a day's focus only where commits, pull requests or reviews don't already cover it. Phrase it as work in progress ("Worked on the sign-up epic"), taking the topic from the branch name.
   - **`commit-unpushed` rows:** describe them normally, and mark them "(local, not yet pushed)".
   - **`issue-filed` rows:** summarize by count and theme per repository ("Filed 12 core-agent issues covering email trigger and ingest gaps"), not one line per issue.
   - **Comments:** fold comments into the review or discussion they belong to.

9. **Group into themes** per repository and day: new features, bug fixes, infrastructure and DevOps, documentation, refactoring and cleanup, testing, code review, issues and planning, coordination.

### Phase 4: Write the entry (plain-text output only)

The user pastes the timetrack into a system that **does not support markdown**. The **deliverable** must be plain text: no `#` headings, no `**bold**`, no backticks, no markdown lists other than lines starting with `-` and a space.

10. **Get the day of the week** for each date with a shell command; do NOT calculate it mentally. GNU `date` (Linux) takes `-d`; BSD `date` (macOS) does not, so fall back to its `-j -f` form:

    ```sh
    date -d "YYYY-MM-DD" "+%A" 2>/dev/null || date -j -f "%Y-%m-%d" "YYYY-MM-DD" "+%A"
    ```

11. **Write the timetrack entry** using this structure:

    - First line: `YYYY-MM-DD (Day of Week)`, using the day name from step 10.
    - Blank line, then a repository name as a single line.
    - Blank line, then each **theme** as a short title line.
    - Under each theme, one or more lines starting with `-` and a space, 1-2 sentences each.
    - Repeat for other repositories, then for each day in the range.
    - **Every day in the range gets an entry.** A day with no events is the date line followed by `- No recorded activity.` (`coverage.txt` lists those days).

    Example shape (illustrative; the real output must match this plain-text style):

    ```text
    2026-04-06 (Monday)

    my-org/current-repo

    Customer reporting improvements
    - Shipped clearer export flow so ops can close month without manual spreadsheets.

    Code review
    - Reviewed PR #42 from a contributor (faster nightly imports) and requested changes.

    other-org/other-repo

    Issues and planning
    - Filed 5 issues covering gaps found in the onboarding flow.

    2026-04-07 (Tuesday)

    - No recorded activity.
    ```

    Guidelines:

    - **Audience is upper management** -- focus on outcomes and business value, not implementation details
    - Group related commits into a single bullet rather than listing each commit
    - Use plain language; avoid jargon (no "enum", "migration", "dependency injection")
    - Lead with the *what* and *why*, not the *how*
    - Mention PR numbers where relevant, with the attribution from step 7
    - Do NOT fabricate work -- describe only what the events and Slack messages show

12. **Present the timetrack** inside a single markdown code fence (` ```text `) so the user can copy the literal text with dashes intact. Markdown renderers turn bare `-` lines into bullets, which strips the dash on copy-paste; a code block keeps the characters exactly and provides a one-click copy button.

13. **After the code fence, give a short coverage note** to the user, outside the copied text:
    - the timezone used
    - each source that failed, was partial or was skipped, including Slack
    - unpushed work and uncommitted changes the collector found
    - what no source covers: repositories with no local clone, pull request or issue in the range; email; meetings

## Important Rules

- **Never fabricate work** -- every line traces to an event or a Slack message.
- **Keep it concise** -- each theme should be 1-3 sentences, not paragraphs.
- **Management-friendly language** -- translate technical changes into business outcomes.
- **Respect date boundaries** -- the collector buckets by the chosen timezone; never move an event to another day.
- **Correct attribution** -- review, authorship and merging are worded per step 7.
- **Transcripts stay private** -- the collector reads only repository, branch and timing from them, never prompt text, because sessions can contain client data.
