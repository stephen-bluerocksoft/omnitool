---
name: omni-spec-align
description: Audit alignment between an in-flight feature's spec artifacts and the implementation on its branch, updating the spec to match reality (implementation is the source of truth). Use when the feature's specs/NNN-name/ artifacts have not yet merged to the default branch and the code has diverged from them -- e.g. after implementing. Under Flow-Forward, the default, it never aligns a merged feature; a project whose constitution records Living Spec aligns merged features too. Also runs as the alignment sub-step of omni-spec-implement.
---

# omni.spec.align

## Overview

Audit alignment between specification artifacts and the actual implementation. When code has evolved past the spec during implementation, this command updates the spec to match reality -- the implementation is the source of truth at this point.

This is NOT a code review or bug hunt. This command asks: **"Does the spec accurately describe what was built?"**

**Confirm before updating specs.** This flow rewrites the spec artifacts (spec.md, plan.md, tasks.md, contracts/, data-model.md, ...) to match the implementation. Before Phase 1, state which feature spec you will align, then ask with the Guided decisions rule in the core standards. Selecting the first option is the go-ahead for this flow on that spec, and nothing else:

- **Align the spec now (Recommended)** -- run Phases 1 to 5 and update the artifacts to match the code
- **Not now** -- stop with nothing edited

Skip this question when the user explicitly invoked `/omni-spec-align`, or when this skill runs as a sub-step of `/omni-spec-implement` (that flow's confirmation already covers it).

**Base branch**: below, `<base>` means the repository's main integration branch. Detect it once: try `git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p'`, and if empty fall back to whichever of `main` or `master` exists (`git rev-parse --verify main` / `git rev-parse --verify master`).

**In-flight features only, under Flow-Forward.** BRS projects follow Speckit's Flow-Forward model by default: a feature directory that has merged to the default branch is an immutable record. Before Phase 1, read the spec persistence model in `.specify/memory/constitution.md`. If it records one that edits merged features in place, such as Living Spec, skip this check and go to Phase 1. Otherwise run `git cat-file -e <base>:specs/<NNN>-<name>/spec.md`. If it succeeds, **STOP** without editing anything: drift from a merged spec is either a bug to fix in code or a requirement change that needs a new spec through `/omni-spec-create`, whose `## Supersedes` section names the merged directory. Show that the spec has merged and what the request says about the drift, then ask with the Guided decisions rule in the core standards:

- **Fix the code to match the merged spec** -- the spec stays the governing record; recommend it when the code broke a requirement nobody chose to change
- **Open a superseding spec with `/omni-spec-create`** -- the selection is that skill's go-ahead; recommend it when the drift is behavior the user wants to keep

Ground the recommendation in evidence: if the request does not say which the drift is, read the spec and `git diff <base>` far enough to tell, editing nothing. A code fix is not this skill's work -- report the requirement the code breaks and END your turn. When this skill runs as a sub-step of `/omni-spec-implement`, do not ask: return the decision in the same shape and stop, and that skill asks it at its Step 7. With no user to answer, report it in that shape and END your turn.

## Instructions

Execute the audit as **five sequential phases**. Do NOT skip any phase. Each phase builds on the previous one.

### Phase 1: Read All Spec Artifacts

Identify the feature's spec directory from user input, branch name, or by checking `specs/`. Read every file in `specs/<NNN>-<name>/`:

| Artifact | What to extract |
| -------- | --------------- |
| `spec.md` | Requirements (FR-NNN), user stories, acceptance scenarios, edge cases, assumptions |
| `plan.md` | Key technical decisions, project structure listing, architecture |
| `contracts/` | API contracts -- request/response schemas, status codes, event types |
| `data-model.md` | Entities, fields, relationships, constraints |
| `research.md` | Decisions, rationale, resolved/unresolved open items |
| `tasks.md` | Task breakdown, completion status, dependency graph |
| `quickstart.md` | Setup steps, validation scenarios |

Record the last FR ID (e.g., FR-011) and last task ID (e.g., T018) so new IDs continue sequentially.

### Phase 2: Read the Actual Implementation

1. **Read the project structure** from `plan.md` and read every file listed there in full.

2. **Find files not in the plan**. Check for implementation files that were added or modified but are not listed in the project structure:

   ```bash
   git diff <base> --name-only
   git diff <base> --stat
   ```

   Read any unlisted files that are part of the implementation (not IDE config, lockfiles, etc.).

3. **Check for behavioral changes**. For each endpoint, function, or module described in the spec, read the implementation and note what it actually does -- parameters, return types, error handling, side effects.

### Phase 3: Identify Deviations

Compare spec claims against implementation reality. For each deviation, record the category, the spec claim, and the implementation reality.

| Category | What to look for |
| -------- | ---------------- |
| Behavior changes | Endpoint/function does more or less than spec says |
| New features | Implemented functionality not mentioned in any spec artifact |
| Modified signatures | Function parameters, return types, API contracts changed from spec |
| New files | Scripts, tooling, config files added but not in project structure |
| Removed features | Spec describes functionality that was not implemented or was removed |
| Edge cases | New edge cases discovered and handled during implementation |
| Assumptions invalidated | Spec assumptions that turned out wrong during implementation |
| Data model changes | Fields added/removed, types changed, new relationships |

Do NOT flag trivial differences (variable naming, internal refactoring that preserves behavior). Focus on deviations that would mislead someone reading the spec.

**Open convergence gaps are NOT deviations.** If `tasks.md` contains a `## Phase N: Convergence` section with unchecked `[ ]` tasks, those are known, tracked gaps that `speckit-converge` recorded -- work the spec demanded and nobody has built yet. A requirement is only a "removed feature" when the team decided not to build it, never merely because the code does not implement it yet. Before classifying anything as a removed feature, check whether an open Convergence task traces to it (via its `source-ref`, e.g. `FR-003`, `US1/AC2`, `Constitution II`). If one does, exclude it from Phase 3 entirely and carry it into Remaining Gaps instead.

### Phase 4: Update Spec Artifacts

For **each** deviation identified in Phase 3, update the spec to match what was built. The implementation is the source of truth.

| Artifact | What to update |
| -------- | -------------- |
| `spec.md` | Add/update functional requirements (FR-NNN), acceptance scenarios, edge cases, assumptions. New FRs get sequential IDs continuing from the last one. |
| `contracts/` | Update request/response schemas, status codes, handled event types, notes. Add new contract files if new APIs were introduced. |
| `plan.md` | Update key technical decisions, project structure listing. Add new files. Remove files that were not created. |
| `research.md` | Add new decisions with rationale. Remove or update invalidated decisions. |
| `tasks.md` | Mark completed tasks as `[X]`. Add new tasks for work done outside the original plan. New tasks get sequential IDs continuing from the last one. |
| `quickstart.md` | Add validation scenarios for new behavior. Update setup steps if they changed. |
| `data-model.md` | Update entities, fields, relationships, constraints to match actual schema. |

**Rules for updates**:

- New FRs get sequential IDs continuing from the last (e.g., FR-012, FR-013).
- New tasks get sequential IDs continuing from the last (e.g., T019, T020).
- Group new tasks into a new phase if they represent a distinct body of work.
- Cross-reference new FRs in the tasks that implement them.
- Preserve existing content that is still accurate -- do not rewrite sections unnecessarily.
- Match the style and formatting of existing content in each artifact.
- **Never weaken or delete a requirement that an open Convergence task traces to**, and never rewrite, renumber, or reorder an existing `## Phase N: Convergence` section. Deleting an unmet requirement makes the next converge run report `converged` against a spec that no longer asks for the missing work -- the gap disappears silently instead of being built.

### Phase 5: Self-Verification

Before producing output, verify completeness:

1. **Deviation coverage**: Confirm every deviation from Phase 3 has a corresponding spec update in Phase 4. If any was missed, update now.

2. **ID continuity**: Verify new FR and task IDs are sequential with no gaps or duplicates.

3. **Cross-reference integrity**: Verify new tasks reference the FRs they implement and vice versa.

4. **No spec-only fabrication**: Confirm every spec update reflects actual implemented behavior, not aspirational or planned work. This governs what you *add* -- never invent a requirement for work that does not exist. It is not licence to *delete* an unmet requirement the spec legitimately demands: if an open Convergence task traces to it, it stays.

5. **Artifact consistency**: After all updates, confirm artifacts do not contradict each other (e.g., `data-model.md` matches `contracts/`, `tasks.md` aligns with `plan.md`).

## Output Format

**Tone**: Direct and factual. State what changed, where, and why. No filler.

### Summary

1-2 sentences. State which feature spec was audited and how many deviations were found and resolved.

### Deviations Found

One entry per deviation. Group by category. Omit categories with no deviations.

#### Behavior Changes

- **[spec artifact]** Spec said X. Implementation does Y. Updated [artifact] to reflect Y.

#### New Features

- **[file]** Functionality not in spec. Added FR-NNN to `spec.md`, task T-NNN to `tasks.md`.

#### Modified Signatures

- **[contract/function]** Spec signature was X. Actual signature is Y. Updated `contracts/` and `spec.md`.

#### New Files

- **[file]** Not listed in project structure. Added to `plan.md`.

#### Other

- Brief description of deviation and which artifacts were updated.

### Artifacts Updated

Checklist of which artifacts were modified:

- [x] `spec.md` -- N requirements added/updated
- [x] `plan.md` -- project structure updated
- [ ] `contracts/` -- no changes needed
- [x] `tasks.md` -- N tasks marked complete, N new tasks added
- [ ] `data-model.md` -- no changes needed
- [ ] `research.md` -- no changes needed
- [ ] `quickstart.md` -- no changes needed

### Remaining Gaps

List any issues that cannot be resolved by updating the spec alone (e.g., unimplemented requirements, a deviation that is a design decision rather than a spec correction). List every open `## Phase N: Convergence` task here, with its `source-ref` and severity -- these are the spec's unmet demands, and they must surface as gaps rather than be aligned away. If none, write "No remaining gaps."

A gap that needs a design decision is written in the shape the Guided decisions rule in the core standards gives a decision: its options, each with pros and cons, and a recommendation. Run standalone with the user present, ask those decisions after the output, with that rule. As a sub-step of `/omni-spec-implement`, only report them -- that skill asks them at its Step 7.
