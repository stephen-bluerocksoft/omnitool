---
name: omni-commit
description: Group changes into conventional commits, propose them for approval, and commit what is approved. Use when ready to commit staged or unstaged changes.
disable-model-invocation: true
---

## Permissions

All git commands that modify repository state (add, commit, reset, etc.) require write permissions. Read-only commands (status, log, diff, show, blame) do not.

## Context

This command is the end-to-end implementation of the Commit Proposals rule in the user rules, which is always loaded. That rule defines what a proposal must contain and what has to be flagged in it; this outline adds the grouping and execution procedure around it. Follow both -- do not restate the rule here.

Commits are **permanent history by default**. Whether `/omni-compact` will rewrite them later is not something this command can verify, and the two ways of guessing wrong are not equally cheap: a body written on a branch that gets compacted costs a few discarded lines, while a subject-only commit that turns out to be permanent loses the "why" for good.

If the user's message includes `checkpoint`, the branch will be compacted before PR and a clear subject line is enough. That is a hint about the message, not a different procedure: every phase below still runs, unchanged.

## Outline

### Phase 1: Gather Context

1. **Identify chat-modified files**: Check if any files were modified, created, or edited during the current chat session. These are the **priority files** for committing. If the user provided specific files or guidance in their input, use that as the primary scope.

2. **Run read-only git commands** to understand the full repository state. Read the diffs themselves, not just the stat -- what you recall editing and what is in the tree diverge after any non-trivial session:

   ```sh
   git status --porcelain
   git diff
   git diff --cached
   ```

3. **Determine commit scope**:
   - **If chat-modified files exist**: Focus commits on those files first. Only include other changed files if they are directly related (e.g., a test file for a modified source file, or a lockfile updated by a dependency change).
   - **If no chat-modified files**: Analyze ALL modified/untracked files from `git status` and group them logically.

   Narrowing the scope never shrinks the proposal. Every changed file you do not commit is listed under **Not included** in Phase 3 with the reason.

### Phase 2: Analyze and Group Changes

4. **Read the diffs** for all files in scope:

   ```sh
   git diff -- <file>           # For unstaged changes
   git diff --cached -- <file>  # For staged changes
   ```

   For untracked files, read their contents to understand their purpose.

5. **Group changes into logical commits**. Each group should represent a single coherent change. Grouping criteria:

   | Signal | Grouping Logic |
   | ------ | -------------- |
   | Same feature/component | Files that implement the same feature together |
   | Same change type | All doc updates, all test additions, all refactors |
   | Dependency relationship | Source file + its test file + its types |
   | Config/build changes | Build configs, CI files, dependency manifests |
   | Unrelated changes | Separate commits for unrelated modifications |

   **Rules**:
   - Never mix unrelated changes in one commit
   - Keep commits atomic: each commit should be independently revertable
   - A single file change is a valid commit on its own
   - If ALL changes are related, a single commit is fine
   - Spec/documentation files that accompany code changes may be grouped with those code changes OR committed separately as `docs:` -- use judgment
   - If one file's changes belong to two different groups, say so in the plan. `git add <file>` stages the whole file and cannot split them, so the choice between splitting hunks by hand and accepting a coarser grouping is the user's

6. **For each logical group**, determine:
   - **Type**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
   - **Scope** (optional): A noun describing the section of the codebase (e.g., `auth`, `api`, `dashboard`, `k8s`)
   - **Description**: Short imperative summary, keeping the full first line at or under 50 characters
   - **Body**: Bulleted list of changes, each line starting with `-` and a space. Each bullet explains one change (what and why). Wrap lines at 72 characters. Skip the body only when the branch will be rewritten before merge -- `checkpoint`, or a branch you have confirmed is compacted or squashed before it lands
   - **Breaking change**: Add `!` before colon or a `BREAKING CHANGE:` footer if applicable
   - **Footers** (optional): `Refs:`, `Fixes:`, `Closes #N` if relevant

### Phase 3: Propose

7. **Show the full commit plan and ask for confirmation.** Always -- there is no commit count small enough to skip it, because the grouping is the thing being approved and two commits can split unrelated work as easily as five:

   ```text
   Commit Plan (N)

   1. <type>(<scope>): <description>
      Files: path/one, path/two
      Body:
        - what changed, and why

   2. <type>(<scope>): <description>
      Files: path/three

   Not included:
     - path/four -- unrelated to this task, left in the working tree

   Flags:
     - <anything from step 7a, or omit this section entirely>
   ```

   Files are listed by explicit path; a count ("4 files") is not reviewable. **Not included** lists every changed file you are leaving out and why, including ones you judged out of scope -- it is the part the user cannot reconstruct from the diff.

   a. **Raise these in the plan itself**, not after the user approves:
      - Any `.env`, credential, key, token, or certificate file among the changes -- name it and exclude it by default
      - The current branch is `main` or `master`
      - Changes inside a git submodule (e.g., `ood/ondemand/`) -- the submodule commits separately from the parent's pointer update, so the plan needs both
      - Anything that would need `--amend` or a force push

   b. **Do not stage anything while proposing.** Staging mutates an index the user may have arranged deliberately. Staging happens in Phase 4, by explicit path.

   Ask: "Proceed with these N commit(s)? (yes / no / edit)"

   - If the user says "edit", ask what to change and revise the plan
   - If the user says "no", stop
   - If the user says "yes" or "proceed", continue to Phase 4

   An approved plan authorizes only the commits it showed. If new changes appear or the grouping shifts, re-propose.

### Phase 4: Execute Commits

8. **Execute each commit sequentially**. For each logical group:

   a. Stage only the files for this commit, by explicit path:

   ```sh
   git add <file1> <file2> ...
   ```

   b. Create the commit with the message on stdin:

   ```sh
   git commit -F - <<'MSG'
   <type>(<scope>): <description>

   - First change bullet
   - Second change bullet

   <footers if any>
   MSG
   ```

   Do **not** use `git commit -m "$(cat <<'EOF' ... EOF)"` -- bash 3.2 mis-parses a heredoc inside command substitution and breaks on apostrophes. See [references/commit-message-heredoc.md](references/commit-message-heredoc.md) for the full rationale and for choosing a delimiter. A subject-only commit uses the same form with no blank line and no bullets after it.

   c. Verify the commit succeeded:

   ```sh
   git log --oneline -1
   ```

9. **If a commit fails** (e.g., pre-commit hook rejection), nothing was committed -- the group is still pending:
   - Read the error output
   - If a hook rewrote the files (formatting, lint fixes), re-stage those files by explicit path and retry the same commit
   - If the failure needs a code change you can make, make it, re-stage, and retry the same commit
   - If the fix cannot be automated, report the error and stop. Do not reshuffle the remaining groups around the failure without asking

### Phase 5: Summary

10. **Show final summary** after all commits:

    ```text
    N commit(s) created:
      <hash> <type>(<scope>): <description>
      <hash> <type>(<scope>): <description>

    Branch: <branch-name>
    ```

## Commit Message Format

Types, the 50-character subject limit, imperative mood, body wrapping, and breaking-change syntax are defined once in the Conventional Commits section of the global defaults rule, which is always loaded. Do not restate them here -- a second copy is what let `build` and `ci` go missing from one list and not the other.

## Important Rules

- **Never commit secrets**: Skip `.env`, credentials, API keys, tokens. These are flagged in the plan (step 7a) and excluded by default, not raised after approval.
- **Never force push or amend** unless the user explicitly requests it in the current message.
- **Never commit to main/master** without flagging it in the plan and getting confirmation.
- **Respect .gitignore**: Do not stage files that should be ignored.
