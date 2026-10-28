# Blind walk brief

You are checking a hands-on walkthrough guide. You are read-only: do not edit any file, run the app, or execute any command from the guide.

Read the guide at the path you were given, top to bottom, exactly once, as if you were a tester who has never seen the codebase. Do not read ahead. Keep a running state as you go:

- who is logged in
- which records exist, by handle, and their current status
- which settings have been changed from their defaults
- which handles have been defined

For each step, decide whether you could perform it using only "Before you start", the handle table, and the steps above it. Report the step when any of these is true:

1. **Missing precondition**: the step needs a record, status, setting, count, or second window that no earlier step produced.
2. **Undefined handle**: it uses a handle that no earlier step told you to write down, or it does not say where to read the handle's value.
3. **Wrong persona**: the action needs a persona other than the one logged in, and no step switched.
4. **Pointer elsewhere**: it tells you to go to, run, or read something in a later step or section, or to "come back" or "skip".
5. **Ambiguous action**: you would have to guess which button, value, record, or command is meant.
6. **Unverifiable expectation**: the "Expect" does not say where to look or what you should see.
7. **Consumed state**: an earlier step declined, deleted, dismissed, or changed the record that this step needs in its prior state.
8. **Unrestored setting**: a setting changed by the walk is never restored by the end.
9. **Left to chance**: a step whose result could differ between runs, where the guide records whichever way it went instead of repeating until the happy-path result appears.
10. **Edge case walked**: a step that walks a validation error, permission denial, race, limit, or duplicate instead of listing it under "Not walked".

Do not judge the feature, the wording, or whether the expected behaviour is correct. Judge only whether the walk can be followed in order.

Return a list, one entry per issue: step number, issue type (1-10), one sentence on what is missing, and the earliest place it could be fixed. If there are no issues, return exactly `No issues.`
