# Slicing an epic branch into review units

The unit of review is the workplan unit, not the commit. A hire may land one unit as several commits, and reviewing half a feature produces false positives -- "`foo` is unused" when the next commit calls it. So consecutive commits that belong to one unit are reviewed together, and commits that belong to no single unit are grouped between them.

Inputs: `<merge-base>`, `HEAD`, and the manifest's `units[]` (`id`, `speckit` slug or `null`, in manifest order). Output: an ordered list of slices, each `{id, label, unit, slug, start-sha, end-sha, commits, files, added, code-files, code-added, note}`.

## 1. List the commits

```sh
git rev-list --reverse --first-parent <merge-base>..HEAD
```

Oldest first. `--first-parent` keeps the walk on the epic branch: a merge commit in the range is one commit whose diff is everything it merged. Note any merge commit in the plan's Note column -- BRS branches are rebased, never merged into, so one is unusual.

## 2. Label each commit

For each commit, in this order, stop at the first rule that decides:

1. **Spec paths.** `git diff-tree --no-commit-id --name-status -r <sha>`. Collect every `specs/<slug>/` prefix among the paths and map each slug to the unit whose `speckit` equals it, keeping the status: a slug is **added** when any path under it has status `A`, otherwise **modified**.
   - Exactly one added slug: that unit. The commit that creates a spec directory is the commit building that unit, whatever else it touched -- a unit's implementation routinely amends an earlier unit's data model or research.
   - No added slug and exactly one modified slug: that unit.
   - Otherwise, when two or more slugs are involved: `multi`.
   - No slug at all: continue.
2. **Message.** `git log -1 --format=%B <sha>`. A unit id as a whole word (`U3`), a spec slug (`027-intake-capture`), or the slug's numeric prefix as a whole word (`027`) names a unit. Exactly one unit named: that unit. Several: `multi`. None: `none`.
3. **Sandwich.** After every commit is labelled, a `none` commit whose nearest labelled neighbors on both sides carry the same unit takes that unit -- it was made while that unit was being built.

Independently, mark a commit **docs-only** when every path it touches ends in `.md` or lies under `docs/` or `specs/`. A `.gitignore` or `.yaml` edit outside `docs/` breaks the mark; that is intended.

A unit with `speckit: null` (an exempt unit -- docs, infra, handoff) can only be matched by rule 2. That is expected; its commits usually end up cross-cutting, and they are still reviewed.

## 3. Group into slices

Walk the labelled commits in order. Treat `none` and `multi` as one label, `cross-cutting`. Start a new slice whenever the label changes; consecutive commits with the same label join the current slice.

**A unit slice opens once.** The ceremony builds one slugged unit at a time, so a commit labelled with a unit whose slice has already closed -- a later slice has begun -- is not that unit's implementation; it is a fix made after the fact, which is exactly what the surrounding cross-cutting commits are. Relabel it `cross-cutting` so it joins them. Without this rule the review-response tail of a branch (a fix to 027's workflow, then a note in 027's spec, then a fix in 028) fragments into a run of one-commit slices, each a full review dispatch for a two-file diff.

- A unit slice is named by its unit id (`U3`), carries the unit's slug, and its subagent reads `specs/<slug>/` as the governing spec.
- A cross-cutting slice is named `cross-cutting`; when every commit in it is docs-only, name it `docs-only` instead. Number repeats (`cross-cutting-2`). The first slice of a branch is usually planning docs and the last is usually the preflight pass and the review-response fixes -- ordinary cross-cutting slices.

Each slice's `start-sha` is the previous slice's `end-sha`, or `<merge-base>` for the first. Its `end-sha` is its last commit. The slice diff is `git diff <start-sha>...<end-sha>`, which is what `brs-review`'s base-ref mode computes in a worktree at `<end-sha>` with `<start-sha>` as the base.

## 4. Fallback: no manifest, or nothing maps

With no manifest, or when step 2 labels every commit `none`, unit slicing degrades to the whole branch as one cross-cutting slice -- the single-diff review this skill exists to avoid. Do not do that. Instead:

- Every commit is its own slice, named by its short sha.
- Consecutive docs-only commits merge into one `docs-only` slice.

The report states which fallback applied and why (no manifest found; manifest found but no commit touched a `specs/<slug>/` it names).

## 5. Size each slice

```sh
git diff <start-sha>...<end-sha> --shortstat                                   # files, insertions
git diff <start-sha>...<end-sha> --numstat | grep -v -E '\.md$|\sdocs/|\sspecs/' # code: files, insertions
```

Report both. The **budget is measured on code** -- paths that are not `.md` and not under `docs/` or `specs/` -- because markdown is not bug-hunted and a spec-heavy slice would otherwise be flagged for lines no reviewer traces. A slice over **50 code files or 5,000 added code lines** is marked `OVER BUDGET`. The threshold is where `brs-review` is: it batches above 30 files, and two batches is the range where its per-file attention holds; beyond that is the failure mode this skill exists to avoid. The slice is still reviewed in full -- `brs-review` batches internally -- and the flag goes to the plan, the report's Sizing table, and the closing advice for `/devbot-review`, because the fix is a smaller unit next time, not a smaller review now.

## Worked example

The `intake-foundation` epic (six units, 23 commits, 244 files, +30,734) slices to:

| # | Slice | Unit | Commits | Files | +Lines | Code files | Code +lines | Note |
| - | ----- | ---- | ------- | ----- | ------ | ---------- | ----------- | ---- |
| 1 | docs-only | -- | 2 | 6 | 1266 | 0 | 0 | planning docs |
| 2 | U1 | U1 | 1 | 45 | 5061 | 32 | 3664 | |
| 3 | U2 | U2 | 1 | 37 | 3976 | 26 | 2842 | |
| 4 | U3 | U3 | 1 | 42 | 4450 | 28 | 3193 | |
| 5 | U4 | U4 | 1 | 34 | 3424 | 21 | 2166 | |
| 6 | U5 | U5 | 1 | 23 | 2129 | 10 | 1233 | |
| 7 | U6 | U6 | 1 | 67 | 7493 | 54 | 5864 | OVER BUDGET |
| 8 | cross-cutting | -- | 15 | 128 | 3605 | 50 | 2094 | preflight, spec alignment, review-response fixes |

Each unit landed as one commit. Five touched only their own `specs/<slug>/`; U5's commit added `specs/029-intake-outcomes/` and modified two files under 026's, and the added-slug rule kept it in U5. The preflight commits touched every spec (`multi`) or none (`none`). Three later fixes touched only 027's or 028's spec and would have labelled U3 or U4, but those slices had closed, so they joined the tail. Eight reviews of 1-6k code lines replace one of 30k.
