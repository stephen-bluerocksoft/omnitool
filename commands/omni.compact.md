---
description: Compact a feature branch's noisy commit history into clean, logical commits
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may specify a base branch (e.g., "base: main"), acknowledge force push (`--force`), or provide grouping hints.

## Permissions

All git commands that modify repository state (reset, add, commit, branch) require write permissions. Read-only commands (status, log, diff, show, merge-base) do not.

## Outline

### Phase 1: Safety and Validation

1. **Verify branch safety**. Run in parallel:

   ```sh
   git branch --show-current
   git status --porcelain
   ```

   - If on `main` or `master`, **STOP**. Compaction must be done on a feature branch.
   - If there are uncommitted changes, **STOP**. All changes must be committed before compacting. Suggest the user run `/omni.commit` first.

2. **Determine base branch**. Resolve in this order:
   - Explicitly provided by the user in `$ARGUMENTS` (e.g., "base: dev")
   - Default: `dev` if it exists, otherwise `main`

   Find the merge-base:

   ```sh
   git merge-base <base-branch> HEAD
   ```

3. **Count commits to compact**:

   ```sh
   git log --oneline <merge-base>..HEAD
   ```

   - If there are 0 commits ahead of base, **STOP** -- nothing to compact.
   - If there are 3 or fewer commits, warn the user that the branch is already concise and ask whether to proceed.

4. **Check remote tracking**:

   ```sh
   git log --oneline origin/<current-branch>..HEAD 2>/dev/null
   git log --oneline HEAD..origin/<current-branch> 2>/dev/null
   ```

   - If the branch has been pushed to the remote, **warn the user** that compaction will rewrite history and require a force push.
   - If the user did not include `--force` in `$ARGUMENTS`, ask for explicit confirmation before proceeding.
   - If the remote has commits not in the local branch, **STOP** -- the branches have diverged and compaction could lose remote-only changes.

### Phase 2: Lint and Auto-fix

5. **Detect the repo's linter(s)**. Check the repository root for configuration files (run these checks in parallel):

   | Linter | Detection Files |
   | ------ | --------------- |
   | Ruff | `pyproject.toml` (has `[tool.ruff]`), `ruff.toml`, `.ruff.toml` |
   | ESLint | `eslint.config.*`, `.eslintrc.*`, `package.json` (has `"eslint"` in devDependencies) |
   | Prettier | `.prettierrc*`, `package.json` (has `"prettier"` in devDependencies) |
   | golangci-lint | `.golangci.yml`, `.golangci.yaml`, `.golangci.toml` |
   | cargo clippy | `Cargo.toml` |
   | RuboCop | `.rubocop.yml` |
   | pre-commit | `.pre-commit-config.yaml` |

   Also check `Makefile` for a `lint`, `format`, `fmt`, or `check` target. If the repo has a `Makefile` with one of these targets, prefer that over individual tool invocation since it represents the project's canonical lint pipeline.

6. **Run detected linters with auto-fix**. For each detected linter, run its fix/format command against the files changed on this branch:

   ```sh
   # Get list of files changed on this branch
   git diff --name-only <merge-base>..HEAD
   ```

   Then run the appropriate fix commands (only on changed files when the tool supports file arguments):

   | Linter | Fix Command |
   | ------ | ----------- |
   | Ruff | `ruff check --fix <files>` then `ruff format <files>` |
   | ESLint | `npx eslint --fix <files>` |
   | Prettier | `npx prettier --write <files>` |
   | golangci-lint | `golangci-lint run --fix <files>` |
   | cargo clippy | `cargo clippy --fix --allow-dirty` |
   | RuboCop | `rubocop -a <files>` |
   | Makefile target | `make lint` or `make format` (these typically operate on the whole project) |

   If a linter is detected but its binary is not installed, skip it and warn the user (do not fail the compaction over a missing tool).

7. **Commit linter changes if any exist**:

   ```sh
   git status --porcelain
   ```

   - If there are changes, stage and commit them:

     ```sh
     git add -A
     git commit -m "$(cat <<'EOF'
     style: apply linter auto-fixes
     EOF
     )"
     ```

     Report to the user: "Linter auto-fixes applied and committed. These changes will be folded into the appropriate logical groups during compaction."

   - If there are no changes, report: "Linters passed -- no fixes needed." and continue.

### Phase 3: Capture Context

8. **Create a backup branch** before any destructive operation:

   ```sh
   git branch <current-branch>-backup-$(date +%Y%m%d%H%M%S)
   ```

   Report the backup branch name to the user.

9. **Capture the original commit log** with full detail. This is the Rosetta Stone for attributing changes to logical groups:

   ```sh
   git log --format="%H %s" <merge-base>..HEAD
   ```

   Store the list of SHAs and subjects in memory.

10. **Capture per-commit file lists** so you know which original commits touched which files:

    ```sh
    git show --stat --format="" <sha>
    ```

    Run this for every commit SHA from step 9. Build a mapping: `file -> [list of original commits that touched it]`.

11. **Identify shared files** -- files touched by more than one original commit. These require hunk-level analysis later. Files touched by only one commit are trivially attributed.

### Phase 4: Analyze and Group

12. **Read the original commit subjects** and group them into logical clusters. Each cluster represents one compacted commit. Grouping rules:

   | Signal | Grouping Logic |
   | ------ | -------------- |
   | Spec/planning docs | All spec and plan artifacts together as `docs` |
   | Feature code (by scope) | Group by conventional commit scope (e.g., `auth`, `tenancy`, `frontend`) |
   | Tests (by scope) | Test files grouped to match their feature scope |
   | Refactoring | Structural changes (package reorg, factory patterns) |
   | Config/build/CI | Build configs, dependency manifests, CI files |
   | Style/formatting | Formatting-only changes |

   **Key rule**: Review-driven `fix:` commits are **folded into** their parent `feat:` or `refactor:` group. The fix commits are artifacts of the review process, not distinct logical changes. Their code changes belong with the feature they were fixing.

13. **For each logical group, determine its files**:

    - **Exclusive files** (touched by commits in only this group): Assign directly.
    - **Shared files** (touched by commits in multiple groups): These need hunk-level analysis in Phase 5.

14. **For each logical group**, determine the compacted commit metadata:
    - **Type**: `feat`, `docs`, `test`, `refactor`, `style`, `build`, `ci`, `chore`
    - **Scope** (optional): A noun describing the section of the codebase
    - **Description**: Short imperative summary, keeping the full first line at or under 50 characters
    - **Body** (optional): Bulleted list summarizing what the group contains. Do NOT reference original commit SHAs -- the compacted history should stand on its own.

### Phase 5: Resolve Shared Files

15. **For each shared file**, read the full diff from the merge-base to determine which hunks belong to which group:

    ```sh
    git diff <merge-base>..HEAD -- <shared-file>
    ```

16. **Attribute hunks using two tiers**:

    a. **Mechanical matching (primary)**: For each original commit that touched the file, read its patch:

    ```sh
    git show <sha> -- <shared-file>
    ```

    Compare the original per-commit hunks against the collapsed diff. Lines that were added by a commit in Group A belong to Group A's patch. Lines added by a commit in Group B belong to Group B's patch.

    b. **AI semantic fallback**: When mechanical matching fails (e.g., a review fix modified the same lines as the original feature, so the collapsed diff has only the final version), read the hunk content and the relevant commit messages to determine which logical group the hunk belongs to based on intent.

17. **For each shared file, prepare per-group patches**. Write each group's hunks to a temporary patch file. These will be used during execution to stage only the relevant hunks.

    If a hunk genuinely cannot be split (interleaved line-by-line changes from two different concerns within the same hunk), assign the entire hunk to the **primary** group (the one with the most changes in the file) and note this in the commit body.

### Phase 6: Present Plan

18. **Show the compaction plan** to the user before executing:

    ```
    Compaction Plan
    ===============

    Branch: <current-branch>
    Base: <merge-base-sha> (<base-branch>)
    Backup: <backup-branch-name>
    Original commits: N -> Compacted commits: M

    Commit 1/M: <type>(<scope>): <description>
      Files:
        - path/to/file1
        - path/to/file2 (partial -- hunks only)
      Original commits folded:
        - <sha1> <subject1>
        - <sha2> <subject2>
      Body:
        - change bullet 1
        - change bullet 2

    Commit 2/M: <type>(<scope>): <description>
      Files:
        - path/to/file3
        - path/to/file2 (partial -- remaining hunks)
      Original commits folded:
        - <sha3> <subject3>
      Body:
        - change bullet 1

    Shared files resolved:
      - path/to/file2: hunks split between Commit 1 and Commit 2
    ```

19. **Ask the user to confirm** before proceeding:
    - "Proceed with compaction? (yes/no/edit)"
    - If "edit", ask what to change and revise the plan
    - If "no", delete the backup branch and stop
    - If "yes" or "proceed", continue to Phase 7

### Phase 7: Execute

20. **Soft reset to merge-base**:

    ```sh
    git reset --soft <merge-base>
    ```

21. **Unstage everything** so changes move to the working tree:

    ```sh
    git reset HEAD
    ```

22. **Execute each compacted commit sequentially**. For each logical group:

    a. **Stage exclusive files** (files belonging entirely to this group):

    ```sh
    git add <file1> <file2> ...
    ```

    b. **Stage shared file hunks** using patch application. For each shared file assigned hunks in this group:

    ```sh
    git apply --cached <temp-patch-file>
    ```

    If patch application fails (context mismatch due to earlier staged hunks), fall back to staging the entire file in this commit and note the deviation from the plan.

    c. **Verify staging**:

    ```sh
    git diff --cached --stat
    ```

    d. **Commit** using a HEREDOC:

    ```sh
    git commit -m "$(cat <<'EOF'
    <type>(<scope>): <description>

    - First change bullet
    - Second change bullet
    EOF
    )"
    ```

    e. **Verify** the commit succeeded:

    ```sh
    git log --oneline -1
    ```

23. **After all commits**, stage and commit any remaining unstaged changes that were missed. This is a safety net -- if attribution missed something, it goes into a final `chore: compact remainder` commit rather than being lost.

    ```sh
    git status --porcelain
    ```

    If there are remaining changes, stage and commit them. If the working tree is clean, continue.

### Phase 8: Verify

24. **Verify tree equivalence**. The compacted branch must produce the exact same code as the backup:

    ```sh
    git diff <backup-branch>..HEAD
    ```

    - If the diff is **empty**: compaction succeeded. The code is identical, only the commit history changed.
    - If the diff is **not empty**: compaction introduced or lost changes. **This is a critical failure.** Restore from backup:

      ```sh
      git reset --hard <backup-branch>
      ```

      Report the failure and the diff to the user.

25. **Show final summary**:

    ```
    Compaction Summary
    ==================

    Branch: <current-branch>
    Backup: <backup-branch-name>
    Original commits: N
    Compacted commits: M
    Tree verification: PASSED (identical code)

    New commit history:
      <hash1> <type>(<scope>): <description>
      <hash2> <type>(<scope>): <description>
      ...

    The backup branch <backup-branch-name> has been preserved.
    To delete it: git branch -D <backup-branch-name>
    To restore:  git reset --hard <backup-branch-name>

    Commits are local only (not pushed).
    ```

    If the branch was previously pushed to the remote, remind the user:

    ```
    This branch was previously pushed. To update the remote:
      git push --force-with-lease origin <current-branch>
    ```

## Conventional Commits Quick Reference

| Type | When to Use |
| ---- | ----------- |
| `feat` | Adds a new feature |
| `fix` | Fixes a bug (rarely used in compacted output -- fold into `feat`) |
| `docs` | Documentation only changes |
| `style` | Formatting, missing semicolons, etc. (no code change) |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or correcting tests |
| `build` | Changes to build system or dependencies |
| `ci` | Changes to CI configuration |
| `chore` | Other changes that don't modify src or test files |

**Formatting rules**:
- First line (type + scope + description) MUST be 50 characters or less
- Use imperative mood ("add" not "added")
- Body lines wrap at 72 characters
- Breaking changes: `!` before colon OR `BREAKING CHANGE:` in footer
- Footer tokens use `-` in place of spaces (e.g., `Reviewed-by`)

## Important Rules

- **Never lose code**: The tree SHA after compaction MUST match the tree SHA before. If verification fails, restore from backup automatically.
- **Always create a backup branch**: Before any destructive operation, create `<branch>-backup-<timestamp>`. Never delete it automatically -- let the user decide.
- **Never compact main/master**: Compaction is for feature branches only.
- **Warn on pushed branches**: If the branch has been pushed, require explicit `--force` acknowledgment before proceeding.
- **Never commit secrets**: Skip `.env`, credentials, API keys, tokens. Warn the user if such files appear in the diff.
- **Fold fix commits into features**: The core value of compaction is eliminating review/hunt noise. `fix:` commits from iterative review rounds should be absorbed into the `feat:` or `refactor:` commit they were fixing.
- **Preserve the backup**: Always tell the user how to restore. The backup branch is their safety net.
- **Handle hunk failures gracefully**: If patch-based hunk staging fails, fall back to whole-file staging rather than losing changes. Note the deviation in the commit body.
- **Remainder safety net**: After all planned commits, check for unstaged leftovers and commit them rather than silently losing changes.
