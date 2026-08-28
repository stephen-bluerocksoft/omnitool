# Commit Proposals

Committing requires an explicit go-ahead. This rule governs the moment you ask for it: what to put in front of the user so they can approve, redraw the grouping, or say no without reading the whole diff themselves. It does not authorize committing, and an approved proposal authorizes only the commits it showed.

`/omni-commit` implements this end to end and layers its own grouping and execution procedure on top. Everything here is the floor for every other case: an ad-hoc commit, a hand-off at the end of a task, a fix the user asked you to land.

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

Never mix unrelated changes in one commit. If one file's changes belong to two different commits, say so in the proposal: `git add <file>` stages the whole file and cannot split them, so the user has to choose between splitting the hunks by hand and accepting a coarser grouping.

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

Proceed? (yes / no / edit)
```

- **Subject lines** follow the conventional commit format defined in the global defaults. Show the exact subject you will commit, not a paraphrase of it.
- **Files** are listed by explicit path. A count ("4 files") is not reviewable.
- **A body** is worth writing when the commit is permanent history: landing on `main` or `dev`, a hotfix, or any branch that will not be squashed, rebased, or compacted before merge. On a branch whose history will be rewritten, a clear subject line is enough.
- **Not included** is the part the user cannot reconstruct from the diff. List every changed file you are leaving out and why, including ones you judged out of scope. A scope decision buried in prose does not get reviewed.

## Flag Before Asking

Raise these in the proposal itself, not after the user approves:

- Any `.env`, credential, key, token, or certificate file among the changes -- name it and exclude it by default.
- The current branch is `main` or `master`.
- Changes inside a submodule -- the submodule commits separately from the parent's pointer update, so the proposal needs both.
- Anything that would need `--amend` or a force push. Never do either without an explicit request in the current message.
