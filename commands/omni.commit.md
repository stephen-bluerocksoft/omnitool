---
description: Checkpoint changes as logically grouped conventional commits (designed for compact-before-PR workflow)
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may specify which files to commit, a commit message hint, or ask to commit only specific changes.

**Shortcuts**: Check the user's input for these keywords (case-insensitive) before proceeding to the standard flow:

| Keyword | Behavior |
| ------- | -------- |
| `full` | Jump to the Full Commit Shortcut |

## Full Commit Shortcut

When the user invokes `/omni.commit full` (with optional additional hints after `full`), produce **polished, permanent commits** that will not be compacted. This is for commits landing directly on `main`/`dev`, hotfixes, one-off changes, or any branch where `/omni.compact` will not run.

Follow the same Phase 1 and Phase 2 as the standard flow, with these differences:

- **Phase 2 step 6**: For each logical group, also determine:
  - **Body** (optional): Bulleted list of changes using `- ` prefix. Each bullet explains one change (what and why). Wrap lines at 72 characters.
  - **Breaking change**: Add `!` before colon or `BREAKING CHANGE:` footer if applicable
  - **Footers** (optional): `Refs:`, `Fixes:`, etc. if relevant

- **Phase 3**: **Always** show the full commit plan and ask for confirmation, regardless of how many commits:

  ```
  Commit Plan
  ===========

  Commit 1/N: <type>(<scope>): <description>
    Files:
      - path/to/file1
      - path/to/file2
    Body:
      - change bullet 1
      - change bullet 2

  Commit 2/N: <type>(<scope>): <description>
    Files:
      - path/to/file3
    Body:
      - change bullet 1

  Files NOT included (no changes detected or out of scope):
    - <list any skipped files and why>
  ```

  Ask: "Proceed with these N commit(s)? (yes/no/edit)"

- **Phase 4**: Commit using a HEREDOC to include the body:

  ```sh
  git commit -m "$(cat <<'EOF'
  <type>(<scope>): <description>

  - First change bullet
  - Second change bullet

  <footers if any>
  EOF
  )"
  ```

After all commits, show the standard Phase 5 summary, then stop.

## Permissions

All git commands that modify repository state (add, commit, reset, etc.) require write permissions. Read-only commands (status, log, diff, show, blame) do not.

## Context

This command creates **incremental checkpoint commits** during feature branch development. These commits are not the final history -- the branch will be compacted with `/omni.compact` before PR. The goal is **well-labeled checkpoints that give compact good grouping signals**, not polished commit messages.

What matters: **type**, **scope**, and a clear one-line description.
What does not matter: detailed body text, footers, or multi-paragraph explanations.

## Outline

### Phase 1: Gather Context

1. **Identify chat-modified files**: Check if any files were modified, created, or edited during the current chat session. These are the **priority files** for committing. If the user provided specific files or guidance in their input, use that as the primary scope.

2. **Run read-only git commands** to understand the full repository state:

   ```sh
   git status --porcelain
   git diff --stat
   git diff --cached --stat
   ```

3. **Determine commit scope**:
   - **If chat-modified files exist**: Focus commits on those files first. Only include other changed files if they are directly related (e.g., a test file for a modified source file, or a lockfile updated by a dependency change).
   - **If no chat-modified files**: Analyze ALL modified/untracked files from `git status` and group them logically.

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

6. **For each logical group**, determine:
   - **Type**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
   - **Scope** (optional): A noun describing the section of the codebase (e.g., `auth`, `api`, `dashboard`, `k8s`)
   - **Description**: Short imperative summary, keeping the full first line at or under 50 characters
   - Do NOT write body text or footers -- compact will produce the final commit messages

### Phase 3: Confirm (conditional)

7. **If 3 or more commits**, show a lightweight plan and ask for confirmation:

   ```
   Commit Plan (N commits)
     1. <type>(<scope>): <description>  [file1, file2]
     2. <type>(<scope>): <description>  [file3]
     3. <type>(<scope>): <description>  [file4, file5]

   Proceed? (yes/no/edit)
   ```

   - If the user says "edit", ask what to change and revise the plan
   - If the user says "no", stop
   - If the user says "yes" or "proceed", continue to Phase 4

   **If 1 or 2 commits**, auto-proceed to Phase 4 without asking. Just briefly state what you are committing (e.g., "Committing: `feat(auth): add login endpoint` -- 3 files").

### Phase 4: Execute Commits

8. **Execute each commit sequentially**. For each logical group:

   a. Stage only the files for this commit:

   ```sh
   git add <file1> <file2> ...
   ```

   b. Create the commit (subject line only, no body):

   ```sh
   git commit -m "<type>(<scope>): <description>"
   ```

   c. Verify the commit succeeded:

   ```sh
   git log --oneline -1
   ```

9. **If a commit fails** (e.g., pre-commit hook rejection):
   - Read the error output
   - Fix the issue if possible (e.g., formatting, linting)
   - Create a NEW commit (never amend unless explicitly told to)
   - If the fix cannot be automated, report the error and stop

### Phase 5: Summary

10. **Show final summary** after all commits:

    ```
    N commit(s) created:
      <hash> <type>(<scope>): <description>
      <hash> <type>(<scope>): <description>

    Branch: <branch-name>
    ```

## Conventional Commits Quick Reference

| Type | When to Use |
| ---- | ----------- |
| `feat` | Adds a new feature |
| `fix` | Fixes a bug |
| `docs` | Documentation only changes |
| `style` | Formatting, missing semicolons, etc. (no code change) |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or correcting tests |
| `build` | Changes to build system or dependencies |
| `ci` | Changes to CI configuration |
| `chore` | Other changes that don't modify src or test files |
| `revert` | Reverts a previous commit |

**Formatting rules**:
- First line (type + scope + description) MUST be 50 characters or less
- Use imperative mood ("add" not "added")

## Important Rules

- **Never commit secrets**: Skip `.env`, credentials, API keys, tokens. Warn the user if such files are staged.
- **Never force push or amend** unless the user explicitly requests it.
- **Never commit to main/master** without warning the user first. If on main/master, warn and ask for confirmation.
- **Respect .gitignore**: Do not stage files that should be ignored.
- **Submodule awareness**: If changes are inside a git submodule (e.g., `ood/ondemand/`), note that the submodule must be committed separately from the parent repo's submodule pointer update.
- **Checkpoint mindset** (default mode): These commits will be rewritten by `/omni.compact` before PR. Focus on good labels (type + scope), not polished prose.
- **Permanent mindset** (`full` mode): These commits are the final history. Invest in clear body text that explains what and why.
