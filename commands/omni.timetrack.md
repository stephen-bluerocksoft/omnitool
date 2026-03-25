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

4. **Check for merged PRs** in the current repo:

   ```sh
   gh pr list --state merged --search "merged:>=<start-date>" --json number,title,mergedAt,url --limit 50
   ```

   If `gh` is not available or fails, skip this step gracefully.

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

   - Include these in the timetrack entry under their own `### <Repo Name>` heading.

8. **Identify themes**. Group commits (from all repos) into logical work areas:
   - New features
   - Bug fixes
   - Infrastructure / DevOps
   - Documentation
   - Refactoring / cleanup
   - Testing

### Phase 3: Generate the Entry

9. **Write the timetrack entry** using this format:

   ```markdown
   ## YYYY-MM-DD (Day of Week)

   ### <Repo or Project Name>

   **<Theme 1: concise title>**
   - <1-2 sentence summary of what was delivered and why it matters>

   **<Theme 2: concise title>**
   - <1-2 sentence summary of what was delivered and why it matters>

   ### <Other Repo Name> (if applicable)

   **<Theme>**
   - <summary>
   ```

   Guidelines:
   - **Audience is upper management** -- focus on outcomes and business value, not implementation details
   - Group related commits into a single bullet rather than listing each commit
   - Use plain language; avoid jargon (no "enum", "migration", "dependency injection")
   - Lead with the *what* and *why*, not the *how*
   - Mention merged PRs by number where relevant
   - If multiple days are in the range, use a separate `## YYYY-MM-DD` section for each day
   - Use a separate `### <Repo Name>` section for each repository with activity
   - Do NOT fabricate work -- only describe what is in the actual commit history

10. **Present the entry in a fenced code block** so the user can copy it:

    ````
    ```markdown
    <the timetrack entry>
    ```
    ````

11. **If no commits exist** for the date range (local or cross-repo), report that clearly and suggest checking a different date.

## Important Rules

- **Never fabricate work** -- all content must come from the actual git history.
- **Keep it concise** -- each theme should be 1-3 sentences, not paragraphs.
- **Management-friendly language** -- translate technical changes into business outcomes.
- **Respect date boundaries** -- only include commits within the requested range.
- **Include PR references** -- mention PR numbers when a merge occurred.
