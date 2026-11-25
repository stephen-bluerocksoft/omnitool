---
name: omni-stack-land
description: Land changes across a stack of branches, each built on the one below, with one atomic push. Builds the new heads in a throwaway clone -- applies each branch's changes, merges each branch up with --no-ff, uses prepared conflict resolutions, refuses a rewritten branch, and runs the project's gates on every head -- then shows exactly what would be pushed and pushes only that, only on approval. Use when one change or review round touches several stacked branches. Not for one branch (use omni-commit), for opening pull requests (use omni-pr-create), or for merging a stack into its base.
disable-model-invocation: true
---

# omni-stack-land

## Overview

Landing a stack by hand rewrites the same chain of patches and merges each time something moves. `scripts/stack-land.sh` does it from a folder of prepared files, so a rebuild is one command. Everything happens in a throwaway clone: the repository is only read, and its worktrees, index, and branches are never touched. The script never pushes.

## Instructions

### Phase 1: Plan

Make the plan folder in the repository's gitignored `temp/`. The header of `scripts/stack-land.sh` gives its layout:

1. `stack` -- the branches, bottom first. Read them from the pull requests' bases, not from the names.
2. `gates` -- an executable that runs the project's own checks, as its `Makefile` or CI defines them, and exits non-zero when one fails. Each head is checked out clean, so it sets up whatever it needs. Never leave out a check to make a head pass.
3. `changes/<branch>/` -- each branch's own changes as numbered patches made in a scratch clone, each with its commit message in a `.msg` beside it. Commits already on a local branch need no patch.
4. `after/<branch>/` -- the changes a branch needs because of the branch below it, made against the merged tree.
5. `resolve/<branch>/` -- for a conflict a build reports, the whole resolved file at its path. Read both sides before writing it.

### Phase 2: Build

```sh
bash ~/.claude/skills/omni-stack-land/scripts/stack-land.sh build --repo <repository> --remote <remote> --plan <plan folder> --work <new folder outside the repository>
```

Run it in the background when the gates are slow. Exit 2 means the plan or the environment is wrong. Exit 1 prints `STOP` and why:

- **A conflict with no prepared resolution** -- write the resolution, and build again.
- **A resolution out of date** -- something below changed. Check that branch's resolutions against the new text rather than deleting the one named.
- **A remote head that is not an ancestor** -- the branch was rewritten here, or someone pushed to it. Fetch and find out which. Never force it.
- **A gate that fails** -- fix the change it came from.

A resolution is a whole file, and one whose path still conflicts is used even when the text below it changed, which would undo that change up the stack. The build lists each one it used: after any change to a lower branch, read every listed one against both sides again.

Each build takes a new `--work` folder. A change to the plan, a local branch, or the remote makes an earlier build stale: build again.

### Phase 3: Approve

Print the build's table, its commits, the resolutions it used, and its push command in full, then ask with the Guided decisions rule in the core standards:

- **Push this stack (Recommended)** -- run that command, unchanged
- **Change the plan** -- revise, build again, and ask again
- **Don't push** -- stop with nothing pushed

The selection covers that table and that command. After another build, print and ask again.

### Phase 4: Push and Verify

1. Run `bash ~/.claude/skills/omni-stack-land/scripts/stack-land.sh ready --work <the build's folder>`. It fails when a head on the remote is not the old head in the table: a push alone would be accepted over a branch that was taken back or deleted since. Build again.
2. Run the printed command exactly: one `git push --atomic` of explicit commits to explicit branches, with no force. A rejection changed no branch. Build again; never add `--force`, and never push the branches one by one.
3. Check that the remote holds what was approved:

   ```sh
   bash ~/.claude/skills/omni-stack-land/scripts/stack-land.sh verify --work <the build's folder>
   ```

4. Report each branch's old and new head, what the gates ran, and anything skipped. Say that the local branches are behind the remote, and leave updating them to the user. Delete the work folder.

## Important Rules

- **Never push from the user's checkout**, and never move, check out, or reset a branch there
- **Never edit the pushed commits in the clone by hand** -- a change goes in the plan, and the stack is built again
- **Main, master, and dev are refused** -- a stack reaches them through review
