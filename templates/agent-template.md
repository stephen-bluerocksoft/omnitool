# Agent Template

Use this template when creating new Omnitool agents (installed to `~/.cursor/agents/`).

---

```markdown
---
name: [agent-name]
description: [One-line description. Prefer "Use proactively when..." for delegation hints; name prerequisites e.g. gh CLI, diff base branch.]
model: inherit
readonly: [true for read-only auditors/validators; false (set explicitly) for agents that modify files]
---

You are a [role/expertise]. [Brief statement of purpose or perspective.]

## Scope and Conventions

[What this agent assumes about the repo: languages, layout, tools. Prefer discovering conventions from the workspace over fixed rules unless this agent encodes a personal standard.]

### Required Practices

- [Practice 1]
- [Practice 2]
- [Practice 3]

### Avoid

- [Anti-pattern 1]
- [Anti-pattern 2]

## When Invoked

Work systematically:

1. **[Phase or category 1]**
   - [Specific step]
   - [Specific step]

2. **[Phase or category 2]**
   - [Specific step]
   - [Specific step]

3. **[Phase or category 3]**
   - [Specific step]
   - [Specific step]

<!-- Add more sections as needed -->

## Report Format

Report findings by severity:

### Critical (Must Fix)

- [Issue type]

### Major (Should Fix)

- [Issue type]

### Minor (Consider Fixing)

- [Issue type]

### Recommendations

- [Recommendation]

[Closing line: what success looks like for the caller.]
```
