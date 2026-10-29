# Sizing epics and units by code volume

An epic or unit is sized by the production code it is expected to add, not by how many units it
splits into. Unit count alone sizes an `evolve` epic, which mostly extends machinery already built,
the same as a `build` epic: both come out "six units", while one adds a fifth of the other's code
and spends most of its effort on spec, review, and test ceremony that does not shrink with the code.

## Budgets (soft)

| Level | Production code added | Outside the band |
| ----- | --------------------- | ---------------- |
| Unit (one spec) | up to ~2,000 lines | Over: split along a behavior seam. Under ~1,000: fold into the neighbouring unit it depends on or shares files with, unless it must ship apart |
| Epic | ~10,000 to ~20,000 lines | Under: merge with the neighbour it depends on or shares a seam with. Over: split |

These are soft limits. An epic held apart by an outside gate its neighbours do not share (a
platform dependency, a firm decision, a conditional PRD feature) may stay below the band: record
that as the reason in "Order and its reasons", not silently.

## What counts as production code

Lines added in files that ship and run: backend and frontend source, schema migrations, workflow or
prompt files the product executes, and deployment configuration (compose, Makefile, dependency
manifests). Excluded: tests and test fixtures, specs and other documentation, lockfiles, and
generated files.

## Measure the epics already built

An adopted epic's measured size is the calibration for every estimate. Measure it across its merge
(`<merge>^1..<merge>`), or from the merge-base with `origin/<default branch>` while it is unmerged,
with `git diff --numstat`, summing the added column over production files only. Adjust the path
patterns to the repository's layout:

```bash
git diff --numstat <base>..<head> | awk -F'\t' '
  $3 ~ /(^|\/)(tests?|__tests__|specs|docs)\// || $3 ~ /\.(test|spec)\.[jt]sx?$/ ||
  $3 ~ /(^|\/)test_[^\/]*\.py$/ || $3 ~ /(^|\/)conftest\.py$/ ||
  $3 ~ /(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|poetry\.lock|uv\.lock)$/ ||
  $3 ~ /\.md$/ && $3 !~ /workflows\// { next }
  { added += $1; removed += $2 }
  END { printf "added %d, removed %d, net %d\n", added, removed, added - removed }'
```

Report added and net: a refactor-heavy epic removes a lot, and its added count overstates the
growth. When each spec landed as its own commit, measure per spec too, and record the per-spec
average beside the epic total.

## Estimate a planned epic

Estimate each planned epic's production code from its scope, by analogy with measured specs: "a
timed hold and its automatic decline measured ~450 lines" is evidence; "medium" is not. With no
adopted epic to calibrate against, say the estimate is uncalibrated. Give a range, and re-check it
against the band at every program revision and at the epic's seed, when the grounding in the code
is better.
