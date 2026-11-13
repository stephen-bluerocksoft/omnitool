# Review template

The shape of the review `omni-prd-review` writes. Placeholders are in `<angle brackets>`. Leave out
every section with no findings, with no "none" line in its place; the verdict's counts already say
when there are no questions. No section proposes a fix, sizes work, or orders programs.

````markdown
# <PRD title> v<version>: adversarial review

Reviewed against `<repo>` at `<short sha>` (`<branch>`), <date>.

**Verdict:** <one or two sentences: is the PRD ready to plan, and if not, what the design review
must settle>. <Q> questions for the product owner.

## Domain and legal gaps

- **<Gap> (<PRD citation>).** <What the product does or omits for its users, and why it matters in
  the domain.>

## Ambiguities

- **<Term or requirement> (<PRD citation>).** <The PRD wording, what it leaves unclear or undefined,
  and the code evidence where the requirement points at something that does not exist.>

## Internal contradictions

1. **<Name>.** <Side A (citation)> versus <side B (citation)>, which no precedence rule settles.

## Questions for the product owner

- [ ] <Question> (<the finding it comes from>)
````
