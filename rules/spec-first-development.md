# Spec-First Development

Specifications are the source of truth. Code follows specifications, never the reverse. This rule applies to projects that use Speckit (have a `.specify/` or `specs/` directory). For projects without specs, follow the project's `AGENTS.md` and constitution if present.

## Project Context

Before making changes to any project, read these documents if they exist:

1. **`AGENTS.md`** -- project structure, conventions, technical context, development guidelines
2. **`.specify/memory/constitution.md`** -- governing principles that supersede informal practices

These documents are the project's source of truth. Read them before writing code.

## Workflows

Drive spec work through the omnitool skills -- never hand-code a speckit-style flow yourself:

- **New features**: Use `/omni-spec-create` to generate spec artifacts, then `/omni-spec-implement` to execute tasks.
- **Changes to an in-flight feature** (its spec directory is not yet on the default branch): Use `/omni-spec-modify` to change the spec first (it cascades the edit through plan, tasks, and analysis), then `/omni-spec-implement`.
- **Changes to a merged feature**: Use `/omni-spec-create` for a new feature whose `spec.md` carries a `## Supersedes` section naming the merged directory and the requirement IDs it replaces, then `/omni-spec-implement`. Never edit the merged directory.
- **Bug fixes**: If the bug deviates from spec, fix code to match spec. If the spec was wrong, change the spec first -- `/omni-spec-modify` when the feature is in flight, a new superseding spec via `/omni-spec-create` when it has merged -- then fix code.
- **Spec drifted from code during implementation**: Use `/omni-spec-align` on the in-flight feature to update its spec to match what was built. Drift from a merged spec is a bug fix or a new superseding spec, never an alignment.

**Flow-Forward specs.** BRS projects follow Speckit's Flow-Forward model: a feature directory is editable only while it is in flight on its own branch, and becomes an immutable record once it merges to the default branch (`git cat-file -e <default>:specs/<NNN-name>/spec.md` succeeds). Where two features disagree, the later one whose `## Supersedes` section claims the requirement governs.

These skills wrap Speckit's `speckit-specify`, `speckit-plan`, `speckit-tasks`, `speckit-analyze`, `speckit-implement`, and `speckit-converge` skills, which Speckit installs at `.claude/skills/speckit-*/SKILL.md`. If the `omni-spec-*` skills are not installed, fall back to invoking those `speckit-*` skills directly.

**Verify with converge, don't hand-roll it.** After implementing, `speckit-converge` assesses the code against every requirement, acceptance criterion, plan decision, and constitution MUST principle, then appends the remaining work to `tasks.md` as traceable tasks. Never write a bespoke task-verification pass in its place -- run converge, implement what it appends, and repeat until it reports `converged`.

**Speckit must be on the skills layout.** Older Speckit versions installed slash commands at `.claude/commands/speckit.*.md`. That layout is not supported: if a project has `.claude/commands/speckit.*.md` but no `.claude/skills/speckit-*/`, STOP and tell the user to upgrade (`specify self upgrade`, then `specify integration upgrade claude` and `specify extension update`; for a project that predates Speckit's manifests, fall back to `specify init --here --integration claude --force`, which preserves `specs/` and an existing `.specify/memory/constitution.md`). Never fall back to the legacy command files.

**Backstop**: When you are about to implement in a Speckit repo, do NOT improvise. `/omni-spec-implement` is model-invocable -- run it (it confirms before doing side-effecting work). If the feature's `spec.md`/`plan.md`/`tasks.md` do not exist yet, run `/omni-spec-create` first. If you cannot invoke the skill, STOP and tell the user to run `/omni-spec-implement`.

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
| About to hand-code an implementation in a speckit repo | STOP. Run `/omni-spec-implement` (it confirms first) or hand off to the user |
| On main/master and about to implement | STOP. Create/checkout spec branch |
| Branch name doesn't match spec folder | STOP. Checkout correct branch |
| Not sure what the spec wants | Use the `speckit-clarify` skill |
| Repo has `.claude/commands/speckit.*.md` but no `.claude/skills/speckit-*/` | STOP. Outdated Speckit -- tell the user to upgrade; do not use the legacy command files |
| Change isn't in the spec | Update the spec first -- in flight via `/omni-spec-modify`, merged via a new superseding spec |
| Spec says X but code does Y | Fix code OR change the spec with justification (same routing) |
| About to edit a spec directory that is on the default branch | STOP. It is immutable -- open a new superseding spec with `/omni-spec-create` |
| Task isn't in tasks.md | Add it first |
| API doesn't match contract | Update contract OR fix API |
| Unresolved open item in research.md | Resolve before implementing |
