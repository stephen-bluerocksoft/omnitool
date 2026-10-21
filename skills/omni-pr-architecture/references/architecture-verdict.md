# Architecture Verdict

How Phase 6 decides whether the PR's architecture is ready to approve, and how Phase 8 posts that decision once the user says to. The verdict judges design only. Defects from the code review are fixable later and never decide it; they only decide whether an approval waits on them.

## Rubric

The lenses, vetting, placement, severity, and budget are BRS's shared architecture pass -- the same one `brs-review` and `brs-pr-review` run -- so BRS has one architecture rubric, not two. Read these from the BRS Codex install:

- `~/.claude/skills/brs-pr-review/references/architecture-review.md`
- `~/.claude/skills/brs-pr-review/references/severity.md`
- `~/.claude/skills/brs-pr-review/references/review-template.md` (read in Phase 8's body, below)

If any is missing, do not improvise a rubric. Skip Phases 6 and 8, publish the page without an Architecture assessment section, put a notice in its header saying the verdict did not run and why, and tell the user to run `make install` in the BRS Codex repository.

Where the rubric says to work on a branch or in the repository root, work from git objects at `HEAD` in `CLONE` instead -- this skill never checks out. When the changeset holds only Markdown or configuration with no executable code, the rubric skips its pass; the verdict is then "not applicable", and Phase 8 does not run.

## Inputs

- **The verified synthesis** from Phase 5: components, connections, data model, flows, state machines, surfaces. The lenses are applied to the design the page describes, with targeted reads at `HEAD` for evidence.
- **The governing rules**, read from the PR's base (`git show "$BASE":<path>`) so a PR cannot relax the rules it is judged by:
  - `.specify/memory/constitution.md`, when present;
  - the root `AGENTS.md` (or `CLAUDE.md`, when it carries the guidance), and any nested one above a changed path -- especially the tool-per-concern list under Dependencies;
  - the BRS core standards -- the BRS block of `~/.claude/CLAUDE.md`.

  When the PR itself changes one of these files, say so in the assessment and judge against the base version; the amendment is itself a design decision for the lenses.
- **The feedback ledger**: every architecture-kind finding reviewers already raised, with its status, so it is vetted rather than raised again.

## Run

1. **Lenses.** Apply the rubric's fourteen lenses. When the production code is within one area budget (Phase 4), run them inline. Otherwise dispatch one read-only `Explore` critic, using the rubric's critic prompt with these changes: read from git objects in `CLONE` at `HEAD` (never a working tree); append the Phase 5 synthesis and the ledger's architecture findings, which it must not raise again. Verify its return like an analyst's (Phase 5, step 1).

2. **Conformance.** For every MUST in the constitution, every core-standards MUST that a design can satisfy or break, and every `AGENTS.md` convention about structure, boundaries, or the tools the project uses, decide from the synthesis and the code: conformant, departs, or not applicable. Record only departures, each with its evidence. Design-level means the structure breaks the rule -- a second tool for a concern the project already solves, authorization decided by route rather than per object, a merged spec edited in place, secrets carried in an image layer. A single missing check in one function is a defect for the code review, not a conformance finding. A departure the project recorded as an exception (the constitution, `AGENTS.md`, or the plan's Complexity Tracking) is conformant; note the exception.

3. **Existing architecture findings.** Vet each architecture-kind ledger entry with the rubric's vetting steps, as if it were a candidate. One reported fixed or resolved is checked and sound unless the evidence at `HEAD` shows otherwise. One still pending becomes a finding of the assessment, credited to its reviewer and linked.

4. **Vet and cap.** Vet every candidate with the rubric's vetting steps and threshold. Severity follows the rubric: Blocker for a security vulnerability or data loss by design, Critical for a departure from the spec, a contract, the constitution, or a core MUST, otherwise Major. Placement follows the rubric (in this change, or a follow-up with its reason). Keep to the rubric's eight-item budget and its "checked and sound" line. Do not write the rubric's design themes: when one root cause spans several findings, name it in the verdict's one-sentence reason instead.

5. **Mark hard-to-reverse findings.** A finding is hard to reverse when it sits in one of these, each of which gets more expensive to change once other code, data, or systems depend on it:
   - **data model and persistence** -- schema, keys, constraints, migrations, stored formats;
   - **boundaries** -- what each module, service, or repository owns, and how they call each other;
   - **external contracts** -- public APIs, events, tool schemas, file formats, anything another system reads;
   - **trust boundaries** -- authorization, what a model or workflow can reach, where data leaves the system.

   Name the area on the finding.

## Verdict

Decide from the in-change findings only; follow-ups never decide it.

| Verdict | When |
| ------- | ---- |
| **Request changes** | Any in-change finding is Blocker or Critical, or is a Major marked hard to reverse |
| **Approve pending code-review fixes** | No finding above, and the ledger holds must-fix defects that are not reported fixed or resolved -- open, carried forward, author reports fixed, or author declined |
| **Approve** | No finding above and no pending must-fix defects |

State the reason in one sentence: the findings that decide a Request changes, or the pending must-fix items behind an Approve pending code-review fixes.

## Review body

Phase 8 posts this body, written to the session scratchpad as `architecture-review.md`. It follows `brs-pr-review`'s review template -- `~/.claude/skills/brs-pr-review/references/review-template.md`, read in full -- so the architecture review looks and reads like the code review beside it: the verdict callout with count pills, the `---` dividers, categories in bold, every finding a collapsed entry with its ID pill, severity badge, and plain-language headline, and the template's fields, badge markup, and blank-line rules. Where the template and this section differ, this section wins; nothing else about the template changes.

The body is self-contained -- the explanation page is private, so the body never links to it. Never post architecture findings as inline comments; the template's rule for them applies.

### Differences from the template

- **Marker and heading.** The body's first line is `<!-- omni-pr-architecture:verdict -->`, and its heading is `## Architecture Review: <title>` -- not `## PR Review:`, so neither this skill's feedback ledger nor `brs-pr-review`'s re-review mistakes it for a code-review round.
- **Verdict values.** `APPROVE` with `[!TIP]`, `REQUEST CHANGES` with `[!CAUTION]`, and `APPROVE PENDING CODE-REVIEW FIXES` with `[!WARNING]` -- the template's callout for a value a consuming prompt defines. `### Verdict` carries the same value.
- **Summary.** After the callout, one or two sentences on what the PR builds, then one line: "Architecture only -- defects belong to the code review and do not decide this verdict." For an approval pending fixes, a top-level `[!WARNING]` callout follows, listing the must-fix code-review items the approval waits on, one line each (`> - <ID> <headline> -- <status>, <link>`). There is no Design themes line; when one root cause spans several findings, the verdict's justification names it.
- **Must Fix holds every finding that decides Request changes**: Blocker and Critical, and a Major marked hard to reverse. A hard-to-reverse Major carries this badge after its severity badge, and its `Impact` names the area:

  | Badge | Markup |
  | ----- | ------ |
  | Hard to reverse | `<img alt="Hard to reverse" src="https://img.shields.io/badge/Hard%20to%20reverse-cf222e?style=flat-square">` |

- **Recommended holds the other Majors.** Architecture findings are never Minor.
- **IDs.** Number findings `A1`, `A2`, ... across Must Fix and Recommended in display order, in place of the template's `M` and `R` numbers -- the same IDs the page uses, and never confused with the code review's `M1` or `R1` on the same PR. Follow-ups keep the template's `F` numbers.
- **Categories** name the part of the design, not the review phase: `**Data model**`, `**Boundaries**`, `**External contracts**`, `**Trust boundaries**`, `**Failure modes**`, `**Performance and cost**`, `**Operability**`, `**Conformance**` (departures from the constitution, `AGENTS.md`, or the core standards), or whatever names the group. The template's ordering rules apply.
- **Fields.** `Where`, `Cause`, `Impact`, `Decide`, `Fix`, and `Test` as the template defines them, filled from the rubric's candidate: its scenario and evidence in `Cause`, why it matters and the standard or rule it breaks in `Impact`, its recommendation in `Fix`, and its "keep it fixed" check in `Test`. A finding a reviewer raised first adds that review's URL to `Where` and credits the reviewer in `Cause`.
- **Follow-ups for the author** use the template's `F` entries unchanged.
- **Questions for the author** is an added section, between Follow-ups and Verdict, with its own `---` divider: the page's questions, numbered, word for word. Omit the section and its divider when the page has none.
- **Review notes** holds the commit assessed, the rules read (by path, noting any the PR itself changes), "no departures" when conformance found none, the rubric's checked-and-sound line, items past the budget, and any earlier architecture verdict this one replaces.

Write it in the same plain style as the page. No secrets, values, or record contents.

## Posting (Phase 8)

Never post without the user's explicit go-ahead in this run. With no user to ask -- a subagent, an unattended run -- never post; return the decision in the guided-decisions shape so the session that has the user can ask it.

1. **Re-check the head.** `gh pr view <n> --json headRefOid -q .headRefOid` must still equal `HEAD`. If the PR moved, say so: the verdict judged an older commit, and the user decides whether to re-run first.

2. **Pick the review event:**

   | Verdict | Event |
   | ------- | ----- |
   | Request changes | `--request-changes` |
   | Approve pending code-review fixes | `--comment` -- a formal approval would replace the posting account's own earlier review state and could clear a block the code review set |
   | Approve | `--approve` |

   Check the posting account with `gh api user -q .login`. When it is the PR's author, GitHub refuses both approve and request-changes on one's own PR: use `--comment` and say so. When the event is `--approve` or `--request-changes` and that account already has a review state on the PR, say in the question what it replaces.

3. **Ask.** Print the full review body in the visible text of the message, then ask with the Guided decisions rule in the core standards:
   - **Post as `<event>` (Recommended)** -- posts exactly the body shown; selecting it is the go-ahead for that one review and nothing else
   - **Edit the body** -- revise it, show it again, and ask again
   - **Don't post** -- the verdict stays on the page and in the terminal only

4. **Post** only on the first option: `gh pr review <n> -R <owner>/<repo> <event> --body-file <scratchpad>/architecture-review.md`. Report the review's URL. On failure, report the error and ask again; never retry with a different event without asking.
