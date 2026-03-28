# Spec-First Development

Specifications are the source of truth. Code follows specifications, never the reverse. This rule applies to projects that use Speckit (have a `.specify/` or `specs/` directory). For projects without specs, follow the project's `AGENTS.md` and constitution if present.

## Project Context

Before making changes to any project, read these documents if they exist:

1. **`AGENTS.md`** -- project structure, conventions, technical context, development guidelines
2. **`.specify/memory/constitution.md`** -- governing principles that supersede informal practices

These documents are the project's source of truth. Read them before writing code.

## Workflows

- **New features**: Use `/omni.spec.create` to generate spec artifacts, then `/omni.spec.implement` to execute tasks.
- **Changes to existing features**: Read the current spec in `specs/{nnn}-{name}/`, update spec artifacts as needed, checkout the spec branch, THEN make code changes.
- **Bug fixes**: If the bug deviates from spec, fix code to match spec. If the spec was wrong, update spec first, then fix code. Document in the spec's edge cases section.

## Before Making Code Changes

1. **Verify branch**: Must NOT be on `main`/`master`. Run `git branch --show-current`.
2. **Read project context**: Read `AGENTS.md` and `.specify/memory/constitution.md` if not already read in this session.
3. **Identify the spec**: Check `specs/` for the relevant feature. Review spec.md, plan.md, tasks.md, data-model.md.
4. **Resolve open items**: Check research.md for unresolved items; resolve before implementing.
5. **Verify spec coverage**: The change MUST be documented in the spec. If not, update the spec first.
6. **Check for drift**: If code contradicts the spec, the SPECIFICATION is correct.

## Specification Hierarchy (highest authority first)

1. `.specify/memory/constitution.md` -- Project principles
2. `specs/[feature]/spec.md` -- Feature requirements
3. `specs/[feature]/plan.md` -- Technical architecture
4. `specs/[feature]/data-model.md` -- Entity definitions
5. `specs/[feature]/contracts/` -- API contracts
6. `specs/[feature]/tasks.md` -- Task breakdown

## Red Flags

| Situation | Action |
| --------- | ------ |
| On main/master and about to implement | STOP. Create/checkout spec branch |
| Branch name doesn't match spec folder | STOP. Checkout correct branch |
| Not sure what the spec wants | Use `/speckit.clarify` |
| Change isn't in the spec | Update the spec first |
| Spec says X but code does Y | Fix code OR update spec with justification |
| Task isn't in tasks.md | Add it first |
| API doesn't match contract | Update contract OR fix API |
| Unresolved open item in research.md | Resolve before implementing |
