# Page Outline

The published page is a single HTML Artifact built under the `artifact-design` contract, with diagrams drawn under `artifact-diagramming`. Those skills own the visual system -- theme tokens, dark mode, typography, allowed CDNs, phone-width layout. This file owns the content: which sections exist, in what order, and what each must say.

Write for a senior engineer who knows the repository but has not read this PR. Use the codebase's own names for components, entities, and endpoints. Prefer a diagram or table to a paragraph wherever the content is a structure.

## Title and header

- `<title>`: `PR <n> Explained` -- two to four words, per the artifact-design contract.
- Visible heading: the PR title.
- Header line: `<owner>/<repo>` PR #`<n>`, linked to the PR URL; state (open, draft, merged, closed); author; head short sha; base branch; generation date.
- A one-line notice when anything was skimmed, capped, or unverified, linking to the coverage notes at the bottom.

## Sections, in order

### 1. What this PR builds

One paragraph, five sentences at most, in product terms: the capability the system gains, who uses it, and the major moving parts. No file paths. If a spec governs the PR, name it (`specs/<slug>`).

### 2. Size and composition

The composition table from Phase 2 -- bucket, files, added, deleted, share -- with a horizontal stacked bar or bar chart of added lines by bucket. One sentence that names the real size of the change ("Of 100,000 added lines, about 24,000 are production code"). A second, smaller table: production code by area, files and added lines.

### 3. Architecture

A component diagram of the system as the PR leaves it, scoped to what the PR touches:

- the PR's new components, modified components, and the existing components they integrate with, visually distinguished (for example solid, outlined, and muted) with a legend
- grouped by layer or area (UI, API, services, workflows, storage, external systems)
- arrows labelled with the interface (HTTP, call, queue, event, workflow)

Below the diagram, a table per area: component, kind, new or modified, purpose. Collapse long tables behind a disclosure.

### 4. Data model

An entity-relationship diagram of the new and changed entities and the existing entities they relate to, new versus changed visually distinguished. Then a table: entity, created or changed, key fields, notes (migration name, constraints worth knowing). Field names only -- no data.

### 5. Key flows

Two to four sequence diagrams, one per flow, each with a one-sentence caption naming the trigger and the outcome. Participants are components and external systems, not files. Pick the flows that best explain the capability in section 1; a flow per user story is a good default when a spec exists.

### 6. State machines

One state diagram per state machine the PR adds or changes, with transition triggers on the arrows. Omit the section when there are none.

### 7. Surfaces

- **API surface**: method, path, purpose, area -- new and changed endpoints only.
- **UI surface**: page or major component, where it appears, purpose.
- **Background work**: workflows, jobs, schedulers, event handlers, LLM tools -- whichever the PR adds.

Omit any sub-table that would be empty.

### 8. Configuration, infrastructure, and integrations

New or changed env keys (names only), containers or services, CI changes, external APIs, feature flags, and storage. One line each with its purpose. Omit when empty.

### 9. Spec map and drift

Only when a spec governs the PR. Open with: "A high-level comparison of the code with `specs/<slug>`, not a converge pass."

- **Requirement map**: each user story with its requirements, the area or areas implementing them, and a status (implemented, partial, not found).
- **Not found**: each requirement with no implementing evidence, with the search that was run. When there are none, say so in one sentence and stop -- do not discuss individual requirements under this heading.
- **Checked and resolved**: requirements that first looked missing but turned out to be satisfied, each with the mechanism that satisfies it. Omit the heading when there are none. Keeping these apart from Not found means that heading only ever lists real gaps.
- **Beyond spec**: capabilities with no requirement.
- **Plan departures**: plan decisions the code does differently, with both sides stated.

When no spec governs the PR, replace the section with one line saying so and naming what intent was drawn from (PR body, linked issues).

### 10. Architecture review

The advisory half of the page, built in Phase 6 under `references/architecture-review.md`. It follows progressive disclosure: the reader who stops after the first box knows what to do; everything else is detail on demand. Open with one sentence that sets the stance: "A skeptical architect's read of this design: where it will hurt and what to change while it is cheap. Design advice, not a defect review."

In order:

1. **Bottom line** -- one bordered box, the only thing a busy reader needs:
   - the two or three **risk themes**, each a short name on its own line followed by one sentence and the numbers of the recommendations it covers;
   - one count line: how many to address in this PR, how many for the author to file, and how many are blocking (usually none). Do not list the items again -- the list headings directly below already name them, and repeating them in the box is noise.
2. **Address in this PR** -- one short line under the heading noting which items need a spec change or touch an unmerged migration, then one full block per item in priority order, numbered 1, 2, 3; the first open, the rest collapsed.
3. **For the author to file** -- one line under the heading saying these cannot be done in this PR and the author files them. Then one collapsed row per follow-up, lettered A, B, C. The row shows the title, the priority, the repositories involved, what it depends on, an ordered **Issues to file** list (each issue tagged with its repository, its draft title, and what blocks it -- including the issue in this repository that adopts a dependency's change), and -- when waiting leaves an exposure -- the interim decision for the author, linked to the matching question. When the follow-up is part of an in-PR recommendation, link the two both ways; when it stands alone, expanding the row reveals its full block.
4. **Checked and sound** -- a short list of decisions examined and found safe.
5. **Questions for the author** -- three to six, each about intent the code cannot reveal. A question answerable by reading more code does not belong here.

**Full block layout.** Lay each block out as structure, never as bold run-in labels inside paragraphs, which read as a wall of text:

- the header shows the number in a small badge, the title in the display face, the priority tag, and a blocking or non-blocking tag;
- a row of small labelled tiles holds the lens, the quality attribute, spec change, and where it goes (this PR, or the follow-up it depends on);
- the scenario is a tinted panel of three labelled rows -- When, Today, Should -- as a definition list;
- every other field is a two-column definition list: a narrow column of small uppercase muted labels on the left, the content on the right, with lists for multi-part fields such as Where and Recommendation. Below about 640px it stacks to one column.

The fields, in order: **Where** (paths, tables, routes, with counts when the point is "N copies"); **Why it matters** (the concrete cost and when it lands); **Design today** (when the spec, a ruling, or research chose it on purpose, that reason and what the alternative still satisfies; name any PR finding it extends, for example "extends R15"); **Recommendation** (specific enough to size); **Cost** (spec change and which requirements, migration impact); **Keep it fixed** (the automated check that stops it coming back, when practical); **Unknowns** (what the code cannot settle and the measurement that would).

Never put a defect, a style remark, or a "this is fine" confirmation among the recommendations -- confirmations belong in Checked and sound. When vetting leaves nothing standing, say so in the bottom line and keep the other parts.

### 11. Coverage notes

Collapsed by default. How the analysis ran (single pass, or M area analysts with the area plan table, plus the architecture critic: which lenses produced candidates, how many were dropped in vetting and why, and any that survived vetting but missed the eight-recommendation cap, in one line each), what each analyst skimmed or could not read, claims dropped or marked unverified, and what was sampled from the tests, seeds, and generated buckets (one line per bucket, describing coverage and entities, never values).

## Diagram guidance

- **Choose the medium by diagram type.** Artifacts render Mermaid natively from `<pre class="mermaid">` blocks, with no library to load. Use Mermaid for the entity-relationship, sequence, and state diagrams, whose layout it handles well, and leave theming to the renderer -- no `classDef` colors, which ignore dark mode. Hand-draw the architecture diagram and the size chart as inline SVG, colored through the page's theme tokens and `currentColor`, because they need the new/modified/existing encoding and an exact scale.
- **Make every diagram enlargeable.** Wrap each diagram -- each hand-drawn SVG container and each `<pre class="mermaid">` -- in an element with class `zoomable`, `tabindex="0"`, `role="button"` and `aria-label="Enlarge diagram"`, and give it a small "Enlarge" badge on its top edge. Wrap the Mermaid block rather than tagging the `<pre>`, because the renderer may replace the `<pre>` with its SVG. One page-level script opens a full-screen viewer when a `zoomable` is clicked or activated with Enter or Space. The viewer clones the diagram's `<svg>` (sized from its `viewBox`) into a stage with zoom by wheel, pinch, double-click and +/− buttons, drag to pan, a Fit button, a zoom percentage, and Escape to close and return focus. Use event delegation on `document`, since Mermaid renders after the page loads. Hide the viewer with the `hidden` attribute and put `[hidden] { display: none !important; }` in the page's own CSS, so a closed viewer can never cover the page when it is rendered outside the Artifact skeleton. Large sequence and architecture diagrams are unreadable at column width without it.
- **Keep Mermaid syntax plain.** Write path parameters as `:id` rather than `{id}` in sequence messages, give multi-word states an alias (`state "Follow-Up Sent" as FUS`), and keep `;` and `#` out of labels.
- Diagrams show the mechanism, not decoration. Every box is a real component, entity, or external system named in the code at head.
- Keep each diagram readable at phone width: at most about 15 nodes. Split a larger picture by area rather than shrinking it.
- Use the same encoding for new, modified, and existing across the architecture and data-model diagrams, with one shared legend.
- Every diagram has a text caption and a text alternative (the table beneath it), so the content survives without the picture.
