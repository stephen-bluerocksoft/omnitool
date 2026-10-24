---
name: omni-compact
description: Compact a feature branch's noisy commit history into clean, logical commits. Use when a branch is ready for PR and needs history cleanup.
disable-model-invocation: true
compatibility: Requires BRS Codex installed -- runs its detect-base.sh from brs-review
---

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
   - If there are uncommitted changes, **STOP**. All changes must be committed before compacting. Suggest the user run `/omni-commit` first.

2. **Determine base branch** with the script BRS Codex installs in brs-review. It prints the base the user named (e.g., "base: dev") after checking it exists, and otherwise the nearest of `main`, `master`, and `dev`:

   ```sh
   bash ~/.claude/skills/brs-review/scripts/detect-base.sh [<base the user named>]
   ```

   A non-zero exit means no base was found, the named base does not exist, or BRS Codex is not installed: **STOP** and report its message. Never compact against a guessed base -- the base sets which commits get rewritten.

   Find the merge-base:

   ```sh
   git merge-base <base-branch> HEAD
   ```

3. **Count commits to compact**:

   ```sh
   git log --oneline <merge-base>..HEAD
   ```

   - If there are 0 commits ahead of base, **STOP** -- nothing to compact.
   - If there are 3 or fewer commits, show the list, then ask with the Guided decisions rule in the core standards whether to proceed:
     - **Stop -- already concise** -- leaves the history as it is; recommend it unless the list shows noise to fold (review `fix:` commits, `wip`, checkpoint subjects)
     - **Compact anyway** -- continues to step 4; recommend it when that noise is there

4. **Check remote tracking**:

   ```sh
   git log --oneline origin/<current-branch>..HEAD 2>/dev/null
   git log --oneline HEAD..origin/<current-branch> 2>/dev/null
   ```

   - If the branch has been pushed to the remote, **warn the user** that compaction will rewrite history and require a force push.
   - If the user did not include `--force` in the user's message, ask for explicit confirmation with the Guided decisions rule in the core standards before proceeding. A force push replaces history other people may have pulled, so the safe option is the recommendation unless the evidence says otherwise:
     - **Don't compact (Recommended)** -- stop; the pushed history stays intact
     - **Compact and rewrite history** -- continue, and push with `--force-with-lease` afterwards. Recommend this one instead only when the evidence shows the branch is the user's own and nobody has based work on it (for example, no other contributor's commits on it and no open PR under review by others)
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
     # Stage exactly the files the linters rewrote -- never `git add -A`,
     # which would sweep in unrelated work sitting in the tree.
     git diff --name-only -z | xargs -0 git add --
     git commit -F - <<'MSG'
     style: apply linter auto-fixes
     MSG
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

    ```text
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

19. **Ask the user to confirm** before proceeding, with the Guided decisions rule in the core standards:
    - **Compact as shown (Recommended)** -- continue to Phase 7
    - **Edit the plan** -- ask what to change, revise the plan, show it again, and ask again
    - **Don't compact** -- stop without rewriting anything, then ask step 26's backup question. Nothing has been rewritten, so the backup holds no unique state: recommend **Delete the backup** there

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

    d. **Commit** with the message on stdin (not `-m "$(cat <<'EOF' ...)"` -- bash 3.2 breaks on apostrophes there; see `omni-commit/references/commit-message-heredoc.md`):

    ```sh
    git commit -F - <<'MSG'
    <type>(<scope>): <description>

    - First change bullet
    - Second change bullet
    MSG
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

    ```text
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
    To restore:  git reset --hard <backup-branch-name>

    Commits are local only (not pushed).
    ```

    If the branch was previously pushed to the remote, remind the user:

    ```text
    This branch was previously pushed. To update the remote:
      git push --force-with-lease origin <current-branch>
    ```

26. **Offer the backup branch's deletion** after the summary, with the Guided decisions rule in the core standards. Never delete it without this answer:
    - **Keep the backup (Recommended)** -- the safety net stays until the compacted branch has merged or been force-pushed and reviewed
    - **Delete the backup** -- runs `git branch -D <backup-branch-name>`; the pre-compaction history is then recoverable only from the reflog

## Commit Message Format

Types, the 50-character subject limit, imperative mood, body wrapping, and breaking-change syntax are defined once in the Version Control section of the BRS core standards, which is always loaded. Do not restate them here.

Two things are specific to compaction and are not in that rule:

- `fix` is rarely right in compacted output. A bug fixed on the same branch that introduced the feature was never a bug in the base history -- fold it into the `feat` commit.
- Footer tokens use `-` in place of spaces (e.g., `Reviewed-by`).

## Important Rules

- **Never lose code**: The tree SHA after compaction MUST match the tree SHA before. If verification fails, restore from backup automatically.
- **Always create a backup branch**: Before any destructive operation, create `<branch>-backup-<timestamp>`. Never delete it automatically -- the user decides through the step 26 question.
- **Never compact main/master**: Compaction is for feature branches only.
- **Warn on pushed branches**: If the branch has been pushed, require explicit acknowledgment before proceeding -- `--force` in the user's message, or the **Compact and rewrite history** option selected in step 4.
- **Never commit secrets**: Skip `.env`, credentials, API keys, tokens. Warn the user if such files appear in the diff.
- **Fold fix commits into features**: The core value of compaction is eliminating review/hunt noise. `fix:` commits from iterative review rounds should be absorbed into the `feat:` or `refactor:` commit they were fixing.
- **Preserve the backup**: Always tell the user how to restore. The backup branch is their safety net.
- **Handle hunk failures gracefully**: If patch-based hunk staging fails, fall back to whole-file staging rather than losing changes. Note the deviation in the commit body.
- **Remainder safety net**: After all planned commits, check for unstaged leftovers and commit them rather than silently losing changes.
