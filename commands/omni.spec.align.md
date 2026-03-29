# omni.spec.align

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may specify a spec number or name (e.g., "005", "admin-api"), a branch name, or specific areas to focus on (e.g., "just the contracts", "data model only").

## Execution Constraint

Do NOT use the Task tool to delegate work to subagents. Execute all steps sequentially in the main agent context. Subagents default to a lesser model (Composer 2) that degrades quality for judgment-intensive work.

## Overview

Audit alignment between specification artifacts and the actual implementation. When code has evolved past the spec during implementation, this command updates the spec to match reality -- the implementation is the source of truth at this point.

This is NOT a code review or bug hunt. This command asks: **"Does the spec accurately describe what was built?"**

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
   git diff main --name-only
   git diff main --stat
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

### Phase 5: Self-Verification

Before producing output, verify completeness:

1. **Deviation coverage**: Confirm every deviation from Phase 3 has a corresponding spec update in Phase 4. If any was missed, update now.

2. **ID continuity**: Verify new FR and task IDs are sequential with no gaps or duplicates.

3. **Cross-reference integrity**: Verify new tasks reference the FRs they implement and vice versa.

4. **No spec-only fabrication**: Confirm every spec update reflects actual implemented behavior, not aspirational or planned work.

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

List any issues that cannot be resolved by updating the spec alone (e.g., unimplemented requirements, features that need discussion). If none, write "No remaining gaps."
