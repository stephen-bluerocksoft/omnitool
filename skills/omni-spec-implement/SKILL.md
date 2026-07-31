---
name: omni-spec-implement
description: Implement a feature from its spec artifacts, then converge it against the spec, align the spec, and green the test suite. Use ONLY when the current feature branch already has spec.md, plan.md, and tasks.md -- whether tasks remain open or the list is already fully checked off, since convergence verifies the code actually satisfies the spec either way. Never use it to scaffold a new spec (use omni-spec-create) and never on a vague "build X".
---

# omni.spec.implement

**Confirm before implementing.** This flow writes code across many files, rewrites the spec artifacts to match what was built, and runs the full test suite -- fixing pre-existing failures too (Step 6). Before running Step 1, state which spec/branch you will implement and how many incomplete tasks remain, then confirm the user wants to proceed now. Skip this confirmation only when the user explicitly invoked `/omni-spec-implement`.

## Runtime note

This skill drives two Speckit skills through the Skill tool (names are hyphenated, not dotted):

- **`speckit-implement`** (`.claude/skills/speckit-implement/SKILL.md`) -- executes the tasks in `tasks.md`.
- **`speckit-converge`** (`.claude/skills/speckit-converge/SKILL.md`) -- assesses the codebase against `spec.md`, `plan.md`, `tasks.md`, and the constitution, then **appends** whatever is still unbuilt as a new `## Phase N: Convergence` section in `tasks.md`. It is append-only: it never edits the spec, never renumbers existing tasks, and never touches application code.

Converge is the verification engine for this workflow -- do NOT hand-roll a task-verification pass alongside it. It checks more than a task-by-task audit does: every FR/SC/acceptance scenario, the plan's technical decisions, constitution MUST principles, and `unrequested` code the artifacts never asked for.

Older Speckit versions installed a slash-command file at `.claude/commands/speckit.implement.md`, and versions before converge shipped no `speckit-converge` skill at all. Neither is supported -- see Step 1.

**Base branch**: throughout this skill, `<base>` means the repository's main integration branch. Detect it once and reuse it in every `git diff` below: try `git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p'`, and if that is empty fall back to whichever of `main` or `master` exists (`git rev-parse --verify main` / `git rev-parse --verify master`).

## Step 1: Verify Prerequisites

**Dotfile directory caution**: `.specify/` and `.claude/` are dotfile directories. Recursive glob patterns (`**/`) silently skip them. List them with an `ls` shell command -- never rely on glob alone.

1. Run `ls -d .specify/ .claude/skills/speckit-implement/ .claude/skills/speckit-converge/ .claude/commands/speckit.implement.md 2>/dev/null` to confirm Speckit is initialized, on the skills layout, and new enough to provide converge:
   - `.specify/`, `.claude/skills/speckit-implement/`, and `.claude/skills/speckit-converge/` all present -- continue
   - `.claude/commands/speckit.implement.md` present but `.claude/skills/speckit-implement/` absent -- **STOP**, outdated Speckit (see below)
   - skills layout present but `.claude/skills/speckit-converge/` absent -- **STOP**, outdated Speckit (see below); this workflow depends on converge for verification
   - `.specify/` absent -- not initialized; tell the user to run `/omni-spec-create` and stop
2. Run `git branch --show-current` to get the current branch
3. Verify the branch matches a `specs/` directory (e.g., branch `005-my-feature` matches `specs/005-my-feature/`). If not on a feature branch, check user input for a spec reference and `git checkout` the matching branch.
4. Verify these files exist in the spec directory:
   - `spec.md` (required)
   - `plan.md` (required)
   - `tasks.md` (required)
5. Read `tasks.md` and count incomplete tasks (lines with `[ ]`). If zero incomplete tasks remain, do NOT stop -- every task being checked off is a claim, not proof. Tell the user the task list is already complete and that you are running a convergence check to confirm the code actually satisfies the spec, then **skip Step 2 and start at Step 3a**. Converge will either report `converged` or append the work that is genuinely still missing.
6. If the user specified a subset of tasks, note which tasks to implement. Otherwise, implement all incomplete tasks.

If any prerequisite fails, tell the user what is missing and suggest running `/omni-spec-create` first.

### Outdated Speckit

Either the project uses the legacy slash-command layout, or it predates `speckit-converge`. Both are unsupported: this workflow requires the skills layout **and** the converge skill. **Do NOT fall back to the `.claude/commands/speckit.*.md` files, do NOT substitute a hand-rolled verification pass for converge, and do NOT proceed** -- report the following to the user and END your turn:

> This project's Speckit install is out of date -- it is missing `.claude/skills/speckit-converge/` (and may still use the legacy `.claude/commands/speckit.*.md` layout). The omni spec workflow requires the skills layout plus converge. To upgrade:
>
> ```sh
> cp .specify/memory/constitution.md "/tmp/speckit-constitution-$(basename "$PWD").md"
> specify self upgrade
> specify init --here --integration claude --force
> cp "/tmp/speckit-constitution-$(basename "$PWD").md" .specify/memory/constitution.md
> rm -f .claude/commands/speckit.*.md
> ```
>
> Re-run `/omni-spec-implement` once the upgrade is done.

## Step 2: Implement

Run the Speckit implement phase to execute tasks from `tasks.md`: invoke the `speckit-implement` skill.

## Step 3: Post-Implementation Verification

Two passes, run in order. **3a (converge)** covers spec compliance -- requirements, plan decisions, constitution. **3b (test audit)** covers what converge deliberately does not: whether the repo's own testing conventions are honoured for the code that changed.

### 3a: Converge

Converge is the spec-compliance verification pass. **Do NOT hand-roll a task-by-task audit here** -- `speckit-converge` already inventories every functional requirement, success criterion, acceptance scenario, plan decision, and constitution MUST principle, then appends what is still unbuilt as tasks. Reimplementing that is duplicated, weaker work.

Run the converge/implement cycle until the feature converges:

1. Invoke the `speckit-converge` skill. It reports one of two outcomes:
   - **`converged`** -- the implementation satisfies the spec, plan, and tasks. `tasks.md` is left byte-for-byte unchanged. Record the summary counts and go to Step 3b.
   - **`tasks_appended`** -- it appended a `## Phase N: Convergence` section to `tasks.md` with one task per finding, ordered CRITICAL/HIGH first and traced to a `source-ref` (`FR-003`, `US1/AC2`, `plan: storage decision`, `Constitution II`) and a `gap-type` (`missing`, `partial`, `contradicts`, `unrequested`).

2. On `tasks_appended`, record the findings table, then invoke `speckit-implement` again to execute the newly appended Phase N tasks.

3. Re-run `speckit-converge`. Repeat until it reports `converged`.

**Cap at 3 converge cycles.** Stop early if a cycle stops making progress -- if a converge run appends as many findings as the one before it, or re-appends the same `source-ref`s, further cycles will not converge either. In both cases carry the outstanding findings into the Step 7 summary as unresolved items rather than looping.

Handling specific gap types:

- **`contradicts` against a constitution MUST principle** is the highest-severity finding. Never resolve it by weakening the constitution -- fix the code.
- **`unrequested`** means the code contains work the spec, plan, and tasks never called for. This is a BRS standards violation ("the simplest solution that satisfies the spec wins"), not a nice-to-have. Default to removing the unrequested code. If it is genuinely load-bearing, it belongs in the spec -- say so in the Step 7 summary and recommend `/omni-spec-modify` rather than quietly keeping it.
- Converge does **not** un-mark phantom `[X]` tasks; it captures the remaining work as new tasks instead. Do not go back and edit the old checkboxes.

Checkbox integrity is handled a layer down, not here. When the BRS Codex `orchestrating-speckit-implementation` skill is installed, it runs inside every `speckit-implement` call and gates on `spec-task-verifier`, which confirms each `[X]` is backed by real, non-stub code. Converge covers spec-satisfaction; that pass covers task-claim integrity. Do not add a third verification pass of your own on top of either.

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

## Step 4: Test Remediation Loop

Spec-compliance gaps were already closed by the converge/implement cycle in Step 3a -- do not re-remediate them here. This step resolves the **Step 3b test-audit findings only**.

**If the test audit reported zero issues**: skip to Step 5.

**If the test audit found issues**:

1. Read the specific findings from the audit result set
2. Fix them:
   - Missing tests: add tests following the repo's conventions
   - Pattern deviations: update tests to match repo patterns
   - Coverage gaps: extend the existing tests to cover the untested public API
3. Re-run the test audit
4. Review the new results

**Cap at 2 remediation cycles.** If issues persist after 2 cycles, include them in the summary as unresolved items rather than looping indefinitely.

If adding tests surfaces a genuine implementation gap that the spec calls for, do not patch it silently. Return to Step 3a and run one more converge cycle (within its 3-cycle cap) so the gap is captured as a traceable, `source-ref`-linked task. If the cap is already spent, record it as an unresolved item in the Step 7 summary.

## Step 5: Align the Spec

Bring the spec artifacts back in line with what was actually built -- the implementation is the source of truth at this point.

**Order matters: alignment MUST come after convergence, never before.** Converge treats `spec.md` and `plan.md` as the source of intent and is append-only against them; align rewrites them to match the code. Aligning first would rewrite the spec to describe whatever was built -- including unrequested code -- and converge would then have nothing left to find. Step 3a establishes what the spec demanded; Step 5 records what was actually delivered.

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

- Tasks completed: N of N total (including N appended by convergence)
- Files created/modified: brief list

### Verification Results

**Convergence**:

- Final outcome: `converged` or unresolved after N cycles
- Converge cycles run: N of 3
- Requirements / acceptance criteria checked: N; plan decisions checked: N; constitution principles checked: N (or "skipped -- template")
- Findings by gap type: N missing, N partial, N contradicts, N unrequested
- Convergence tasks appended and completed: N (list any that remain outstanding, with their `source-ref` and severity)
- Constitution violations: N (list each; these are CRITICAL)
- Unrequested code: N (state what was removed, and flag anything kept that needs `/omni-spec-modify` to legitimise)

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

Suggest the user review the changes and commit when satisfied. If there are unresolved issues from any cap (Step 3a converge cycles, Step 4, or Step 6), list them as action items. If convergence did not reach `converged`, say so plainly -- the feature is not fully built to spec, and the outstanding Convergence tasks remain in `tasks.md` for a follow-up `/omni-spec-implement` run. Do NOT suggest running the test suite -- it has already been run.

Your response for this step MUST be a text message only -- no tool calls, no file edits.
