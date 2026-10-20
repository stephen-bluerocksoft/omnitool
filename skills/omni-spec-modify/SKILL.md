---
name: omni-spec-modify
description: Change the requirements of an EXISTING in-flight feature spec before implementation, cascading the edit through plan, tasks, contracts, and analysis. Use when the user wants to add, change, or remove a requirement on a feature whose specs/<NNN>-<name>/ directory exists on its own branch and has not merged to the default branch -- phrases like "update the spec to", "change the requirement", "the feature should now also". Do NOT use on a merged feature under Flow-Forward, the default (use omni-spec-create for a new spec that supersedes it) -- a project whose constitution records Living Spec uses this skill on merged features too; to create a new spec (use omni-spec-create), or to sync specs to already-built code (use omni-spec-align).
---

# omni.spec.modify

Change an existing feature's specification *before* implementing it. This edits the spec artifacts and re-runs analysis; it does NOT write feature code (use `/omni-spec-implement` for that) and it does NOT create a new spec (use `/omni-spec-create`).

**Confirm before editing the spec.** This flow rewrites an existing feature's spec artifacts and re-runs analysis. Before Step 1, state which spec you will modify and the change you understood, then ask with the Guided decisions rule in the core standards. Selecting the first option is the go-ahead for this flow on that spec and that change, and nothing else:

- **Update the spec now (Recommended)** -- run Steps 1 to 6 for the change as stated
- **Adjust the change first** -- ask what to change, restate it, and ask again
- **Not now** -- stop with nothing edited

If the request is exploratory ("what would it take to..."), answer in prose instead and offer to run this when they are ready. Skip the question only when the user explicitly invoked `/omni-spec-modify`.

## Runtime note

Speckit installs its phases as **Claude Code skills** at `.claude/skills/speckit-<phase>/SKILL.md`. This skill invokes `speckit-analyze` (and, if the change is ambiguous, `speckit-clarify`) through the Skill tool. Names are hyphenated, not dotted.

Older Speckit versions installed slash-command files at `.claude/commands/speckit.*.md` instead. That layout is **not supported** by this skill -- see Step 1.

## Step 1: Identify the Spec and Branch

**Dotfile directory caution**: `.specify/` and `.claude/` are dotfile directories. Recursive glob patterns (`**/`) silently skip them. List them with an `ls` shell command -- never rely on glob alone.

1. Run `ls -d .specify/ .claude/skills/speckit-analyze/ .claude/commands/speckit.analyze.md 2>/dev/null` to confirm Speckit is initialized and on the skills layout:
   - `.specify/` and `.claude/skills/speckit-analyze/` both present -- continue
   - `.claude/commands/speckit.analyze.md` present but `.claude/skills/speckit-analyze/` absent -- **STOP**, outdated Speckit (see below)
   - `.specify/` absent -- this feature has no spec yet; suggest `/omni-spec-create` and stop
2. Run `git branch --show-current`. Identify the feature's spec directory from the branch name, user input, or by checking `specs/`. The branch should match a `specs/<NNN>-<name>/` directory (e.g. branch `005-my-feature` matches `specs/005-my-feature/`).
3. If you are on `main`/`master`, or the branch does not match the target spec, `git checkout` the feature branch first -- spec edits belong on the feature branch, never on main.
4. Verify `spec.md`, `plan.md`, and `tasks.md` exist in the spec directory. If any is missing, the feature was never fully specified -- suggest `/omni-spec-create` and stop.
5. Confirm the feature may be edited. Read the spec persistence model in `.specify/memory/constitution.md`: if it records one that edits merged features in place, such as Living Spec, skip the rest of this step. Otherwise the BRS default, Flow-Forward, applies -- confirm the feature is still in flight. Detect the default branch (`git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p'`, falling back to whichever of `main` or `master` exists), then run `git cat-file -e <default>:specs/<NNN>-<name>/spec.md`. If it succeeds the feature has merged, and under Speckit's Flow-Forward model a merged feature directory is never edited. **STOP**: tell the user the change needs a new spec through `/omni-spec-create`, whose `## Supersedes` section names this directory and the requirement IDs it replaces, and END your turn.

### Outdated Speckit (legacy commands layout)

The project was scaffolded by a Speckit version that installs slash commands. This workflow requires the skills layout. **Do NOT fall back to the `.claude/commands/speckit.*.md` files and do NOT proceed** -- report the following to the user and END your turn:

> This project uses an outdated Speckit layout (`.claude/commands/speckit.*.md`). The omni spec workflow requires the skills layout (`.claude/skills/speckit-*/`). To upgrade:
>
> ```sh
> specify self upgrade
> specify integration upgrade claude
> specify extension update
> rm -f .claude/commands/speckit.*.md
> ```
>
> `integration upgrade` is diff-aware: it compares manifest hashes and refuses to run when Speckit files have local edits, so pass `--force` only when you mean to discard them. A project on the legacy commands layout predates those manifests, so if the upgrade reports nothing to compare against, use `specify init --here --integration claude --force` instead -- it preserves `specs/` and an existing `.specify/memory/constitution.md`. Back the constitution up first if it carries edits you cannot lose.
>
> Re-run `/omni-spec-modify` once the upgrade is done.

## Step 2: Read the Current Spec

Read every file in the spec directory and understand the current state before changing anything:

| Artifact | What to extract |
| -------- | --------------- |
| `spec.md` | Requirements (FR-NNN), user stories, acceptance scenarios, edge cases, assumptions |
| `plan.md` | Key technical decisions, project structure listing, architecture |
| `data-model.md` | Entities, fields, relationships, constraints |
| `contracts/` | API contracts -- request/response schemas, status codes, event types |
| `research.md` | Decisions, rationale, resolved/unresolved open items |
| `tasks.md` | Task breakdown, completion status (`[ ]`/`[X]`), dependency graph |
| `quickstart.md` | Setup steps, validation scenarios |

Record the last FR ID (e.g. FR-011) and last task ID (e.g. T018) so new IDs continue sequentially. Include any `## Phase N: Convergence` section when computing the maximum -- its tasks are real task IDs, and new tasks must continue past them rather than collide. Do not renumber or reorder that section. Restate the requested change concretely. If it is ambiguous, resolve it before editing: run the `speckit-clarify` skill when the ambiguity is in the requirement itself, and put any other open choice to the user with the Guided decisions rule in the core standards. Where no one can answer, stop and report the open questions in that rule's shape rather than editing on a guess.

## Step 3: Apply the Change Top-Down

Edit the artifacts in authority order so lower-authority artifacts conform to higher-authority ones. The specification hierarchy (highest first):

1. `.specify/memory/constitution.md` -- Project principles (never edit it -- the core standards forbid amending it to accommodate a feature; see the conflict rule below)
2. `specs/[feature]/spec.md` -- Feature requirements
3. `specs/[feature]/plan.md` -- Architecture decisions
4. `specs/[feature]/data-model.md` -- Entity definitions
5. `specs/[feature]/contracts/` -- API contracts
6. `specs/[feature]/tasks.md` -- Task breakdown

**When the change conflicts with the constitution**, edit nothing yet. Show the principle and the conflicting part of the change side by side. If a version of the change exists that conforms to the principle and still meets the user's stated need, ask with the Guided decisions rule in the core standards:

- **Reshape the change to conform** -- state the conforming version; recommend it when it keeps what the user asked for
- **Drop the conflicting part** -- apply the rest of the change; recommend it when the conflicting part is separable and the rest stands alone
- **Stop without editing** -- leave the spec as it is; amending the constitution is a project-level decision made through `speckit-constitution`, never inside this flow

If no conforming version exists, there is nothing to choose: stop, report the conflict, and END your turn.

For the requested change:

1. **`spec.md` first** -- add, modify, or remove functional requirements (FR-NNN), user stories, acceptance scenarios, edge cases, and assumptions. New FRs get sequential IDs continuing from the last one. When removing scope, mark it removed rather than silently deleting history.
2. **Cascade downward** -- update `plan.md` (technical decisions, project structure), `data-model.md` (entities, fields, relationships), and `contracts/` (schemas, status codes) so each stays consistent with the revised `spec.md`.
3. **`tasks.md` last** -- add tasks for new work (sequential IDs, cross-referenced to the FRs they implement), update tasks whose scope changed, and mark tasks that the change makes obsolete. Preserve `[X]` tasks that are still valid; do not reset completed work that the change does not touch.

## Step 4: Analyze and Remediate

1. Run the Speckit analyze phase (the `speckit-analyze` skill).
2. Remediate ALL findings using the same CRITICAL/HIGH/MEDIUM/LOW severity rules as `omni-spec-create` Step 3d (Analyze and Remediate) -- update the relevant artifact, reconcile inconsistencies, resolve an ambiguity yourself only where the artifacts, constitution, or code settle it (citing the evidence) and ask the user the rest as that step describes, and accept LOW findings only with a documented rationale.
3. Re-run the analysis until zero CRITICAL, HIGH, and MEDIUM findings remain. If new findings emerge from edits, repeat the cycle.

## Step 5: Enforce Test Coverage

Review `tasks.md` and verify every new or changed user story has at least one corresponding test task:

- Test tasks MUST appear BEFORE their corresponding implementation tasks.
- Each test task specifies: file path, what it tests, expected pass/fail criteria.
- Follow the project's test framework (check plan.md Technical Context).
- If test tasks are missing for the changed behavior, add them.

## Step 6: Verify and Summarize (Text Only)

1. Run `git branch --show-current` to confirm you are on the feature branch matching the spec folder.
2. **OUTPUT a summary and END your turn. Do NOT call any more tools.**
   - Lead with a short prose paragraph describing what the change is and how it flows through the spec (the mechanism, not a bullet list).
   - Requirements added / modified / removed (by FR ID).
   - Artifacts updated: [list].
   - Table of analysis findings addressed and how each was resolved; list any LOW findings accepted with rationale.
   - Confirm test tasks are present for each new or changed user story.
   - Tell the user to run `/omni-spec-implement` when they are ready to build the change.
   - Your response for this step MUST be a text message only -- no tool calls, no file edits, no implementation.

**Implementation is NOT part of this command.** Use `/omni-spec-implement` to execute the updated tasks.
