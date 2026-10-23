# Task Splitting

How the tasks in a feature's `tasks.md` are cut. `omni-spec-create` checks the generated tasks against it, and `omni-spec-modify` applies it to every task it adds or rescopes.

## One deliverable per task

Split a task that combines several distinct UI or code changes, so that each task produces exactly one verifiable artifact.

**Bad**: "Update React components for payroll settings and timesheet labels"

**Good**:

- T022a: Rename `biweekly` to `pay-period` in types, services, and component labels
- T022b: Add `pay_frequency` select, `semi_monthly_split_day` input, `week_start_day` select to PayPeriodManagement
- T022c: Make info/description text dynamic based on selected frequency

## Name the concrete outputs

Every UI task lists the specific elements it adds or changes (form fields, selectors, inputs, buttons). Every API task lists the specific endpoints or fields.

## Cover every configurable field

When a task updates the UI for a feature, cross-check `contracts/` for the full list of fields: the task names a control for every user-configurable one.

## Separate rename from create

Renaming existing code and adding new functionality are independent deliverables. Never combine them in one task.
