---
description: Create spec artifacts for a feature using the spec-first development workflow
---

# omni.spec.create

## User Input

```text
$ARGUMENTS
```

You **MUST** use the user input as the feature description. If empty, ask the user what feature they want to build before proceeding.

This command ALWAYS creates a new spec. Even if an existing spec directory seems related, create a new spec -- do NOT modify or extend existing specs.

## Execution Constraint

Do NOT use the Task tool to delegate work to subagents. Execute all steps sequentially in the main agent context. Subagents default to a lesser model (Composer 2) that degrades quality for judgment-intensive work.

## Step 1: Verify Speckit Initialization

Check if speckit command files exist **in the current project/workspace root directory** at `<project-root>/.cursor/commands/speckit.*.md` (e.g., `speckit.specify.md`, `speckit.plan.md`). Do NOT check `~/.cursor/commands/` -- that is the user-level directory where this command lives, not the project directory.

**Important**: The `.cursor` directory is a dotfile directory. Glob's `**/` recursion skips dotfile directories, so you MUST use the `target_directory` parameter to search inside it explicitly.

If the project's `.cursor/commands/` directory does NOT contain any `speckit.*.md` files:

1. `cp .specify/memory/constitution.md /tmp/constitution-backup.md`
2. `specify init --here --ai cursor-agent --force`
3. `cp /tmp/constitution-backup.md .specify/memory/constitution.md`

If speckit commands already exist in the project, continue.

## Step 2: Create Feature Spec

1. Read the speckit specify command at `<project-root>/.cursor/commands/speckit.specify.md` for the detailed workflow instructions
2. Run `.specify/scripts/bash/create-new-feature.sh --json --short-name "<short-name>" "<description>"` using the user's feature description
   - Derive the `short-name` from the feature description (lowercase, hyphenated, concise)
   - If a specific spec number was requested, add `--number N` to the command
3. Follow the speckit.specify.md instructions to fill `spec.md`:
   - Use the template at `.specify/templates/spec-template.md`
   - Write user stories, requirements, acceptance criteria, and success metrics based on the feature description
4. Create `specs/<branch-name>/checklists/requirements.md` and validate the checklist against the spec
5. Record the **branch name** and **spec directory path** for subsequent steps

## Step 3: Clarify (Interactive)

1. Read the `spec.md` file created in Step 2
2. Look for `[NEEDS CLARIFICATION]` markers and genuine ambiguities
3. Ask the user targeted questions in a single focused batch
4. Encode answers back into `spec.md`

If there are no ambiguities or markers, state that and move on. Do not invent questions for the sake of having them.

## Step 4: Plan, Tasks, and Analysis

Execute these phases in order using the spec directory and branch from Step 2:

### 4a: Plan

1. Run `git checkout <branch>` to ensure you are on the feature branch
2. Read and follow `<project-root>/.cursor/commands/speckit.plan.md`
3. This fills: plan.md, research.md, data-model.md, contracts/, quickstart.md

### 4b: Tasks

1. Read and follow `<project-root>/.cursor/commands/speckit.tasks.md`
2. This generates tasks.md from the plan

### 4c: Checklist

1. Read and follow `<project-root>/.cursor/commands/speckit.checklist.md`

### 4d: Analyze and Remediate

1. Read and follow `<project-root>/.cursor/commands/speckit.analyze.md`
2. Remediate ALL findings using these severity rules:

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

### 4e: Enforce Test Coverage

Review tasks.md and verify every user story has at least one corresponding test task:

- Test tasks MUST appear BEFORE their corresponding implementation tasks
- Each test task specifies: file path, what it tests, expected pass/fail criteria
- Follow the project's test framework (check plan.md Technical Context)
- If test tasks are missing, add them

## Step 5: Verify and Summarize

1. Run `git branch --show-current` to confirm you are on the feature branch matching the spec folder name
2. **OUTPUT a summary and END your turn. Do NOT call any more tools.**
   - Present what was created: spec.md, plan.md, tasks.md, and any contracts or data models
   - Include a table of analysis findings that were addressed and how each was resolved
   - List any LOW findings accepted with rationale
   - Confirm test tasks are present for each user story
   - Tell the user to run `/omni.spec.implement` when they are ready to begin implementation
   - Your response for this step MUST be a text message only -- no tool calls, no file edits, no implementation

**Implementation is NOT part of this command.** Use `/omni.spec.implement` to execute the tasks.

## Notes

- For a specific spec number, include it in the feature description (e.g., "spec 5: my feature")
