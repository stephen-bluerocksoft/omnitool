# Review template

The shape of the review `omni-prd-review` writes. Placeholders are in `<angle brackets>`. Drop any
section the PRD gives nothing to, except "What is sound", which is always present.

````markdown
# <PRD title> v<version>: adversarial review

Reviewed against `<repo>` at `<short sha>` (`<branch>`), <date>.

**Verdict:** <one or two sentences: is the product sound, is the architecture sound, and is it
ready to plan>. <The single most important reason.>

## Architectural blockers

<One sentence: how many of the PRD's claims about the system do not hold.>

| # | PRD assumes | What the code has today | Consequence |
| --- | --- | --- | --- |
| 1 | <claim> (<PRD citation>) | <what exists, with `path` or a short quote> | <new foundation work / wrong if reused / blocked on X / ordering decision> |

## Domain and legal gaps

<Lead with the riskiest gap.>

- **<Gap>.** <What the PRD does or omits, why it matters in the domain, what to do.>

## Internal contradictions

1. **<Name>.** <Side A (citation)> versus <side B (citation)>. <The decision it needs.>

## What is sound

- **<Rule or reuse>.** <Why it holds, with evidence.>

## Recommendation

<Rough size: N to M epics.> Settle these before planning:

- [ ] <Decision the product owner can make>

A first slice that delivers <the PRD's highest value>:

1. <Step on what exists or is cheapest to build>

<What follows the slice.>
````
