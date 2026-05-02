---
description: Generate a timetrack entry summarizing today's work for upper management
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may specify a date range, a specific date, a project filter, or a desired level of detail.

## Outline

### Phase 1: Determine Date Range

1. **Parse date from user input**. If `$ARGUMENTS` contains a date or date range, use it. Otherwise default to **today** (current calendar date).

2. **Resolve the date(s)** into `--since` / `--until` flags for git log. Examples:

   - "today" → `--since="YYYY-MM-DDT00:00:00" --until="YYYY-MM-DDT23:59:59"` (today's date)
   - "yesterday" → same pattern, one day back
   - "this week" → Monday of current week through today
   - "2026-02-15" → that specific day
   - "2026-02-10 to 2026-02-14" → that range

### Phase 2: Gather Context (Current Repo)

3. **Collect local commits**. Run in parallel:

   ```sh
   git log --since="<start>" --until="<end>" --all --format="%ai %h %s%n%b---" --reverse
   git log --since="<start>" --until="<end>" --all --stat --format="%h %s" --reverse
   ```

4. **Check for merged PRs** in the current repo (metadata for attribution, not just listing):

   ```sh
   gh pr list --state merged --search "merged:>=<start-date>" --json number,title,mergedAt,url,author,mergedBy,reviews --limit 50
   ```

   For **each PR** you might mention in the timetrack, resolve the user's role before writing copy. When in doubt, use `gh pr view <number> --json author,mergedBy,reviews,commits` for the current repo, or `gh pr view <number> -R owner/repo --json ...` for other repositories, or the Pulls API. You need whether the authenticated user **authored**, **merged**, **reviewed** (submitted review), or only has **commits** on the branch.

   If `gh` is not available or fails, rely on commit authorship only and **do not** imply PR merges the user did not author or merge.

4b. **Attribution rules for PRs** (prevents reviewing others' work from reading as your delivery):

   | Evidence | How to phrase (plain text) |
   | -------- | -------------------------- |
   | User is PR **author** (or their commits are the substantive change) | Delivery language is OK: what shipped, outcomes, "in PR #N" if helpful. |
   | User **reviewed** (appears in `reviews`) but is **not** the author | **Must** lead with review role: e.g. "Code review on PR #N:" or "Reviewed PR #N (repo name):" then summarize **what the PR changes** without implying you wrote it. Do **not** use "Merged PR #N to..." for review-only work. |
   | User is **mergedBy** but **not** author | Say **merged** or **integrated** and name that it came from another contributor/team if known (e.g. "Merged PR #N from contributor X ..." or "Integrated PR #N ..."). Do not describe the feature work as if you implemented it unless your commits are in that PR. |
   | PR merged in range but user's only tie is review | Same as review row: explicit **review** framing only. |

   **Anti-pattern to avoid**: Phrases like "Merged PR 45 to strengthen CI..." when the user's role was **reviewer** -- that reads as you shipped the change. Replace with review-first wording and, where useful, a short nod to authorship ("author's PR", "contributor PR", or the author's login if appropriate for your audience).

### Phase 2b: Gather Context (All Repos)

5. **Discover the authenticated GitHub username**:

   ```sh
   gh api user --jq '.login'
   ```

6. **Search for commits across all repos** using the GitHub Search API. Use the committer-date qualifier to match the date range:

   ```sh
   gh api "search/commits?q=author:<username>+committer-date:<start-date>..<end-date>&sort=committer-date&per_page=100" \
     --jq '.items[] | "\(.repository.full_name) | \(.sha[:7]) | \(.commit.message | split("\n")[0])"'
   ```

   - This returns commits from **all repositories** the user has pushed to (public and private repos the token can access).
   - For a single day, the date qualifier is `committer-date:YYYY-MM-DD`.
   - For a range, use `committer-date:YYYY-MM-DD..YYYY-MM-DD`.

7. **Identify other repos with activity**. Compare the cross-repo results against the current repo name. For any *other* repos that appear:

   - Fetch their commit details for richer context:

     ```sh
     gh api "search/commits?q=author:<username>+repo:<owner>/<repo>+committer-date:<date-range>&per_page=100" \
       --jq '.items[] | "\(.sha[:7]) \(.commit.message)"'
     ```

   - Include these in the timetrack entry under their own repo heading line (plain text; see Phase 3).

8. **Identify themes**. Group commits (from all repos) into logical work areas:

   - New features
   - Bug fixes
   - Infrastructure / DevOps
   - Documentation
   - Refactoring / cleanup
   - Testing

### Phase 3: Generate the Entry (plain-text output only)

The user pastes the timetrack into a system that **does not support markdown**. The **deliverable** must be plain text: no `#` headings, no `**bold**`, no backticks, no markdown lists other than lines starting with `-` and a space.

9. **Determine the day of week** for each date using a shell command -- do NOT attempt to calculate it mentally:

   ```sh
   date -j -f "%Y-%m-%d" "YYYY-MM-DD" "+%A"
   ```

10. **Write the timetrack entry** using this structure:

   - First line: `YYYY-MM-DD (Day of Week)` (using the shell-verified day name from step 9)
   - Blank line, then a repo or project name as a single line (ALL CAPS or Title Case is fine).
   - Blank line, then each **theme** as a short title line (plain text only).
   - Under each theme, one or more lines starting with `-` and a space (1-2 sentences each).
   - Repeat for other repos. For multiple days in range, repeat the date line and sections per day.

   Example shape (illustrative; the real output must match this plain-text style):

   ```text
   2026-04-06 (Monday)

   my-org/current-repo

   Customer reporting improvements
   - Shipped clearer export flow so ops can close month without manual spreadsheets.

   Bug fixes
   - Resolved timeout errors affecting morning batch runs.

   other-org/other-repo

   Documentation
   - Updated runbooks for the handoff to the support team.
   ```

   Guidelines:

   - **Audience is upper management** -- focus on outcomes and business value, not implementation details
   - Group related commits into a single bullet rather than listing each commit
   - Use plain language; avoid jargon (no "enum", "migration", "dependency injection")
   - Lead with the *what* and *why*, not the *how*
   - When referencing a PR, **match language to role** (see step 4b): reviewed vs authored vs merged-by-you. Never describe reviewed-only PRs as your own merge or implementation.
   - Mention PR numbers where relevant, with correct attribution
   - Do NOT fabricate work -- only describe what is in the actual commit history and PR metadata

11. **Present the timetrack** inside a single markdown code fence (` ```text `) so the user can copy the literal text with dashes intact. Cursor renders bare `-` lines as markdown bullets, which strips the dash on copy-paste. A code block preserves the characters exactly and provides a one-click copy button.

12. **If no commits exist** for the date range (local or cross-repo), report that clearly and suggest checking a different date.

## Important Rules

- **Never fabricate work** -- all content must come from the actual git history.
- **Keep it concise** -- each theme should be 1-3 sentences, not paragraphs.
- **Management-friendly language** -- translate technical changes into business outcomes.
- **Respect date boundaries** -- only include commits within the requested range.
- **Include PR references** -- mention PR numbers when relevant, with **correct attribution** (review vs author vs merger per step 4b).
