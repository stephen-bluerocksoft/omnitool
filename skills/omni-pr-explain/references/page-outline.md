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

### 10. Questions for the author

Architecture-level questions only: boundaries, coupling, ownership, sequencing, design trade-offs. Three to eight items. Never defects -- those belong to `brs-pr-review`.

### 11. Coverage notes

Collapsed by default. How the analysis ran (single pass, or M area analysts with the area plan table), what each analyst skimmed or could not read, claims dropped or marked unverified, and what was sampled from the tests, seeds, and generated buckets (one line per bucket, describing coverage and entities, never values).

## Diagram guidance

- **Choose the medium by diagram type.** Artifacts render Mermaid natively from `<pre class="mermaid">` blocks, with no library to load. Use Mermaid for the entity-relationship, sequence, and state diagrams, whose layout it handles well, and leave theming to the renderer -- no `classDef` colors, which ignore dark mode. Hand-draw the architecture diagram and the size chart as inline SVG, colored through the page's theme tokens and `currentColor`, because they need the new/modified/existing encoding and an exact scale.
- **Make every diagram enlargeable.** Wrap each diagram -- each hand-drawn SVG container and each `<pre class="mermaid">` -- in an element with class `zoomable`, `tabindex="0"`, `role="button"` and `aria-label="Enlarge diagram"`, and give it a small "Enlarge" badge on its top edge. Wrap the Mermaid block rather than tagging the `<pre>`, because the renderer may replace the `<pre>` with its SVG. One page-level script opens a full-screen viewer when a `zoomable` is clicked or activated with Enter or Space. The viewer clones the diagram's `<svg>` (sized from its `viewBox`) into a stage with zoom by wheel, pinch, double-click and +/− buttons, drag to pan, a Fit button, a zoom percentage, and Escape to close and return focus. Use event delegation on `document`, since Mermaid renders after the page loads. Large sequence and architecture diagrams are unreadable at column width without it.
- **Keep Mermaid syntax plain.** Write path parameters as `:id` rather than `{id}` in sequence messages, give multi-word states an alias (`state "Follow-Up Sent" as FUS`), and keep `;` and `#` out of labels.
- Diagrams show the mechanism, not decoration. Every box is a real component, entity, or external system named in the code at head.
- Keep each diagram readable at phone width: at most about 15 nodes. Split a larger picture by area rather than shrinking it.
- Use the same encoding for new, modified, and existing across the architecture and data-model diagrams, with one shared legend.
- Every diagram has a text caption and a text alternative (the table beneath it), so the content survives without the picture.
