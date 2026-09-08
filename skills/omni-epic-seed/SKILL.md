---
name: omni-epic-seed
description: Synthesize a devbot-plan-ready epic seed document from a PRD or product brief. Use when the user has a PRD, design doc, or product brief and wants the source input for /devbot-plan -- phrases like "turn this PRD into an epic", "make a devbot plan from this PRD", "seed a devbot epic". Produces ONE seed markdown doc (context, locked decisions, requirements, a proposed unit decomposition, runnable verification, risks, open questions) shaped so /devbot-plan can derive overview.md, manifest.yaml, workplan.md, design.md, and evaluation.md cleanly. Do NOT use to run /devbot-plan (this skill hands off to it), to author speckit specs (use omni-spec-create), or to write epic artifacts directly.
---

# omni.epic.seed

This skill turns one PRD into one **seed document** -- the source input `/devbot-plan` digests into an
epic artifact set. It folds the per-feature "brief" into the seed's own unit sections, so there are no
separate brief files to maintain.

**Fully autonomous.** Never ask the user a question, not even a confirming one. Every genuine
ambiguity in the PRD becomes an explicit open question with a stated default assumption -- never a
fabricated answer. This is the load-bearing rule: a guess written into the seed stops reading as a
guess and becomes a requirement the epic gets built to.

**Stop at the seed.** Write the file, print the handoff line, end the turn. Do NOT run `/devbot-plan`,
do NOT create the epic directory, do NOT author speckit specs.

**Offline.** Like `/devbot-init`, `/devbot-plan`, and `/devbot-review`, this skill never needs a
running devbot. Only `/devbot-launch` and `/devbot-status` talk to the API.

## Runtime note

The pipeline this skill feeds:

```text
PRD -> [this skill] -> temp/<epic-slug>-seed.md
    -> /devbot-plan  -> <docs-root>/<epic-slug>/{overview.md, manifest.yaml, workplan.md,
                                                 design.md, evaluation.md}
    -> /devbot-review -> /devbot-launch
```

The seed is **input**, not an epic artifact. `/devbot-plan` derives the epic from it and supersedes
it; the epic docs are the source of truth from that point on. The seed goes to `temp/` for exactly that
reason -- that directory is expected to be gitignored, and Step 10 covers the case where it is not.

**The seed proposes, `/devbot-plan` decides.** Plan confirms the archetype with the user, assigns unit
IDs and the dependency graph, numbers spec slugs from the next free `specs/NNN`, assigns `REQ-NNN`
IDs, and sizes the run limits. Supplying clean raw material for those decisions is the job. Presenting
them as settled is overreach -- see "What not to write" below.

## Step 1: Resolve inputs and project conventions

Resolve four things before reading anything else:

1. **The PRD** -- a file path or inline text in the invocation. If a path, it is the source document
   the seed cites; if inline, say so in the role banner instead of citing a path.
2. **The target repo** -- the codebase the epic will run against. Default to the current repo; use a
   different path only when the PRD names one.
3. **The epic slug** -- kebab-case, two words where possible: the distinguishing modifier plus the
   head noun, filler dropped ("Billing Uplift for Teams" -> `billing-uplift`; "Reliable Customer
   Notifications" -> `reliable-notifications`). Take a third word only when two would be ambiguous
   inside this repo. The slug names the epic directory, the manifest `epic:` key, and the argument to
   every later `/devbot-plan`, `/devbot-review`, and `/devbot-launch` call, so it must be stable
   across re-runs -- where the title admits two equally good slugs, pick one and record the
   alternative as an open question rather than leaving the next invocation to guess.
4. **The repo ref** for the role banner -- `git rev-parse --short HEAD` and `git branch
   --show-current`. If the target is not a git repository, write that in place of the ref.

Then read the project's devbot conventions. `/devbot-plan` reads a `## devbot program conventions`
block first and stops if it is missing, so the seed must know what that block says.

**Dotfile directory caution**: `.specify/` is a dotfile directory. Recursive glob patterns (`**/`)
silently skip dotfile directories, causing false negatives. List it with an `ls` shell command --
never rely on glob alone.

Run from the target repo root:

```sh
ls -d .specify/ temp/ 2>/dev/null
grep -n "devbot program conventions" CLAUDE.md AGENTS.md 2>/dev/null
```

Interpret the result:

| Result | Action |
| ------ | ------ |
| Conventions block found | Read epic docs root, constitution path, `Speckit:`, and archetype tendency from it. Continue to Step 2. |
| Conventions block absent | Do NOT stop -- this skill is autonomous. Apply the defaults below, record it as a **blocking** open question, and name `/devbot-init` in the handoff line. Continue to Step 2. |

Within either row, `Speckit: no` additionally means: propose no slugs and no converge gate, and mark
every unit exempt (Step 7). When the block is absent, or is present but carries no `Speckit:` line,
read it off the repo instead -- `.specify/` present means yes, absent means no.

Defaults when the block is absent, each recorded in the seed as an assumption:

- Epic docs root: `docs/epics/`
- Constitution: `.specify/memory/constitution.md` when `.specify/` exists, otherwise none
- Speckit: yes when `.specify/` exists, otherwise no
- Archetype tendency: none -- classify from the PRD alone

## Step 2: Ingest the PRD fully

Read the PRD and **every file it references** before writing anything. Extract:

- The goal and its value -- enough for two or three paragraphs of "why"
- Decisions the PRD explicitly states
- Constraints: performance, compatibility, never-touch areas, deadlines
- Any requirements or acceptance criteria already written down
- Anything the PRD itself flags as undecided

## Step 3: Ground against the codebase (light recon)

Verify the specific claims the PRD makes about existing code -- **and nothing else**. That is the
stopping rule: a claim the PRD makes is worth a grep, a file the PRD never mentions is not.
`/devbot-plan` does its own plan-time recon for evolve epics and is told not to go deep, because deep
engineering recon is the hires' job at run time.

Do:

- Confirm what already exists, naming real files and symbols
- Cite grep evidence where it settles a question (include the pattern and the hit count)
- **Reconcile the PRD against reality.** Where a PRD claim contradicts the code, flag it in the seed's
  Context section and **prefer the code**. A PRD that says a capability already shipped when a
  whole-repo grep returns zero hits changes the scope of the epic, and the seed is where that gets
  caught

Do not fabricate a path or a symbol. If a claim cannot be checked, record it as an open question
rather than asserting it.

## Step 4: Classify the archetype

Classify as `build`, `evolve`, or `discover` with a one-line justification. Blends are normal.

| Archetype | When | What the seed must then carry |
| --------- | ---- | ----------------------------- |
| `build` | Greenfield -- little or no existing code | Capability slices; acceptance tests as the done shape |
| `evolve` | Changes existing code | Current-state anchors, the regression baseline, and invariants that must not break |
| `discover` | Research, tuning, or measurement | The discover block: research question, hypotheses, metrics with current baselines, datasets, stopping rules, prior work |

Record it as a **proposal** -- plan confirms the archetype with the user, and everything downstream
depends on it. For a blend, name both (e.g. "evolve, with a large build component") and keep **every**
section that applies to either: an evolve blend still carries the regression baseline, and an epic
with one research-shaped unit still carries the discover block scoped to that unit.

## Step 5: Separate locked decisions from open questions

A decision is **locked** only when the PRD states it, or the code or the constitution unambiguously
determines it. Resolving what the evidence genuinely determines is reading, not deciding -- cite the
evidence when you do it.

Everything else is an **open question** carrying the default assumption applied. Never invent an
answer and present it as a decision.

For "where it resolves", use the real stages -- never `speckit-clarify`, which the run-time ceremony
explicitly forbids hires from invoking because it is an interactive Q&A round with no non-interactive
mode:

- `/devbot-plan` -- its bounded question round, the one stage that talks to the user
- Pre-launch human review at `/devbot-review`
- Run time -- the hire applies the default, marks it `UNCONFIRMED` in the spec's Assumptions, and ends
  the turn with a `BLOCKER:` line for the next `/devbot-status` check-in

Choose by the kind of answer the question needs:

| The question needs | Where it resolves | Blocking? |
| ------------------ | ----------------- | --------- |
| An architecture or scope choice that changes the unit decomposition | `/devbot-plan` | yes |
| A vendor selection, a credential, or a policy sign-off -- anything from outside the repo | Pre-launch review | no |
| A tunable parameter where any sane default ships safely | Run time | no |

## Step 6: Derive requirements

Write requirements as testable capability statements. Each carries:

- A **priority** signal: `P1` when the epic fails its goal without it, `P2` when the epic still
  delivers without it. Where the PRD weights two requirements equally and the ranking is genuinely
  contested, record it as an open question instead of inventing one
- A **verified by** pointer naming a concrete check -- a test command, a metric, or an audit. It may
  name a harness that a unit of **this** epic creates, provided that unit is a dependency of the unit
  covering the requirement. On a repo with no runnable suite that is the normal case, and building the
  harness is then the first unit

These feed overview.md's `| ID | Requirement | Priority | Verified by |` table, and `/devbot-review`
rejects an epic where a requirement's verification names nothing that exists or is ever built.

Do **not** number them `REQ-001` -- `/devbot-plan` assigns the IDs and owns the traceability spine.
Keep the list and the units' "Covers" fields consistent so it can build that spine: every requirement
covered by at least one unit, every unit covering at least one requirement.

## Step 7: Propose the unit decomposition

Decompose spec-first into **3 to 9 units**, ordered so prerequisites come first. A unit is a shippable
behavior slice that becomes one future Speckit spec.

For each unit write:

- **Covers** -- which requirements from Step 6
- **Delivers** -- product-level scope and boundaries. **Not a task list**: the per-unit task breakdown
  is the hires' job at run time
- **Current-state anchor** -- the real files and symbols it touches or ports from
- **Depends on** -- other units, or none
- **Done** -- machine-checkable, plus the converge gate for dev units
- **Open questions** -- genuine ambiguities and the default assumption applied
- **Budget hint** -- rough effort, which informs the manifest limits

**Slug proposals.** A unit that produces shippable software behavior is a dev unit: propose a short
slug name prefixed "next available `NNN`" (e.g. next available `NNN-billing-webhooks`). Never assign a
real `specs/NNN` number -- plan numbers it from the next free slot at scaffold time. A unit that
produces only docs, infra, a human handoff, or a discover experiment is exempt: mark it `none` and
give the reason. Build and test tooling is infra even when it commits real code -- a unit that adds a
dependency manifest, a test runner configuration, or CI wiring ships no product behavior and is
exempt. Every unit gets one or the other, so an omission is never mistaken for a deliberate
exemption.

Two constraints to state in the seed:

- **A slug may span several units.** One spec feature commonly covers several units; that is normal
  and is not a collision
- **Slugged units run one at a time.** Spec Kit tracks a single active feature per repo via
  `.specify/feature.json`, so two dev units in flight corrupt each other. Only exempt units genuinely
  run in parallel

For dev units, append the converge gate to the done condition in this wording:

> `/speckit-converge` reports `converged` for `specs/<slug>`, or two converge -> implement cycles have
> run and only LOW/MEDIUM `unrequested` findings remain.

Where Speckit is not in use, omit slugs and the converge gate entirely and mark every unit `none`
with the repo-level reason "Speckit not in use in this repo". Do not force a unit-kind category onto a
unit that plainly ships behavior -- the exemption is a property of the project here, not of the unit.
Retitle the units section `## Phases -> units` in that case: without Speckit they do not become
Speckit specs, and the template's heading would assert something false.

## Step 8: Write verification as runnable commands

Write the verification section as numbered, exact, copy-pasteable commands, each with its expected
outcome. "`cd backend && pytest tests/billing/` -> green" works; "verify billing is correct" does not.
These convert directly into evaluation.md's `| Harness | Command | Expected | Used by |` table and
into the epic done condition.

Every gate that can be environmentally unavailable (Docker, a cloud credential, a tool that may not be
installed) must say what happens when it is: an **explicit recorded skip with its reason**, never a
silent waiver, and never counted as proving runtime behavior.

For an `evolve` epic also record the regression baseline: the exact command, its current result, and
what must not change. evaluation.md has a "Regression protection (evolve)" section that expects
precisely this.

**Run the baseline command rather than assuming it passes.** If it does not run at all -- no test
runner installed, no dependency manifest, no tests collected -- record that failure verbatim as the
current result, and make establishing the baseline the first unit. Do not write a baseline you did not
observe. An evolve epic cannot show it preserved anything against a suite that never ran, and a green
run collecting zero tests reads exactly like a green run of a real suite.

## Step 9: Recommend oversight, rails, and the scope boundary

Recommend, as raw material for the manifest:

- **Oversight**: `fully_autonomous`, `approve_each_turn`, or `checkpoint`
- **Rails**: rough turns, runtime, and tokens at **about twice** the honest estimate. Budgets are
  safety rails, not estimates -- a tripped limit halts cleanly, a runaway does not. Anchor the honest
  estimate per unit before doubling: a small unit (one model, one enforcement point) runs a few turns,
  a medium one (a seam through existing code, a migration) several, and a large one (an interface
  refactor, concurrency correctness) upward of ten. Sum the units, then double. Turns is the anchored
  quantity; runtime and tokens follow from it and are rough by nature, so present them as rough
- **Scope boundary**: what the hires do versus what is a human handoff. This is the densest and most
  load-bearing statement in the seed: it defines the non-goals and the guard clauses in the done
  conditions. Say plainly where credentials, outward actions, or production access make something a
  documented handoff rather than hire work

## Step 10: Emit the seed and hand off

1. Fill every `[BRACKET]` in the template, delete the guidance lines, and drop the sections that do
   not apply to the archetype
2. Write the seed to `temp/<epic-slug>-seed.md` in the target repo, creating `temp/` if it does not
   exist
3. **OUTPUT the handoff, then END your turn -- once you write this output, call no further tools.**
   It has two parts, in this order.

   The handoff line. This part is always emitted:

   > Seed written to `temp/<epic-slug>-seed.md`. Next: run `/devbot-plan <epic-slug>` pointing at that
   > file, then `/devbot-review <epic-slug>`.

   Append this sentence **only** when Step 1 found no conventions block:

   > This project has no `## devbot program conventions` block -- run `/devbot-init` first, or
   > `/devbot-plan` will stop.

   Append this one **only** when `temp/` is not gitignored in the target repo -- the seed is a staging
   artifact, not something to commit:

   > `temp/` is not gitignored here, so exclude the seed from any commit.

   Then two or three sentences on what the seed proposes: archetype, unit count, and how many open
   questions are left for `/devbot-plan`. Name the **blocking** ones explicitly, with the evidence
   behind each -- those are what the user has to answer before planning is worth running

## Seed document template

Fill every `[BRACKET]`, delete the guidance lines, and drop the sections that do not apply to the
archetype.

```markdown
# [Epic Name] -- PRD/Design Seed for /devbot-plan

> **Role of this document:** the PRD/design seed for the `[epic-slug]` devbot epic -- the source input
> to `/devbot-plan`, which digests it into the epic artifact set (overview.md, manifest.yaml,
> workplan.md, design.md, evaluation.md) under `[docs-root]/[epic-slug]/`. Product/design level; the
> per-unit task breakdown is the hires' job at run time, not this file's. The decomposition below is a
> **proposal** -- `/devbot-plan` confirms the archetype, assigns unit IDs, REQ IDs, and spec numbers.
> Generated by `omni-epic-seed` from `[source PRD path]`, reconciled against `[target repo]` @ `[git ref]`.

## Context

[Goal in one or two plain paragraphs: the outcome and its value.]

[Current-state grounding: what already exists in the target codebase, citing real file paths and grep
evidence; what the gap actually is. Reconcile against the PRD -- flag any PRD claim the code
contradicts, and prefer the code.]

## Decisions (locked)

| Area | Decision | Rationale |
| ---- | -------- | --------- |
| [area] | [decision] | [why -- PRD statement, code, or constitution] |

[Only decisions the PRD states or that the code or constitution unambiguously determines.]

## Target architecture / approach

[Components, boundaries, data flow, interfaces and contracts, invariants. Concrete where known --
directory trees, module names, file paths.]

## Requirements / success criteria

| Requirement | Priority | Verified by |
| ----------- | -------- | ----------- |
| [testable capability statement] | P1 | [command, metric, or audit] |

[Do NOT number these REQ-NNN -- /devbot-plan assigns the IDs. Phrase each as a machine-checkable
outcome.]

## Execution model

- **Archetype:** build | evolve | discover -- [one-line justification; /devbot-plan confirms].
- **Oversight (recommended):** fully_autonomous | approve_each_turn | checkpoint.
- **Rails (rough, about 2x the honest estimate):** ~[N] turns, [runtime], ~[M] tokens.
- **Scope boundary:** hires do [X]; human handoffs are [Y]. Defines the non-goals and the
  done-condition guard clauses.
- **Units:** [N] proposed units. Slugged units run one at a time -- Spec Kit tracks a single active
  feature per repo. Ordered [why].

## Phases -> units (each becomes a Speckit spec)

### Unit 1 -- [title] (proposed spec: next available `NNN-slug` | or `none` -- [exemption reason])

- **Covers:** [which requirements above].
- **Delivers:** [product-level scope and boundaries; NOT a task list].
- **Current-state anchor:** [real files and symbols it touches or ports from].
- **Depends on:** [unit refs, or none].
- **Done (machine-checkable):** [runnable checks]. [Dev units add: plus `/speckit-converge` reports
  `converged` for `specs/<slug>`, or two converge -> implement cycles have run and only LOW/MEDIUM
  `unrequested` findings remain.]
- **Open questions:** [genuine ambiguities and the default assumption applied].
- **Budget hint:** [rough effort].

[...repeat per unit, 3 to 9 total...]

## Risks and invariants

- **[Risk stated as a mechanism]** -- [cause -> consequence -> what unblocks it]. **Must not break:**
  [the invariant this protects].

[State each risk as a mechanism, not a worry. These become design.md's "Invariants -- must not break"
and evaluation.md's "Must not change".]

## Regression baseline (evolve only)

- **Baseline command:** `[exact command]` -> [current result, e.g. "412 passed, 3 skipped"].
- **Must not change:** [behavior, contracts, and performance floors this epic may not regress].

## Discover (discover archetype only)

- **Research question:** [falsifiably stated].
- **Hypotheses:** [each with how it would be confirmed or refuted].
- **Metrics and baselines:** [metric, definition, current baseline, target -- "better" must be defined
  before the first experiment].
- **Datasets / test conditions:** [what they cover, where they live].
- **Stopping rules:** success, diminishing returns, budget.
- **Prior work:** [what has been tried, results, links].
- **Harness status:** [exists at `<command>` | does not exist -- must be the first unit].

## Verification (end-to-end)

1. `[exact command]` -> [expected outcome].
2. `[exact command]` -> [expected outcome]. [If [tool] is unavailable, record an explicit skip with
   the reason; never silently waived, and not counted as proving runtime behavior.]

[These become evaluation.md's harnesses and the epic done condition.]

## Non-goals / out of scope

- [Hard boundary] -- [where it went instead: a later epic, a human handoff, a deliberate deferral].

## Open questions (epic-level)

| # | Question | Default assumption applied | Blocking | Where it resolves |
| - | -------- | -------------------------- | -------- | ----------------- |
| 1 | [question] | [the default applied] | yes/no | /devbot-plan |

[Never fabricate an answer. State the default assumed so /devbot-plan, review, or the hire can
override it. "Where it resolves" is /devbot-plan, pre-launch review, or run time (hire defaults and
raises a BLOCKER) -- never speckit-clarify, which hires are forbidden to invoke.]

## Traceability

[Source PRD sections; issue IDs; reused specs and modules named exactly; the project constitution
path.]
```

## What /devbot-plan does with this seed

`/devbot-plan` accepts a PRD or design-doc pointer and emits five epic artifacts. Supply clean inputs;
let it formalize.

| Seed section | Feeds |
| ------------ | ----- |
| Role banner | overview.md `**Source documents**` -- the epic derives from, and does not replace, the seed |
| Context | overview.md "Why" and design.md "Context" |
| Decisions (locked) | design.md "Key decisions" table |
| Target architecture | design.md "Architecture", "Interfaces & contracts", "Invariants" |
| Requirements | overview.md "Requirements" REQ table and its "Verified by" column |
| Execution model | Archetype classification, manifest oversight and limits, overview.md "Non-goals" |
| Phases -> units | workplan.md "Units" and manifest `units[]` with their speckit slugs |
| Risks and invariants | design.md "Invariants -- must not break", evaluation.md "Must not change" |
| Regression baseline | evaluation.md "Regression protection (evolve)" |
| Discover block | design.md discover variant, ledger.md baseline, harness-first ordering |
| Verification | evaluation.md "Harnesses" and the epic-level done condition |
| Non-goals | overview.md "Non-goals" -- the manager treats these as hard boundaries |
| Open questions | overview.md "Open questions" table |
| Traceability | The requirement -> unit -> spec spine and the source-documents link |

Hard rules `/devbot-plan` and `/devbot-review` enforce. Design the seed so they are trivial to satisfy:

- **Machine-checkable done conditions.** Verifiable from artifacts alone. If a human reviewer could
  not verify it from what is written, the devbot manager cannot either. This check is non-negotiable
  at review
- **Traceability spine.** Every requirement covered by at least one unit; every unit covering at least
  one requirement
- **Archetype drives everything.** Evolve epics need current-state grounding and a no-regression
  clause; discover epics need the metric harness before any experiment
- **Budgets are about 2x the honest estimate** -- safety rails, not estimates
- **Two readers, and one is a machine.** The devbot manager inherits no `CLAUDE.md` and no skills; it
  sees only the epic's done conditions and guidance, and its memory of earlier turns is a couple of
  hundred characters each. So the seed carries concrete paths, runnable commands, and checkable
  conditions, with no unstated context

### What not to write

These belong to `/devbot-plan`, `/devbot-launch`, or the hires. Writing them here is overreach:

- `manifest.yaml`, or any of its fields
- `REQ-NNN` identifiers
- The verbatim epic done condition -- plan writes it and appends the clause "and every unit's done
  condition in workplan.md is met" itself
- Real `specs/NNN` numbers -- propose the short name, say "next available `NNN`"
- Unit IDs (`U1`, `U2`) presented as settled, or a dependency graph presented as decided
- Task lists, speckit specs, or a restatement of the speckit ceremony -- the ceremony ships with the
  devbot skill and `/devbot-launch` injects it into the run
- A restatement of the project constitution -- reference it by path

## Quality rules

- **Never fabricate a decision.** Undecided means an open question plus the default assumption applied.
  This is the single most important rule
- **Everything checkable.** No done or verification statement a human could not verify from artifacts
  alone. Prefer exact commands
- **Reconcile the PRD against the code.** When they disagree, flag it and prefer the code
- **Concrete over abstract.** Real paths, real symbols, runnable commands
- **Product level, not task level.** Units describe what ships, not how to build it
- **Propose, do not decide** what `/devbot-plan` owns

## Notes

- Re-running the skill on the same PRD overwrites the same `temp/<epic-slug>-seed.md`. If the epic
  directory already exists, `/devbot-plan` switches to revision mode and iterates on the existing
  artifacts rather than regenerating them
- An epic whose units are all exempt is normal, and arrives two different ways: an epic of research,
  analysis, or review-and-recommend work, which is not dev work anywhere; and an epic of ordinary dev
  units in a repo that has no Speckit. Same marking, different reason -- give the right one. Never
  invent a dev unit or a slug to make an epic look conventional
- If the PRD is too large for 3 to 9 units, say so in the seed and propose the split into more than
  one epic rather than compressing it into oversized units
