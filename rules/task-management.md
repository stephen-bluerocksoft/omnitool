# Task Management & Verification

## Task Splitting

### One deliverable per task

A task that combines multiple distinct UI or code changes MUST be split. Each task should produce exactly one verifiable artifact.

**Bad**: "Update React components for payroll settings and timesheet labels"
**Good**:

- T022a: Rename `biweekly` to `pay-period` in types, services, and component labels
- T022b: Add `pay_frequency` select, `semi_monthly_split_day` input, `week_start_day` select to PayPeriodManagement
- T022c: Make info/description text dynamic based on selected frequency

### Name the concrete outputs

Every UI task MUST list the specific elements expected (form fields, selectors, inputs, buttons). Every API task MUST list the specific endpoints or fields.

### Separate rename from create

Renaming existing code and adding new functionality are independent deliverables. Never combine them in one task.

## Verification

Before marking any task complete (in TodoWrite or tasks.md), run these checks. Never rely solely on a sub-agent's "done" signal.

1. **Grep for evidence.** Search target directories for keywords that MUST appear. If a task says "add E2E tests for semi-monthly," grep `e2e/` for `semi_monthly`. No hits = not done.

2. **Read the implementation.** Grep proves keywords exist, not that the implementation is correct. Read the created/modified files and verify the logic matches the task requirements. Watch for stub bodies, placeholder returns, empty functions, and TODO comments.

3. **Count deliverables.** If the task specifies concrete outputs (files, test cases, endpoints), verify each one exists.

4. **Verify against contracts.** When a task says "update UI for [feature]," cross-reference `contracts/` for the full list of fields. The UI MUST have controls for every user-configurable field.

5. **Distinguish update from create.** Completing one does not satisfy the other. If a task says "update/add," verify both the updates AND the additions.

6. **Run the tests.** If the task involves test files, run them (or at minimum typecheck them) before marking complete.

7. **Check acceptance criteria.** Verify against the spec's Success Criteria and Acceptance Scenarios, not just whether files were touched.

## Sub-agent Verification

- After a sub-agent returns, independently verify its output before marking complete.
- If the sub-agent was scoped narrowly (e.g., "rename X to Y"), check whether the parent task had broader scope (e.g., "rename X to Y AND add tests for Z").
- When splitting across multiple sub-agents, track and verify each sub-task separately.

## Red Flags

| Signal | Action |
| ------ | ------ |
| Sub-agent touched files but task asked for NEW files | Verify new files exist |
| Task keyword not found in target directory | Task is not complete |
| Task says "tests" but no test functions reference new behavior | Task is not complete |
| Sub-agent returned success but you didn't independently verify | Do not mark complete |
