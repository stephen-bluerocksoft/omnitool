---
name: omni-spec-implement
description: Implement a feature from its spec artifacts, then verify, align the spec, and green the test suite. Use ONLY when the current feature branch already has spec.md, plan.md, and tasks.md with incomplete tasks -- never to scaffold a new spec (use omni-spec-create) and never on a vague "build X".
---

# omni.spec.implement

**Confirm before implementing.** This flow writes code across many files, rewrites the spec artifacts to match what was built, and runs the full test suite -- fixing pre-existing failures too (Step 6). Before running Step 1, state which spec/branch you will implement and how many incomplete tasks remain, then confirm the user wants to proceed now. Skip this confirmation only when the user explicitly invoked `/omni-spec-implement`.

## Runtime note

Speckit's implement phase is exposed as `/speckit.implement` in Claude Code (command file at `.claude/commands/speckit.implement.md`).

**Base branch**: throughout this skill, `<base>` means the repository's main integration branch. Detect it once and reuse it in every `git diff` below: try `git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p'`, and if that is empty fall back to whichever of `main` or `master` exists (`git rev-parse --verify main` / `git rev-parse --verify master`).

## Step 1: Verify Prerequisites

**Dotfile directory caution**: `.specify/` and `.claude/` are dotfile directories. Recursive glob patterns (`**/`) silently skip them. List them with an `ls` shell command -- never rely on glob alone.

1. Run `ls -d .specify/ .claude/commands/speckit.implement.md 2>/dev/null` to confirm speckit is initialized
2. Run `git branch --show-current` to get the current branch
3. Verify the branch matches a `specs/` directory (e.g., branch `005-my-feature` matches `specs/005-my-feature/`). If not on a feature branch, check user input for a spec reference and `git checkout` the matching branch.
4. Verify these files exist in the spec directory:
   - `spec.md` (required)
   - `plan.md` (required)
   - `tasks.md` (required)
5. Read `tasks.md` and count incomplete tasks (lines with `[ ]`). If zero incomplete tasks remain, inform the user and stop.
6. If the user specified a subset of tasks, note which tasks to implement. Otherwise, implement all incomplete tasks.

If any prerequisite fails, tell the user what is missing and suggest running `/omni-spec-create` first.

## Step 2: Implement

Run the Speckit implement phase to execute tasks from `tasks.md`: invoke `/speckit.implement`.

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

2. **Identify changed code** -- run `git diff <base> --name-only --diff-filter=AM`, filter to source files only, and determine each file's expected test location based on discovered conventions.

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

## Step 5: Align the Spec

Bring the spec artifacts back in line with what was actually built -- the implementation is the source of truth at this point.

Do NOT re-derive the alignment procedure here. Run the **omni-spec-align** skill, which is the single source of truth for spec alignment: pass it the spec directory for the current branch. Because the implement confirmation at the top of this skill already covers this work, omni-spec-align runs as a **sub-step of omni-spec-implement** and skips its own confirmation gate.

When it returns, carry its "Artifacts Updated" and "Remaining Gaps" results into the Step 7 summary.

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

Run all detected test layers. Independent layers (backend, frontend, E2E) can be launched in parallel as background shell commands, then monitor each for completion.

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
