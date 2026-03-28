# Documentation from Codebase

All documentation MUST be sourced strictly from the codebase. Never fabricate content.

## Principles

- **Truth from Source**: Documentation must reflect what actually exists in the code
- **No Fabrication**: Never invent examples, configurations, or implementation details
- **No Line Numbers**: Do not reference specific line numbers in documentation (they change frequently)
- **Docs Ship with Code**: When a project has a `docs/` directory, update relevant docs in the same change as code. Do not let them drift.

## Where Documentation Belongs

Different types of documentation have different right places. Putting the wrong type in the wrong place causes drift, duplication, or loss.

| Documentation Need | Right Place | Wrong Place |
| --- | --- | --- |
| Function behavior, params, returns, exceptions | Docstrings | Separate file |
| System architecture, data flow, component relationships | `docs/architecture.md` | Scattered across docstrings |
| Process documentation (e.g., how PDF generation works end-to-end) | `docs/` | A single function's docstring |
| Setup guides (SSO, deployment) | `docs/` or `QUICKSTART.md` | Code comments |
| Why a decision was made | ADR or `research.md` in spec | Nowhere |
| Project conventions for AI agents | `AGENTS.md` | User rules |
| API endpoint contracts | Docstrings + `docs/api-reference.md` when auto-gen is unavailable | Only in code with no external reference |

When in doubt, follow the project's constitution or `AGENTS.md` for where documentation belongs.

## Before Writing Documentation

1. **Read the implementation first** -- understand what the code actually does before documenting it
2. **Copy real examples** -- use actual code snippets, not invented ones
3. **Check current behavior** -- run the code to confirm documented behavior
4. **Use function/class names** -- reference by name, not line number

## What NOT to Do

| Violation | Why It's Wrong |
| --------- | -------------- |
| Inventing example configurations | Creates confusion when they don't work |
| Making up API endpoints | Leads to integration failures |
| Fabricating implementation details | Misleads developers about actual behavior |
| Referencing line numbers | Breaks as soon as code changes |
