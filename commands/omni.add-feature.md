---
description: Run the spec-first development workflow for a feature or change
---

# omni.add-feature

## User Input

```text
$ARGUMENTS
```

You **MUST** use the user input as the feature description. If empty, ask the user what feature they want to build before proceeding.

This command ALWAYS creates a new spec. Even if an existing spec directory seems related, create a new spec — do NOT modify or extend existing specs.

## Context-Optimization Strategy

This command delegates heavy spec-creation work to dedicated **sub-agents** via the Task tool, preserving the main conversation context for later implementation. The main agent handles orchestration and the interactive clarify step only.

- **Step 2** uses `subagent_type: "spec-creator"` — knows the speckit specify workflow
- **Step 4** uses `subagent_type: "spec-planner"` — knows plan, tasks, analyze, remediate, and test coverage

## Step 1: Verify Speckit Initialization

Check if speckit command files exist **in the current project/workspace root directory** at `<project-root>/.cursor/commands/speckit.*.md` (e.g., `speckit.specify.md`, `speckit.plan.md`). Do NOT check `~/.cursor/commands/` — that is the user-level directory where this command lives, not the project directory.

**Important**: The `.cursor` directory is a dotfile directory. Glob's `**/` recursion skips dotfile directories, so you MUST use the `target_directory` parameter to search inside it explicitly.

If the project's `.cursor/commands/` directory does NOT contain any `speckit.*.md` files:

1. `cp .specify/memory/constitution.md /tmp/constitution-backup.md`
2. `specify init --here --ai cursor-agent --force`
3. `cp /tmp/constitution-backup.md .specify/memory/constitution.md`

If speckit commands already exist in the project, continue.

## Step 2: Create Feature Spec (Sub-Agent)

Launch a **Task** sub-agent with `subagent_type: "spec-creator"`.

The prompt only needs:

1. The feature description (paste the user's input verbatim)
2. The workspace root path (absolute path)
3. If a specific spec number was requested, include that

The `spec-creator` agent already knows the speckit workflow, file locations, and what to return. You do NOT need to explain the process in the prompt.

Wait for completion. Capture the **branch name** and **spec directory path** from the response.

## Step 3: Clarify (Main Agent — Interactive)

This step requires user interaction, so it stays in the main context. Keep it concise.

1. Read the `spec.md` file created by the sub-agent in Step 2
2. Look for `[NEEDS CLARIFICATION]` markers and genuine ambiguities
3. Ask the user targeted questions in a single focused batch
4. Encode answers back into `spec.md`

If there are no ambiguities or markers, state that and move on. Do not invent questions for the sake of having them.

## Step 4: Plan, Tasks, and Analysis (Sub-Agent)

Launch a **Task** sub-agent with `subagent_type: "spec-planner"`.

The prompt only needs:

1. The branch name from Step 2
2. The spec directory path from Step 2
3. The workspace root path
4. Whether spec.md was updated with clarifications in Step 3

The `spec-planner` agent already knows the plan/tasks/analyze/remediate workflow, severity rules, test coverage requirements, and what to return. You do NOT need to explain the process in the prompt.

Wait for completion.

## Step 5: Verify and Summarize (Main Agent)

1. Run `git branch --show-current` to confirm you are on the feature branch matching the spec folder name
2. **OUTPUT a summary and END your turn. Do NOT call any more tools.**
   - Present what was created: spec.md, plan.md, tasks.md, and any contracts or data models
   - Include a table of analysis findings that were addressed and how each was resolved
   - List any LOW findings accepted with rationale
   - Confirm test tasks are present for each user story
   - Ask the user to review the spec artifacts and confirm they want to proceed with implementation
   - Your response for this step MUST be a text message only — no tool calls, no file edits, no implementation

**Implementation is NOT part of this command** — it begins only when the user explicitly runs it in a subsequent turn.

## Notes

- Steps 1, 3, and 5 run in the main context (lightweight — verification, Q&A, summary only)
- Steps 2 and 4 run in dedicated sub-agents (heavy lifting stays out of main context)
- The main context retains only: user input, clarify Q&A, and two sub-agent summaries
- This leaves maximum context budget available for subsequent implementation
- For a specific spec number, include it in the feature description (e.g., "spec 5: my feature")
