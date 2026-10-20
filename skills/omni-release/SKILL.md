---
name: omni-release
description: Prepare and cut a release -- review what ships since the last tag, check migrations, configuration and rollback safety, propose a version, and tag and confirm it only after approval. Use when asked to release, cut a tag, or ship what is on the integration branch to an environment.
disable-model-invocation: true
---

# omni-release

A release tag is usually a deploy: the pipeline builds on the tag, and an environment follows it with
no further review. So the review happens **before** the tag, on the exact commit that will be tagged,
and its output is a written proposal the user approves. Pushing the tag is the irreversible step, and
it is gated like every other outward action.

## Phase 1: Find the project's release process

Read the project's `AGENTS.md` (and anything it points to for releases -- a release runbook, a deploy
doc). It defines the mechanics this skill must follow: the branch releases are cut from, the tag
format, what a tag triggers, how a release is confirmed, and how it is rolled back.

If the project documents no release process, **stop** and say so. Do not invent one: the user decides
how this project releases, and the answer belongs in the project's docs, not in this run.

Record:

- `BRANCH` -- the branch releases are cut from
- `LAST` -- the latest release tag (`git tag --sort=-v:refname | head -1`, matching the project's format)
- `HEAD_SHA` -- `git rev-parse origin/<BRANCH>` after `git fetch origin <BRANCH> --tags`

## Phase 2: Gate on CI for that exact commit

```bash
gh run list --branch "$BRANCH" --commit "$HEAD_SHA" --json workflowName,status,conclusion
```

Every workflow on `HEAD_SHA` must be `completed/success`. A run on an earlier commit does not count,
and one still in progress is not green. If CI is still running, the rest of the review can proceed,
but the tag waits.

## Phase 3: Review what ships

Each item is checked by reading the diff, not recalled:

1. **Merged pull requests** since `LAST`, grouped by area into a table:
   `git log --merges --format='%cs %s' "$LAST..$HEAD_SHA"`.
2. **Pinned dependencies that move** -- submodules, vendored services, images built from another
   repository. A moved pin ships that repository's changes too; review its range the same way, and
   confirm the new pin is a commit the project allows (for example, merged `main` only).
3. **Migrations, in every database the release touches** (including a pinned dependency's). Classify
   each for rollback safety: a rollback re-pins the previous images and does not reverse migrations.
   Safe when the previous code still works on the new schema (new table, new nullable column, widened
   constraint); unsafe when it does not (dropped or renamed column, narrowed constraint), which makes
   the rollback a data rollback.
4. **New configuration** -- settings, environment variables, secrets -- compared with what the target
   environment actually supplies (its manifests, secret store references). A required value with no
   source fails at start-up, not at review.
5. **New start-up validators** -- a service that now refuses a value it used to accept goes down on
   the new image. Check the deployed value against the new rule.

**Secrets are checked, never printed.** A check reads the value and prints only a verdict (length,
placeholder or not), and it must fail on an empty read -- a missing credential that reads as empty
must not report a pass.

## Phase 4: Propose -- STOP

Present, in this order:

- **Version**, with a one-line reason (minor when anything user-facing was added, patch for fixes,
  docs, and tests only; major only for a breaking change the user confirms -- see the major-bump
  question below).
- **CI** on `HEAD_SHA`: green, or still running.
- **What ships**: the PR table, and each moved pin with what it brings.
- **Risk check**: migrations and their rollback safety, configuration, start-up validators -- each
  with the evidence that settled it.
- **Unverified**: anything that could not be checked, and why. A check blocked by missing
  credentials or access is the user's to unblock: say what to run, and do not proceed past it.
- **Rollback**: the previous tag, and whether it is an image re-pin or a data rollback.
- **Steps**: the exact tag and push commands from the project's process.

If an **Unverified** item blocks the release, do not ask for the go-ahead: report what to run and
stop. Otherwise ask for an explicit go-ahead with the Guided decisions rule in the core standards. The
tag push is irreversible, so the options are:

- **Release as proposed (Recommended)** -- tag `HEAD_SHA` with the proposed version and push that tag
  in Phase 5
- **Change the version** -- name a different version; revise the proposal, show it again, and ask
  again
- **Don't release** -- stop with nothing tagged

When the review found a breaking change, the version is its own question in the same call, before the
go-ahead: **Major (Recommended)** when the diff shows the break (removed or renamed public surface,
incompatible schema or configuration), or **Minor** when the user judges the change not breaking for
this project's consumers.

A question or comment in reply is not a go-ahead: answer it, then ask again.

## Phase 5: Tag

Only after the go-ahead, and only when CI on `HEAD_SHA` is green and every blocking check passed:

```bash
git fetch origin "$BRANCH" --tags
[ "$(git rev-parse "origin/$BRANCH")" = "$HEAD_SHA" ] || { echo "ABORT: $BRANCH moved"; exit 1; }
git tag -a "$VERSION" -m "Release ${VERSION#v}" "$HEAD_SHA"
git push origin "$VERSION"
```

- Tag the reviewed commit by SHA. If the branch moved, stop: the new commits were not reviewed.
- Push only this tag -- never `git push --tags`.
- One release in flight at a time. Never delete or move a tag a pipeline has already built.

## Phase 6: Confirm it landed

Follow the project's confirmation steps (pipeline result, environment bump, workloads on the new
version, a health check). Waiting on a scan or a reconcile interval is normal; wait for the evidence
rather than reporting success early. Report:

- the tag and the commit it points to,
- the pipeline run and its result,
- each deployed component and the version it runs, from the environment itself,
- the health check result,
- anything still pending, with what it is waiting on.

A release is reported as landed only when the environment shows the new version. Until then it is
reported as pushed, with what is outstanding.
