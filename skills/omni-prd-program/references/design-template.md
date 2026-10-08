# design.md template

The program's `design.md` is the detailed design for what **crosses epic boundaries**: the shared
data model, the lifecycle a record moves through across epics, where data and files live, the
changes existing systems need before any epic can build on them, and the order those changes land
in. Each epic's own `design.md`, written later by `/devbot-plan`, covers only that epic and links
here for the shared parts.

It is written for engineers and the product owner. It is concrete -- real tables, real files, real
symbols, diagrams where a picture is clearer than prose -- and it decides nothing the PRD, the code,
or a recorded ruling does not settle. Where a choice is open, the design states what it prefers and
points at the open decision; it never presents the preference as settled.

A design grows by sections. The first run covers the foundations every epic needs; later runs add a
section when an epic's turn reveals a cross-epic concern. When `design.md` already exists, the skill
never regenerates it. It records what the user decided -- marking an open decision decided, or adding
a short section for a decided cross-epic contract with no home -- and corrects statements the code or
a recorded ruling has overtaken, each cited. Undecided design goes to `program.md`'s Findings as a
proposed addition.

Fill every `[BRACKET]`, delete the guidance lines, and drop the optional sections that do not
apply.

```markdown
# [Program name]: Detailed Design

Status: draft, [date]. [What is pending: rulings, agreements with other tracks.]

PRD: [`[PRD file]`]([relative link]) ([title, version or date]). Program plan: [program.md](program.md).

## Scope

[What this design covers now, and what is added later as it is designed.]

## Overview

[Plain language, three short paragraphs at most: the central records and how they relate, the
lifecycle in one sentence, and where the data and files live. Cite the PRD requirement that drives
each choice.]

## Data model

### Shape

[A diagram of the records and their relationships (mermaid erDiagram), then one bullet per rule:
ownership, cardinality, uniqueness, what happens on duplicates and returns. Cite the PRD item and
the current code for each.]

### Where data lives

[Optional -- when records already exist and some facts must move. A table: field or group, home,
why. The rule that decides the home in one sentence above the table.]

## Lifecycle

[The states a record moves through across epics (mermaid stateDiagram-v2), which epic moves it
across each boundary, and which transitions are automatic versus a person's action.]

## [Integration or storage section]

[Optional, one per concern that several epics share -- files and storage, inbound messages,
outbound communication, scheduling, an external system. A sequence diagram where the flow has more
than two participants. Name the existing code it builds on.]

## Changes existing systems need

[What must change in code that already exists before the epics can build on it, each with the
reason and the evidence.]

## Alternatives considered

[Each serious alternative, why it was rejected, with evidence.]

## Rulings this reverses

[Optional -- only when the design contradicts an earlier recorded decision. Name the decision, who
made it, where it is recorded, and what this design changes.]

## Dependencies on other tracks

[Optional -- what this design needs from work another team or track owns, stated as asks to agree,
never as assignments.]

## Open decisions

1. **[Decision]** -- [the options, what this design prefers and why, and what it blocks].

## Order of work

1. [Agreements and rulings first, then the changes in the order they can land, each tied to the
   epic that carries it.]

## Sources

- [Files, symbols, specs, and branches read, named exactly; the PRD items cited.]
```
