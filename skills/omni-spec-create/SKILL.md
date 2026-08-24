---
name: omni-spec-create
description: Create a brand-new feature specification using the spec-first (Speckit) workflow. Use when the user wants to spec, scope, or plan a NEW feature -- phrases like "write a spec for", "start a new feature", "scope out", or "let's plan X". Produces spec.md, plan.md, tasks.md, and any contracts/data models. Do NOT use to modify an existing spec (use omni-spec-modify for that).
---

# omni.spec.create

This command ALWAYS creates a new spec. Even if an existing spec directory seems related, create a new spec -- do NOT modify or extend existing specs.

**Confirm before scaffolding.** This flow creates a new git branch and scaffolds many files. Before running Step 1, state the feature you understood and confirm the user wants a full new spec created now. If the request is exploratory ("what would it take to..."), answer in prose instead and offer to run this when they are ready. Skip the confirmation only when the user explicitly asked to create the spec (e.g. invoked `/omni-spec-create` or said "create the spec").

## Runtime note

Speckit installs its phases as **Claude Code skills** at `.claude/skills/speckit-<phase>/SKILL.md`. Invoke them through the Skill tool by name -- `speckit-specify`, `speckit-plan`, `speckit-tasks`, `speckit-checklist`, `speckit-analyze`. Names are hyphenated, not dotted.

Older Speckit versions installed slash-command files at `.claude/commands/speckit.*.md` instead. That layout is **not supported** by this skill -- see Step 1.

When BRS Codex subagents are installed (`spec-creator`, `spec-planner`, `spec-validator`), you MAY delegate the heavy phases to them to keep the main context clean; they wrap the same Speckit skills. Delegation is optional -- invoking the Speckit skills directly is equally valid.

## Step 1: Verify Speckit Initialization

**Dotfile directory caution**: `.specify/` and `.claude/` are dotfile directories. Recursive glob patterns (`**/`) silently skip dotfile directories, causing false negatives. List these directories with an `ls` shell command -- never rely on glob alone.

Run this check from the project root:

```sh
ls -d .specify/ .claude/skills/speckit-specify/ .claude/commands/speckit.specify.md 2>/dev/null
```

Do NOT check `~/.claude/skills/` -- that is the user-level directory where this skill lives, not the project directory.

Interpret the result:

| Result | Action |
| ------ | ------ |
| `.specify/` and `.claude/skills/speckit-specify/` both present | Speckit is current. Continue to Step 2. |
| `.claude/commands/speckit.specify.md` present, `.claude/skills/speckit-specify/` absent | **STOP.** Outdated Speckit -- see below. |
| `.specify/` absent | Not initialized -- see below. |

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
> Re-run `/omni-spec-create` once the upgrade is done.

### Not initialized

1. `cp .specify/memory/constitution.md "/tmp/omni-spec-create-constitution-$(basename "$PWD").md"` (skip if `.specify/` does not exist yet) -- the per-project filename avoids clobbering another repo's backup
2. `specify init --here --integration claude --force`
3. `cp "/tmp/omni-spec-create-constitution-$(basename "$PWD").md" .specify/memory/constitution.md` (skip if no backup was made)
4. Confirm `.claude/skills/speckit-specify/` now exists. If it does not, the installed `specify` CLI is too old -- tell the user to run `specify self upgrade` and stop.

## Step 2: Create Feature Spec

Run the Speckit specify phase to create the feature spec, handling any clarifying questions it surfaces:

Invoke the `speckit-specify` skill with the feature description.

Record the **branch name** and **spec directory path** from the phase output for subsequent steps.

## Step 3: Plan, Tasks, and Analysis

Execute these phases in order using the spec directory from Step 2. Invoke the `speckit-*` skill named in each phase below.

### 3a: Plan

1. Run `git checkout <branch>` to ensure you are on the feature branch
2. Run the Speckit plan phase (`speckit-plan`)
3. This fills: plan.md, research.md, data-model.md, contracts/, quickstart.md

### 3b: Tasks

1. Run the Speckit tasks phase (`speckit-tasks`)
2. This generates tasks.md from the plan

### 3c: Checklist

1. Run the Speckit checklist phase (`speckit-checklist`)

### 3d: Analyze and Remediate

1. Run the Speckit analyze phase (`speckit-analyze`)
2. Remediate ALL findings from the analysis report using these severity rules:

**CRITICAL/HIGH** -- Blockers. For each finding:

- Update the relevant spec artifact (spec.md, plan.md, tasks.md, contracts/, data-model.md)
- Coverage gaps: add or update tasks in tasks.md
- Inconsistencies: reconcile conflicting artifacts
- Ambiguities: choose concrete behavior, document in spec.md edge cases, update tasks

**MEDIUM** -- Must be resolved. For each finding:

- Coverage gap: add explicit mention in task descriptions in tasks.md
- Underspecification: add concrete decision to spec.md and ensure tasks.md reflects it
- Inconsistency: update lower-authority artifact to match higher-authority one
- Ambiguity: resolve with concrete statement in spec.md, propagate to dependent artifacts

**LOW** -- For each finding, choose one:

- Fix if the change is small (add a type annotation, clarify a sentence)
- Accept by adding a note in spec.md under "Known Limitations" or "Deferred Items" with rationale

3. Re-run the analysis until zero CRITICAL, HIGH, and MEDIUM findings remain
4. If new findings emerge from edits, repeat the cycle

When resolving conflicts between artifacts, higher authority wins:

1. `.specify/memory/constitution.md` - Project principles
2. `specs/[feature]/spec.md` - Feature requirements
3. `specs/[feature]/plan.md` - Architecture decisions
4. `specs/[feature]/data-model.md` - Entity definitions
5. `specs/[feature]/contracts/` - API contracts
6. `specs/[feature]/tasks.md` - Task breakdown

### 3e: Enforce Test Coverage

Review tasks.md and verify every user story has at least one corresponding test task:

- Test tasks MUST appear BEFORE their corresponding implementation tasks
- Each test task specifies: file path, what it tests, expected pass/fail criteria
- Follow the project's test framework (check plan.md Technical Context)
- If test tasks are missing, add them

## Step 4: Verify and Summarize

1. Run `git branch --show-current` to confirm you are on the feature branch matching the spec folder name
2. **OUTPUT a summary and END your turn. Do NOT call any more tools.**
   - **Lead with a "Core design" paragraph (REQUIRED).** Before any tables or lists, write 2-5 sentences of plain prose that describe the central approach the spec commits to -- the mechanism a reader needs to picture what is about to be implemented. Name the key moving parts, the primary flow, what is reused vs. built new, and any deliberate non-goals (e.g. "zero changes to X", "least-privilege Y"). This is a narrative overview, not a bullet list, and it must always appear even when the spec is simple. Derive it from plan.md (Technical Context, architecture) and research.md (design decisions) -- do not fabricate.
   - Present what was created: spec.md, plan.md, tasks.md, and any contracts or data models
   - Include a table of analysis findings that were addressed and how each was resolved
   - List any LOW findings accepted with rationale
   - Confirm test tasks are present for each user story
   - Tell the user to run `/omni-spec-implement` when they are ready to begin implementation
   - Your response for this step MUST be a text message only -- no tool calls, no file edits, no implementation

**Implementation is NOT part of this command.** Use `/omni-spec-implement` to execute the tasks.

## Notes

- For a specific spec number, include it in the feature description (e.g., "spec 5: my feature")
