---
description: Execute a Cursor Plan Mode plan with post-implementation verification and proactive test creation
---

# omni.plan.implement

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may specify a plan name (e.g., "fix e2e test flakes"), a file path, or specific todos to implement (e.g., "just the tests todo", "skip docs").

## Execution Constraint

Do NOT use the Task tool to delegate work to subagents. Execute all steps sequentially in the main agent context. Subagents default to a lesser model (Composer 2) that degrades quality for judgment-intensive work.

## Step 1: Find and Read the Plan

Locate the `.plan.md` file to execute:

1. **If `$ARGUMENTS` contains a file path** (ends in `.plan.md` or contains `/`): read that file directly.

2. **Otherwise, auto-detect**:
   a. Search the workspace for `*.plan.md` files using `ls *.plan.md .cursor/plans/*.plan.md 2>/dev/null`
   b. If no workspace plans found, search `~/.cursor/plans/` using `ls -t ~/.cursor/plans/*.plan.md 2>/dev/null | head -20`
   c. If `$ARGUMENTS` is not empty, filter candidates by matching the user input against filenames (case-insensitive partial match)
   d. If multiple candidates remain, pick the most recently modified file. If the top candidates were modified within 60 seconds of each other, list them and ask the user which one to use.

3. **Read the plan file**. Parse:
   - YAML frontmatter: `name`, `overview`, `todos` (array of `{id, content, status, dependencies}`)
   - Markdown body: implementation details, file paths, code snippets, approach descriptions

4. **Count incomplete todos** (status is not `completed`). If zero remain, inform the user that all todos are already complete and stop.

5. If the user specified a subset of todos, note which to implement. Otherwise, implement all incomplete todos.

6. **Read project context**: read `AGENTS.md` and `.specify/memory/constitution.md` if they exist in the project root, for conventions and constraints.

## Step 2: Implement

Execute each incomplete todo in order, respecting `dependencies` in the frontmatter (a todo with dependencies must wait until all dependencies are completed).

For each todo:

1. Read the plan body sections relevant to this todo -- look for file paths, code snippets, and approach descriptions that correspond to the todo's `content`
2. Implement the changes described
3. Update the todo's `status` to `completed` in the plan file's YAML frontmatter

If the plan body references files to read for context (existing code, configs, schemas), read them before making changes.

## Step 3: Write Tests

**Guard**: run `git diff HEAD --name-only --diff-filter=AM` and filter to source files only. Exclude non-source files: `*.md`, `*.json`, `*.yaml`, `*.yml`, `*.toml`, `*.cfg`, `*.ini`, `*.lock`, `*.css`, `*.scss`, `*.svg`, `*.png`, `*.jpg`, `*.gif`, `*.ico`, `*.woff`, `*.woff2`, `*.ttf`, `*.eot`, `*.map`. If zero source files were changed, skip this step entirely.

If source files were changed:

1. **Discover test setup** -- find test directories and identify the test framework from config files (`pytest.ini`, `pyproject.toml [tool.pytest]`, `jest.config.*`, `vitest.config.*`, etc.). Read 3-5 existing test files and extract naming patterns, directory structure, fixture/import patterns, assertion style, and mocking approach. If no test infrastructure exists at all (no framework config, no test directory, no existing tests), skip this step and note it in the summary.

2. **Identify changed source files** -- from the filtered `git diff` output, list every source file that was created or modified.

3. **Write tests** -- for every changed source file, determine the expected test file location based on discovered conventions, then:
   - If the test file does not exist, create it following repo patterns for naming, fixtures, assertions, and mocking
   - If the test file already exists, extend it to cover new/changed functionality rather than replacing existing tests
   - Tests must cover the public API of each changed file
   - Follow the project's test framework and assertion style exactly

## Step 4: Post-Implementation Verification

After implementation and test creation are complete, verify the work directly. Execute both verification passes sequentially.

### 4a: Todo Verification

Verify that every todo marked `completed` has real, functioning implementation:

1. **Parse todos** -- extract every todo with status `completed`. For each, record the id, content, file paths mentioned in the plan body for that todo, and keywords that identify the deliverable.

2. **Grep for evidence** -- for each claimed-complete todo:
   - Check that all file paths mentioned in the plan body for this todo actually exist
   - Grep target directories for keywords from the todo content -- zero hits means no evidence
   - If the todo specifies concrete outputs (e.g., "add 3 tests"), count them
   - If the plan body says "create" a file, verify the file is new; if "modify," verify it was changed

3. **Functional validation** -- for todos where files exist:
   - Read the file and check that imported modules/packages exist
   - Look for TODO comments, `pass` statements, `NotImplementedError`, empty function bodies, or stub implementations
   - If the todo involves connecting components (routes, middleware, DI), verify the wiring in entry point files

4. **Cross-reference with plan body** -- compare the plan's "Files to Modify" or equivalent sections against what was actually changed. Flag any files the plan mentions that were not touched, and any changes made that the plan did not describe.

Record results as: verified todos, phantom completions (marked done but no evidence), broken implementations (files exist but incomplete), and uncovered plan sections.

### 4b: Test Audit

Audit test coverage and pattern consistency for changed code:

1. **Identify changed code** -- run `git diff HEAD~1 --name-only --diff-filter=AM` (or against the appropriate base), filter to source files only, and determine each file's expected test location based on discovered conventions.

2. **Audit tests** -- for each changed source file, check:
   - Does the expected test file exist?
   - Does it follow the repo's naming, fixture, and assertion patterns?
   - Does it cover the source file's public API?
   - Does it compile/parse without errors?

Record results as: missing tests, pattern deviations, and coverage gaps.

## Step 5: Remediation Loop

Review the results from both verification passes (Step 4a and 4b).

**If both passes report zero issues**: skip to Step 6.

**If either pass found issues**:

1. Read the specific failures from each result set
2. Fix the issues in code:
   - Phantom completions: implement the missing functionality
   - Broken implementations: fix the broken code
   - Missing tests: add tests following the repo's conventions
   - Pattern deviations: update tests to match repo patterns
3. Update any newly completed todos in the plan file frontmatter
4. Re-run ONLY the verification pass(es) that found failures
5. Review the new results

**Cap at 2 remediation cycles.** If issues persist after 2 cycles, include them in the summary as unresolved items rather than looping indefinitely.

## Step 6: Run Full Test Suite

Run the complete test suite. Fix **all** failures -- not just regressions introduced by the current changes.

### 6a: Detect Test Layers

Check which test layers exist by looking for these indicators:

| Layer | Detection | Run Command |
| ----- | --------- | ----------- |
| Backend (pytest) | `pytest.ini`, `pyproject.toml [tool.pytest]`, or `tests/` with `.py` test files | `cd backend && pytest` (activate venv first) |
| Frontend (Jest/Vitest) | `package.json` with `test` script in frontend dir | `cd frontend && npm test -- --watchAll=false` |
| E2E (Playwright) | `playwright.config.ts`, `playwright.config.js`, or `e2e/` directory with `.spec.ts` files | `cd e2e && npx playwright test` (or project-root-level `npx playwright test` depending on config location) |

Only run layers that actually exist. If a layer's detection files are absent, skip it. If no test layers are detected at all, skip this step and note it in the summary.

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

Do NOT dismiss failures as "pre-existing" or "unrelated to this change." A green suite is the goal.

**Cap at 3 remediation cycles.** If failures persist after 3 cycles, stop and include the remaining failures in the summary as unresolved items with root-cause analysis for each.

## Step 7: Summary (Text Only)

**OUTPUT a summary and END your turn. Do NOT call any more tools.**

Present the combined results from all steps:

### Plan

- Plan: [plan name]
- Todos completed: N of N total

### Implementation

- Files created/modified: brief list

### Tests Written

- Source files changed: N
- Test files created: N
- Test files extended: N
- Skipped (no test infrastructure / no source changes): yes/no

### Verification Results

**Todo Verification**:
- Verified: N todos
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

### Next Steps

Suggest the user review the changes and commit when satisfied. If there are unresolved issues from any remediation cap (Step 5 or Step 6), list them as action items. Do NOT suggest running the test suite -- it has already been run.

Your response for this step MUST be a text message only -- no tool calls, no file edits.
