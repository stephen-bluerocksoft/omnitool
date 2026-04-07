---
description: Create a pull request from the current branch using gh CLI
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may specify a target base branch, a title hint, reviewers, or other PR options.

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
   - If there are uncommitted changes, warn the user and ask whether to proceed or commit first.

2. **Determine base branch**. The base branch is resolved in this order:
   - Explicitly provided by the user in `$ARGUMENTS` (e.g., "into dev", "base: main")
   - The branch's upstream tracking branch (if set)
   - Default: `main`

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

   - If a PR already exists for this branch, show the URL and ask the user if they want to update it or abort.

### Phase 2: Draft the PR

6. **Analyze ALL commits** between base and HEAD. Do NOT just look at the latest commit -- the PR encompasses the entire branch diff.

   ```sh
   git log --format="%h %s%n%b" <base>..HEAD
   ```

   Read the full commit messages (subjects and bodies) to understand the complete scope of changes.

7. **Determine PR title**:
   - If the user provided a title hint in `$ARGUMENTS`, use it
   - If the branch has a single commit, use that commit's subject as the title
   - If the branch has multiple commits, synthesize a title that captures the overall change
   - Title should follow conventional commit format if the project uses it
   - Keep the title concise (under 72 characters)

8. **Draft the PR body** using this structure:

   ```markdown
   ## Summary

   <Bullet list -- one bullet per distinct deliverable in the PR. Each bullet
   should name the concrete artifact (file, flag, endpoint, page) and state
   what it does. Aim for completeness: a reviewer reading only the Summary
   should know every deliverable.>

   ## Context

   <1-2 paragraphs explaining WHY this change exists. What problem was hit,
   what gap was discovered, or what product need drove it. Mention any PRs
   this supersedes or relates to.>

   ## <Area: short description>

   <For each logically distinct change area (feature, subsystem, module),
   create a separate section with a descriptive heading. Include:
   - A paragraph explaining what it does and any design decisions
   - Security, performance, or compatibility notes when relevant
   - A **Changes:** sub-list naming the specific files or components touched>

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
   - **Summary** lists deliverables, not motivations. Each bullet names a file, flag, route, or capability.
   - **Context** explains the "why" -- the problem, gap, or product need. Reference related PRs or issues.
   - **Change sections** group related work under descriptive headings (e.g., "Frontend: welcome page", "Auth: multi-domain support", "CLI: new --workflow-dirs flag"). One section per logical area.
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

    ```
    Pull Request Plan
    =================

    Branch: <current-branch> -> <base-branch>
    Commits: <N> commit(s)
    Push needed: yes/no

    Title: <pr-title>

    Body:
    <full PR body preview>
    ```

11. **Ask the user to confirm**:
    - "Create this PR? (yes/no/edit)"
    - If "edit", ask what to change and revise
    - If "no", stop
    - If "yes" or "proceed", continue

12. **Execute**. Run sequentially:

    a. Push the branch if needed:
    ```sh
    git push -u origin HEAD
    ```

    b. Create the PR using a HEREDOC for the body:
    ```sh
    gh pr create --base <base-branch> --title "<title>" --body "$(cat <<'EOF'
    <pr-body>
    EOF
    )"
    ```

    c. If the user specified reviewers in `$ARGUMENTS`, add them:
    ```sh
    gh pr edit <pr-number> --add-reviewer <reviewer1>,<reviewer2>
    ```

13. **Report the result**:
    - Show the PR URL
    - Show the PR number
    - Note that the PR is ready for review

## Important Rules

- **Never force push** unless the user explicitly requests it.
- **Never create PRs to main/master** without confirming the base branch with the user.
- **Never fabricate changes** -- all PR content must be derived from the actual diff and commit history.
- **Respect spec-first workflow** -- if a spec exists for the branch, reference it.
- **Do not commit** -- this command only creates PRs from existing commits. Use `/omni.commit` first if changes are uncommitted.
- **Check for secrets** -- if the diff contains files that might have secrets (`.env`, `credentials.*`, `*secret*`), warn the user before pushing.
