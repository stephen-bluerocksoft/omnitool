# Commit Proposals

Committing requires an explicit go-ahead. This reference governs the moment you ask for it: what to put in front of the user so they can approve, redraw the grouping, or say no without reading the whole diff themselves. It does not authorize committing, and an approved proposal authorizes only the commits it showed.

`omni-commit` loads this file for every commit it proposes and layers its own scoping and grouping procedure on top. The skill is model-invocable, so the same floor covers an ad-hoc commit, a hand-off at the end of a task, and a fix the user asked you to land.

## Before Proposing

- **Propose from the diff, not from memory.** Run `git status --porcelain`, `git diff`, and `git diff --cached`, and read any untracked file you intend to include. What you recall editing and what is actually in the tree diverge after any non-trivial session.
- **Cover all pending work in one proposal.** Surfacing a second commit after the first is approved means the user approved a scope they could not see.
- **Do not stage while proposing.** Staging mutates an index the user may have arranged deliberately. Stage at execution time, by explicit path.

## Grouping

Each commit is one coherent change that is independently revertable. A single file is a valid commit on its own; so is one commit for everything, when it is all genuinely one change.

| Signal | Group together |
| ------ | -------------- |
| Same feature | A source file with its tests, types, and fixtures |
| Same change type | All docs, all formatting, all test additions |
| Build and config | Manifests with their lockfile, CI config, build config |
| Unrelated | Nothing -- these are separate commits |

Never mix unrelated changes in one commit. If one file's changes belong to two different commits, say so in the proposal: `git add <file>` stages the whole file and cannot split them, so that file is its own question, asked with the Guided decisions rule in the core standards -- **Split the hunks by hand** or **Accept the coarser grouping**. Recommend splitting when the two changes are unrelated, since the coarser commit would break the rule above; recommend the coarser grouping when they are close enough that reverting one without the other is not a real need.

## What to Show

```text
Commit Plan (N)

1. <type>(<scope>): <description>
   Files: path/one, path/two

2. <type>(<scope>): <description>
   Files: path/three
   Body:
     - what changed, and why

Not included:
  - path/four -- unrelated to this task, left in the working tree
```

- **Subject lines** follow the conventional commit format defined in the global defaults. Show the exact subject you will commit, not a paraphrase of it.
- **Files** are listed by explicit path. A count ("4 files") is not reviewable.
- **A body** is worth writing when the commit is permanent history: landing on `main` or `dev`, a hotfix, or any branch that will not be squashed, rebased, or compacted before merge. On a branch whose history will be rewritten, a clear subject line is enough.
- **Not included** is the part the user cannot reconstruct from the diff. List every changed file you are leaving out and why, including ones you judged out of scope. A scope decision buried in prose does not get reviewed.

Print the full plan in the visible text of the message that asks -- not in thinking, not only in an earlier turn, and never by reference ("the plan above") -- then ask for the go-ahead with the Guided decisions rule in the core standards. "Commit as shown" means shown in that message. The options:

- **Commit as shown (Recommended)** -- creates exactly the commits in the plan; selecting it is the go-ahead for those commits and no others
- **Edit the plan** -- regroup, reword, or change what is included; revise the plan, show it again, and ask again
- **Don't commit** -- leaves the working tree and index as they are

## Flag Before Asking

Raise these in the proposal itself, not after the user approves:

- Any `.env`, credential, key, token, or certificate file among the changes -- name it and exclude it by default.
- The current branch is `main` or `master`. Never commit there: stop before proposing and offer to create a branch. The BRS guard hook blocks the commit anyway.
- Changes inside a submodule -- the submodule commits separately from the parent's pointer update, so the proposal needs both.
- Anything that would need `--amend` or a force push. Never do either without an explicit request in the current message.

## After Approval

- **Stage each commit's files by explicit path, then commit with the message on stdin**: `git commit -F - <<'MSG'`, the message, then `MSG` on its own line. Never `git commit -m "$(cat <<'EOF' ... EOF)"` -- bash 3.2, the macOS system shell, mis-parses a heredoc inside command substitution and breaks on apostrophes.
- **A rejected commit created nothing**; its group is still pending. If a hook rewrote files itself (formatting, lint auto-fixes), re-stage them by explicit path and retry the same commit -- the user's own tooling made that change, not you.
- **A fix you write changes what was approved.** If the failure needs a code change you can make, make it, show its diff beside the hook's error, and ask with the Guided decisions rule in the core standards before committing:
  - **Commit with this fix (Recommended)** -- re-stage by explicit path and retry the same commit
  - **Stop here** -- the fix stays uncommitted in the tree with the rest of the group; commits already created stay
- **Any other failure**: report the error and the commits already created, then ask with the Guided decisions rule, and never reshuffle the remaining groups without the answer:
  - **Stop here (Recommended)** -- the created commits stay; the failed group and everything after it stay uncommitted in the tree
  - **Re-propose the remaining groups** -- show a revised plan for what is still pending and ask for the go-ahead again
