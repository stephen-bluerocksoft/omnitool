---
name: omni-pr-create
description: Create a pull request from the current branch using gh CLI. Use when ready to open a PR for review.
disable-model-invocation: true
compatibility: Requires BRS Codex installed -- runs its detect-base.sh from brs-review
---

## Permissions

All git and gh commands that modify state (push, pr create) require write permissions. Read-only commands (status, log, diff, show, branch) do not.

## Outline

### Phase 1: Gather Context

1. **Verify branch state**. Run these commands in parallel:

   ```sh
   git branch --show-current
   git status --porcelain
   git log --oneline -1
   ```

   - If on `main` or `master`, **STOP** and warn the user. PRs should be created from feature branches.
   - If there are uncommitted changes, list them, then ask with the Guided decisions rule in the core standards:
     - **Commit first** -- stop so the user can run `/omni-commit`; recommend it when the uncommitted files belong to the work on this branch, since the PR would otherwise miss them
     - **Proceed without them** -- the PR covers committed work only and the changes stay in the tree; recommend it when they are unrelated to the branch
     - **Stop** -- end the run with nothing pushed

2. **Determine base branch** with the script BRS Codex installs in brs-review. It prints the base the user named (e.g., "into dev", "base: main") after checking it exists, and otherwise the nearest of `main`, `master`, and `dev`:

   ```sh
   bash ~/.claude/skills/brs-review/scripts/detect-base.sh [<base the user named>]
   ```

   A non-zero exit means no base was found, the named base does not exist, or BRS Codex is not installed: **STOP** and report its message. Never use the branch's upstream tracking branch as the base -- for a pushed feature branch that is the branch itself.

3. **Gather commit history and diff against base**. Run in parallel:

   ```sh
   git log --oneline <base>..HEAD
   git diff --stat <base>...HEAD
   ```

   - If there are zero commits ahead of base, **STOP** -- nothing to open a PR for.

4. **Check remote tracking**. Run:

   ```sh
   git status -sb
   ```

   - Determine if the branch has been pushed to the remote.
   - If not pushed, the branch will be pushed in Phase 3.

5. **Check for existing PR**. Run:

   ```sh
   gh pr list --head <current-branch> --state open --json number,title,url
   ```

   - If a PR already exists for this branch, show the URL, then ask with the Guided decisions rule in the core standards:
     - **Update it (Recommended)** -- continue, redrafting that PR's title and body from the whole branch; the step 10 plan shows the result and step 11 approves it
     - **Abort** -- leave the existing PR as it is and stop

### Phase 2: Draft the PR

6. **Analyze ALL commits** between base and HEAD. Do NOT just look at the latest commit -- the PR encompasses the entire branch diff.

   ```sh
   git log --format="%h %s%n%b" <base>..HEAD
   ```

   Read the full commit messages (subjects and bodies) to understand the complete scope of changes.

7. **Determine PR title**:
   - If the user provided a title hint in the user's message, use it
   - If the branch has a single commit, use that commit's subject as the title
   - If the branch has multiple commits, synthesize a title that captures the overall change
   - Title should follow conventional commit format if the project uses it
   - Keep the title concise (under 72 characters)

8. **Draft the PR body** using this structure:

   ```markdown
   ## Summary

   <1-3 bullet points describing what this PR delivers at a conceptual level.
   Each bullet should state a capability, behavior change, or outcome -- NOT
   list individual files. A reviewer reading only the Summary should understand
   the scope and purpose of the PR in 10 seconds.>

   ## <Area: short description>

   <For each logically distinct change area (feature, subsystem, module),
   create a separate section with a descriptive heading. Start with a paragraph
   explaining what it does, why, and any design decisions. Include security,
   performance, or compatibility notes when relevant. End with a **Changes:**
   sub-list naming the specific files or components touched.>

   **Changes:**
   - `path/to/file.ext` -- what was added or changed
   - `path/to/other.ext` (new) -- brief description

   ## <Another area: short description>

   ...repeat for each distinct area...

   ## Test plan

   <Checklist of verification steps, specific to the changes in this PR.
   Use `- [ ]` for items the reviewer should check.>
   ```

   Guidelines:
   - **Summary** is conceptual, not exhaustive. State capabilities and outcomes, not files. 1-3 bullets max. Do NOT duplicate the per-section Changes lists.
   - **Change sections** group related work under descriptive headings (e.g., "Frontend: welcome page", "Auth: multi-domain support", "CLI: new --workflow-dirs flag"). One section per logical area. Each section should open with motivation and design rationale.
   - Within each change section, include a `**Changes:**` sub-list that names specific files with brief annotations. Mark new files with `(new)`.
   - Omit a change section if the PR is truly single-purpose -- but most PRs that touch multiple areas benefit from the structure.
   - Test plan should be actionable and specific to the changes.
   - If a spec exists for the branch (check `specs/<branch-name>/`), reference acceptance criteria from `spec.md`.
   - Do NOT fabricate changes -- only describe what is actually in the diff.

9. **If the branch name matches a spec folder** (e.g., branch `017-infra-cleanup` has `specs/017-infra-cleanup/`):
   - Read `spec.md` for user stories and acceptance criteria
   - Reference relevant success criteria in the Test Plan
   - Mention the spec in the Summary (e.g., "Implements spec 017-infra-cleanup")

### Phase 3: Present Plan and Execute

10. **Show the PR plan** to the user before executing:

    ```text
    Pull Request Plan
    =================

    Branch: <current-branch> -> <base-branch>
    Commits: <N> commit(s)
    Push needed: yes/no

    Title: <pr-title>

    Body:
    <full PR body preview>

    Flags:
      - <base is main/master, or possible secrets in the diff -- omit this section when there are none>
    ```

11. **Ask the user to confirm** with the Guided decisions rule in the core standards. Selecting the first option is the go-ahead for the push and the PR shown in the plan, and nothing else:
    - **Create this PR (Recommended)** -- push the branch if needed and open the PR with this title, base, and body
    - **Edit the plan** -- ask what to change, revise, show the plan again, and ask again
    - **Don't create** -- stop with nothing pushed

    If the diff carries a possible secret (see Important Rules), ask about it as its own question in the same call, before anything is pushed:
    - **Stop and remove it (Recommended)** -- nothing is pushed; once pushed, a secret has to be rotated, not just deleted
    - **Push anyway** -- the user has confirmed the file holds no real secret

12. **Execute**. Run sequentially:

    a. Push the branch if needed. Name the branch explicitly and confirm it first -- `HEAD` resolves to whatever branch is currently checked out, so if the branch changed underneath you (an IDE, a hook, another session), `push HEAD` silently pushes to that branch instead, `main` included:

    ```sh
    BR=$(git branch --show-current)
    [ "$BR" = "<expected-branch>" ] || { echo "ABORT: on $BR, not <expected-branch>"; exit 1; }
    git push -u origin "$BR"
    ```

    b. Create the PR with the body on stdin (`gh` reads `-` from standard input). Never use `--body "$(cat <<'EOF' ... EOF)"` -- bash 3.2 on macOS mis-parses a heredoc inside command substitution and breaks on any unpaired quote, such as an apostrophe. Pick a delimiter the body cannot contain: `EOF` is a poor choice for any body that discusses shell scripting, because a literal `EOF` line inside the content terminates the heredoc early -- the command receives a silently truncated body and the remainder is parsed as shell. Use `PRBODY` or similar:

    ```sh
    gh pr create --base <base-branch> --title "<title>" --body-file - <<'PRBODY'
    <pr-body>
    PRBODY
    ```

    When step 5 chose **Update it**, edit the existing PR instead of creating one, with the same stdin rule:

    ```sh
    gh pr edit <pr-number> --title "<title>" --body-file - <<'PRBODY'
    <pr-body>
    PRBODY
    ```

    c. If the user specified reviewers in the user's message, add them:

    ```sh
    gh pr edit <pr-number> --add-reviewer <reviewer1>,<reviewer2>
    ```

13. **Report the result**:
    - Show the PR URL
    - Show the PR number
    - Note that the PR is ready for review

## Important Rules

- **Never force push** unless the user explicitly requests it.
- **Never create PRs to main/master** without confirming the base branch with the user. Flag it in the step 10 plan; selecting **Create this PR** in step 11 on that plan is the confirmation.
- **Never fabricate changes** -- all PR content must be derived from the actual diff and commit history.
- **Respect spec-first workflow** -- if a spec exists for the branch, reference it.
- **Do not commit** -- this command only creates PRs from existing commits. Use `/omni-commit` first if changes are uncommitted.
- **Check for secrets** -- if the diff contains files that might have secrets (`.env`, `credentials.*`, `*secret*`), flag them in the step 10 plan and ask the step 11 secrets question before pushing.
