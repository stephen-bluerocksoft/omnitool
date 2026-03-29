---
description: Implement a feature from its spec artifacts with post-implementation verification
---

# omni.spec.implement

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may specify a spec number or name (e.g., "005", "admin-api"), a branch name, or specific tasks to implement (e.g., "just phase 2", "T005-T010 only").

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

## Step 2: Implement

Read the project's `speckit.implement.md` command file at `<project-root>/.cursor/commands/speckit.implement.md` and follow its instructions to execute tasks from `tasks.md`.

**Important**: The `.cursor` directory is a dotfile directory. Glob's `**/` recursion skips dotfile directories, so you MUST use the `target_directory` parameter to search inside it explicitly.

If `speckit.implement.md` does not exist in the project, implement tasks directly:

1. Read `tasks.md` in full
2. Read `plan.md` for architecture context and project structure
3. Read `spec.md` for requirements and acceptance criteria
4. Read `data-model.md` and `contracts/` if they exist
5. Execute tasks in dependency order, respecting `[P]` parallel markers where possible
6. Mark each task as `[X]` in `tasks.md` as you complete it

## Step 3: Post-Implementation Verification

After implementation is complete, verify the work directly. Execute both verification passes sequentially.

### 3a: Task Verification

Verify that every task marked `[X]` in `tasks.md` has real, functioning implementation:

1. **Parse tasks** -- extract every task marked `[X]`. For each, record the task ID, description, file paths mentioned, keywords that identify the deliverable, and whether the task says "create/add" or "update/modify".

2. **Grep for evidence** -- for each claimed-complete task:
   - Check that all file paths mentioned in the task actually exist
   - Grep target directories for keywords from the task description -- zero hits means no evidence
   - If the task specifies concrete outputs (e.g., "add 3 tests"), count them
   - If the task says "create," verify the file is new; if "update," verify it was changed

3. **Functional validation** -- for tasks where files exist:
   - Read the file and check that imported modules/packages exist
   - Look for TODO comments, `pass` statements, `NotImplementedError`, empty function bodies, or stub implementations
   - If the task involves test files, lint or typecheck them
   - If the task involves connecting components (routes, middleware, DI), verify the wiring in entry point files

4. **Cross-reference with spec** -- read `spec.md` acceptance criteria and verify at least one verified task backs each criterion. Flag uncovered acceptance criteria.

Record results as: verified tasks, phantom completions (marked done but no evidence), broken implementations (files exist but incomplete), and uncovered acceptance criteria.

### 3b: Test Audit

Audit test coverage and pattern consistency for changed code:

1. **Discover test setup** -- find test directories and identify the test framework from config files (`pytest.ini`, `jest.config.*`, `vitest.config.*`, etc.). Read 3-5 existing test files and extract naming patterns, directory structure, fixture/import patterns, assertion style, and mocking approach.

2. **Identify changed code** -- run `git diff main --name-only --diff-filter=AM`, filter to source files only, and determine each file's expected test location based on discovered conventions.

3. **Audit tests** -- for each changed source file, check:
   - Does the expected test file exist?
   - Does it follow the repo's naming, fixture, and assertion patterns?
   - Does it cover the source file's public API?
   - Does it compile/parse without errors?

Record results as: missing tests, pattern deviations, and coverage gaps.

## Step 4: Remediation Loop

Review the results from both verification passes (Step 3a and 3b).

**If both passes report zero issues**: skip to Step 5.

**If either pass found issues**:

1. Read the specific failures from each result set
2. Fix the issues in code:
   - Phantom completions: implement the missing functionality
   - Broken implementations: fix the broken code
   - Missing tests: add tests following the repo's conventions
   - Pattern deviations: update tests to match repo patterns
3. Mark any newly completed tasks as `[X]` in `tasks.md`
4. Re-run ONLY the verification pass(es) that found failures
5. Review the new results

**Cap at 2 remediation cycles.** If issues persist after 2 cycles, include them in the summary as unresolved items rather than looping indefinitely.

## Step 5: Align Spec

Update spec artifacts so they accurately describe what was built. The implementation is the source of truth.

### 5a: Read All Spec Artifacts

Read every file in the spec directory and extract:

| Artifact | What to extract |
| -------- | --------------- |
| `spec.md` | Requirements (FR-NNN), user stories, acceptance scenarios, edge cases, assumptions |
| `plan.md` | Key technical decisions, project structure listing, architecture |
| `contracts/` | API contracts -- request/response schemas, status codes, event types |
| `data-model.md` | Entities, fields, relationships, constraints |
| `research.md` | Decisions, rationale, resolved/unresolved open items |
| `tasks.md` | Task breakdown, completion status, dependency graph |
| `quickstart.md` | Setup steps, validation scenarios |

Record the last FR ID and last task ID so new IDs continue sequentially.

### 5b: Read the Actual Implementation

1. Read the project structure from `plan.md` and read every file listed there in full
2. Find files not in the plan using `git diff main --name-only` and `git diff main --stat`. Read any unlisted implementation files (not IDE config, lockfiles, etc.)
3. For each endpoint, function, or module described in the spec, read the implementation and note what it actually does

### 5c: Identify Deviations

Compare spec claims against implementation reality. For each deviation, record the category, spec claim, and implementation reality:

| Category | What to look for |
| -------- | ---------------- |
| Behavior changes | Endpoint/function does more or less than spec says |
| New features | Implemented functionality not mentioned in any spec artifact |
| Modified signatures | Function parameters, return types, API contracts changed from spec |
| New files | Scripts, tooling, config files added but not in project structure |
| Removed features | Spec describes functionality that was not implemented or was removed |
| Edge cases | New edge cases discovered and handled during implementation |
| Assumptions invalidated | Spec assumptions that turned out wrong during implementation |
| Data model changes | Fields added/removed, types changed, new relationships |

Do NOT flag trivial differences (variable naming, internal refactoring that preserves behavior). Focus on deviations that would mislead someone reading the spec.

### 5d: Update Spec Artifacts

For **each** deviation, update the spec to match what was built:

| Artifact | What to update |
| -------- | -------------- |
| `spec.md` | Add/update functional requirements (FR-NNN), acceptance scenarios, edge cases, assumptions |
| `contracts/` | Update request/response schemas, status codes, handled event types. Add new contract files if new APIs were introduced |
| `plan.md` | Update key technical decisions, project structure listing. Add new files. Remove files that were not created |
| `research.md` | Add new decisions with rationale. Remove or update invalidated decisions |
| `tasks.md` | Mark completed tasks as `[X]`. Add new tasks for work done outside the original plan |
| `quickstart.md` | Add validation scenarios for new behavior. Update setup steps if they changed |
| `data-model.md` | Update entities, fields, relationships, constraints to match actual schema |

Rules: new FRs get sequential IDs, new tasks get sequential IDs, cross-reference new FRs in the tasks that implement them, preserve existing content that is still accurate, match the style of existing content.

### 5e: Self-Verification

1. Confirm every deviation has a corresponding spec update
2. Verify new FR and task IDs are sequential with no gaps or duplicates
3. Verify new tasks reference the FRs they implement and vice versa
4. Confirm every spec update reflects actual implemented behavior, not aspirational work
5. Confirm artifacts do not contradict each other after all updates

Record: deviations found by category, artifacts updated, and remaining gaps.

## Step 6: Run Full Test Suite

Run the complete test suite. Fix **all** failures -- not just regressions introduced by the current changes. Pre-existing failures are tech debt that compounds; if the suite surfaces them, fix them now.

### 6a: Detect Test Layers

Check which test layers exist by looking for these indicators:

| Layer | Detection | Run Command |
| ----- | --------- | ----------- |
| Backend (pytest) | `pytest.ini`, `pyproject.toml [tool.pytest]`, or `tests/` with `.py` test files | `cd backend && pytest` (activate venv first) |
| Frontend (Jest/Vitest) | `package.json` with `test` script in frontend dir | `cd frontend && npm test -- --watchAll=false` |
| E2E (Playwright) | `playwright.config.ts`, `playwright.config.js`, or `e2e/` directory with `.spec.ts` files | `cd e2e && npx playwright test` (or project-root-level `npx playwright test` depending on config location) |

Only run layers that actually exist. If a layer's detection files are absent, skip it.

### 6b: Run Tests

Run all detected test layers. Independent layers (backend, frontend, E2E) can be launched in parallel using separate Shell calls with `block_until_ms: 0` to background them, then monitor each for completion.

For each layer:

1. Activate any required environment (venv for Python, node_modules for JS)
2. Run the test command
3. Capture the full output including pass/fail counts

### 6c: Fix All Failures

**If all layers pass**: record results and proceed to Step 7.

**If any layer has failures** -- whether introduced by this implementation or pre-existing:

1. Read the failure output to identify every failing test and its root cause
2. Fix the failures in code -- prioritize fixing the implementation over modifying tests, unless the test itself has a bug (e.g., stale mocks, missing context providers, incorrect assertions)
3. Re-run ONLY the layers that had failures
4. Repeat until all tests pass

Do NOT dismiss failures as "pre-existing" or "unrelated to this change." A green suite is the goal. If 37 frontend tests fail because of a missing `useAuth` context wrapper, fix them.

**Cap at 3 remediation cycles.** If failures persist after 3 cycles, stop and include the remaining failures in the summary as unresolved items with root-cause analysis for each.

## Step 7: Summary (Text Only)

**OUTPUT a summary and END your turn. Do NOT call any more tools.**

Present the combined results from all verification, alignment, and test steps:

### Implementation

- Tasks completed: N of N total
- Files created/modified: brief list

### Verification Results

**Task Verification**:
- Verified: N tasks
- Phantom completions found and fixed: N
- Broken implementations found and fixed: N
- Unresolved issues: N (list if any)

**Test Audit**:
- Framework detected: [name]
- Tests present: N of N changed source files
- Missing tests found and added: N
- Pattern deviations found and fixed: N
- Unresolved issues: N (list if any)

### Test Suite Results

For each layer that was run, report:

- **Backend**: X passed, Y failed (or "all passed")
- **Frontend**: X passed, Y failed (or "all passed")
- **E2E (Playwright)**: X passed, Y failed (or "all passed")
- Failures found and fixed: N (note which were pre-existing vs. introduced)
- Remediation cycles used: N of 3
- Unresolved failures: N (list with root-cause analysis if any)

### Spec Alignment

- Deviations found and resolved: N
- Artifacts updated: [list]
- Remaining gaps: [list or "None"]

### Next Steps

Suggest the user review the changes and commit when satisfied. If there are unresolved issues from any remediation cap (Step 4 or Step 6), list them as action items. Do NOT suggest running the test suite -- it has already been run.

Your response for this step MUST be a text message only -- no tool calls, no file edits.
