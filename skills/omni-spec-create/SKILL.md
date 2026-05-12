---
name: omni-spec-create
description: Create spec artifacts for a feature using the spec-first development workflow. Use when starting a new feature that needs specification.
disable-model-invocation: true
---

# omni.spec.create

This command ALWAYS creates a new spec. Even if an existing spec directory seems related, create a new spec -- do NOT modify or extend existing specs.

## Step 1: Verify Speckit Initialization

**Dotfile directory warning**: Both `.specify/` and `.cursor/` are dotfile directories. Glob's `**/` recursion silently skips dotfile directories, which causes false negatives. Use `ls` via the Shell tool to check for these directories -- never rely on Glob alone.

Run these checks from the project root:

1. `ls -d .specify/ .cursor/skills/speckit-specify/ 2>/dev/null` to detect both the speckit data directory and skill files
2. Do NOT check `~/.cursor/skills/` -- that is the user-level directory where this command lives, not the project directory

If `.cursor/skills/speckit-specify/SKILL.md` already exists, continue to Step 2.

If it does NOT exist, initialize speckit:

1. `cp .specify/memory/constitution.md /tmp/constitution-backup.md` (skip if `.specify/` does not exist yet)
2. `specify init --here --ai cursor-agent --force`
3. `cp /tmp/constitution-backup.md .specify/memory/constitution.md` (skip if no backup was made)

## Step 2: Create Feature Spec

Read the speckit-specify skill at `<project-root>/.cursor/skills/speckit-specify/SKILL.md` and follow its instructions to create the feature spec, including handling any clarifying questions it surfaces.

Record the **branch name** and **spec directory path** from the skill's output for subsequent steps.

## Step 3: Plan, Tasks, and Analysis

Execute these phases in order using the spec directory from Step 2:

### 3a: Plan

1. Run `git checkout <branch>` to ensure you are on the feature branch
2. Read and follow `<project-root>/.cursor/skills/speckit-plan/SKILL.md`
3. This fills: plan.md, research.md, data-model.md, contracts/, quickstart.md

### 3b: Tasks

1. Read and follow `<project-root>/.cursor/skills/speckit-tasks/SKILL.md`
2. This generates tasks.md from the plan

### 3c: Checklist

1. Read and follow `<project-root>/.cursor/skills/speckit-checklist/SKILL.md`

### 3d: Analyze and Remediate

1. Read and follow `<project-root>/.cursor/skills/speckit-analyze/SKILL.md`
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
   - Present what was created: spec.md, plan.md, tasks.md, and any contracts or data models
   - Include a table of analysis findings that were addressed and how each was resolved
   - List any LOW findings accepted with rationale
   - Confirm test tasks are present for each user story
   - Tell the user to run `/omni-spec-implement` when they are ready to begin implementation
   - Your response for this step MUST be a text message only -- no tool calls, no file edits, no implementation

**Implementation is NOT part of this command.** Use `/omni-spec-implement` to execute the tasks.

## Notes

- For a specific spec number, include it in the feature description (e.g., "spec 5: my feature")
