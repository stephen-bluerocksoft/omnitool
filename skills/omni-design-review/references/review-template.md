# Review template

The shape of the review `omni-design-review` writes. Placeholders are in `<angle brackets>`. Leave
out every section with no findings, with no "none" line in its place. No section lists claims that
hold.

````markdown
# <Proposal title>: design review

<Verdict, two or three sentences: whether the design holds, the areas whose claims check out (one
clause), and how many findings must be settled before the spec and how many belong in it.> Reviewed
against `<repo>` at `<short sha>` (`<ref>`), <date><, and `<other ref>` at `<short sha>` for the
in-flight work it found>; every code claim names a file and symbol, or a search, at that ref.

## Must settle before the spec

| Finding | What the code shows | What the spec must decide |
| --- | --- | --- |
| 1. <The claim that fails, in a few words> | <File and symbol, what they do, and what follows for the design> | <The decision, with the consequence of leaving it open> |

## Also fix in the spec

Each of these would ship as a bug if the spec missed it.

1. <The gap, stated as its consequence.> <The code evidence: file and symbol.>

## Not verified

- <What a finding depends on that the code could not settle, and what would establish it.>
````
