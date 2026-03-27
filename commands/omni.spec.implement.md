---
description: Implement a feature from its spec artifacts with post-implementation verification
---

# omni.spec.implement

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may specify a spec number or name (e.g., "005", "admin-api"), a branch name, or specific tasks to implement (e.g., "just phase 2", "T005-T010 only").

## Context-Optimization Strategy

This command reserves the main agent's context budget for **implementation and remediation** -- the two steps that benefit most from full codebase awareness. All other work is delegated to sub-agents:

- **Step 1** (main): lightweight prerequisite checks
- **Step 2** (main): implementation -- the core work that needs full context
- **Step 3** (sub-agents): verification runs in parallel, outside main context
- **Step 4** (main): remediation -- fixing issues while implementation is still in context
- **Step 5** (sub-agent): spec alignment runs outside main context
- **Step 6** (main): text-only summary

## Step 1: Verify Prerequisites

1. Run `git branch --show-current` to get the current branch
2. Verify the branch matches a `specs/` directory (e.g., branch `005-my-feature` matches `specs/005-my-feature/`). If not on a feature branch, check user input for a spec reference and `git checkout` the matching branch.
3. Verify these files exist in the spec directory:
   - `spec.md` (required)
   - `plan.md` (required)
   - `tasks.md` (required)
4. Read `tasks.md` and count incomplete tasks (lines with `[ ]`). If zero incomplete tasks remain, inform the user and stop.
5. If the user specified a subset of tasks, note which tasks to implement. Otherwise, implement all incomplete tasks.

If any prerequisite fails, tell the user what is missing and suggest running `/omni.spec.create` first.

## Step 2: Implement (Main Agent Context)

Read the project's `speckit.implement.md` command file at `<project-root>/.cursor/commands/speckit.implement.md` and follow its instructions to execute tasks from `tasks.md`.

**Important**: The `.cursor` directory is a dotfile directory. Glob's `**/` recursion skips dotfile directories, so you MUST use the `target_directory` parameter to search inside it explicitly.

If `speckit.implement.md` does not exist in the project, implement tasks directly:

1. Read `tasks.md` in full
2. Read `plan.md` for architecture context and project structure
3. Read `spec.md` for requirements and acceptance criteria
4. Read `data-model.md` and `contracts/` if they exist
5. Execute tasks in dependency order, respecting `[P]` parallel markers where possible
6. Mark each task as `[X]` in `tasks.md` as you complete it

This step stays in the main context because implementation requires full codebase awareness and iterative file editing.

## Step 3: Post-Implementation Verification (Sub-Agents in Parallel)

Launch **two sub-agents in parallel** via the Task tool. Both run concurrently to minimize wait time.

### Sub-Agent A: `spec-task-verifier`

Launch with `subagent_type: "spec-task-verifier"`.

The prompt needs:

1. The spec directory path (e.g., `specs/005-my-feature/`)
2. The workspace root path (absolute path)

The agent reads `tasks.md`, greps for evidence of each completed task, validates implementations are functional, and reports phantom completions or broken implementations. You do NOT need to explain the verification process in the prompt.

### Sub-Agent B: `repo-test-auditor`

Launch with `subagent_type: "repo-test-auditor"`.

The prompt needs:

1. The workspace root path (absolute path)
2. The base branch to diff against (usually `main`)

The agent discovers the repo's test framework and conventions, identifies changed source files, and audits test coverage and pattern consistency. You do NOT need to explain the audit process in the prompt.

Wait for both to complete. Capture their reports.

## Step 4: Remediation Loop (Main Agent)

Review the reports from both verification agents.

**If both agents report zero issues**: skip to Step 5.

**If either agent reports issues**:

1. Read the specific failures from each report
2. Fix the issues in code:
   - Phantom completions: implement the missing functionality
   - Broken implementations: fix the broken code
   - Missing tests: add tests following the repo's conventions
   - Pattern deviations: update tests to match repo patterns
3. Mark any newly completed tasks as `[X]` in `tasks.md`
4. Re-launch ONLY the agent(s) that reported failures, with the same parameters
5. Review the new reports

**Cap at 2 remediation cycles.** If issues persist after 2 cycles, include them in the summary as unresolved items rather than looping indefinitely.

## Step 5: Align Spec (Sub-Agent)

Launch a **Task** sub-agent with `subagent_type: "spec-aligner"`.

The prompt needs:

1. The spec directory path (e.g., `specs/005-my-feature/`)
2. The workspace root path (absolute path)

The agent reads all spec artifacts, compares them against the implementation, and updates spec artifacts to match what was built. You do NOT need to explain the alignment process in the prompt.

Wait for completion. Capture the deviation summary.

## Step 6: Summary (Main Agent -- Text Only)

**OUTPUT a summary and END your turn. Do NOT call any more tools.**

Present the combined results from all verification and alignment steps:

### Implementation

- Tasks completed: N of N total
- Files created/modified: brief list

### Verification Results

**Task Verification** (from spec-task-verifier):
- Verified: N tasks
- Phantom completions found and fixed: N
- Broken implementations found and fixed: N
- Unresolved issues: N (list if any)

**Test Audit** (from repo-test-auditor):
- Framework detected: [name]
- Tests present: N of N changed source files
- Missing tests found and added: N
- Pattern deviations found and fixed: N
- Unresolved issues: N (list if any)

### Spec Alignment

- Deviations found and resolved: N
- Artifacts updated: [list]
- Remaining gaps: [list or "None"]

### Next Steps

Suggest the user review the changes, run the test suite, and commit when satisfied. If there are unresolved issues from the remediation cap, list them as action items.

Your response for this step MUST be a text message only -- no tool calls, no file edits.
