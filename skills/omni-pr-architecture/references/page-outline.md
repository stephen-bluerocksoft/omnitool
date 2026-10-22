# Page Outline

The published page is a single HTML Artifact built under the `artifact-design` contract, with diagrams drawn under `artifact-diagramming`. Its visual system is fixed by `references/page-style.md`: the fonts, palette, stylesheet, class names, size chart, architecture grid, and viewer script, copied verbatim on every run so every page looks the same. This file owns the content: which sections exist, in what order, and what each must say.

Write for a senior engineer who knows the repository but has not read this PR. Use the codebase's own names for components, entities, and endpoints. Prefer a diagram or table to a paragraph wherever the content is a structure.

## Title and header

- `<title>`: `PR <n> Explained` -- two to four words, per the artifact-design contract.
- Visible heading: the PR title.
- Header line: `<owner>/<repo>` PR #`<n>`, linked to the PR URL; state (open, draft, merged, closed); author; head short sha; base branch; generation date.
- The architecture verdict as one line -- a pill (Approve, Approve pending code-review fixes, Request changes) and its one-sentence reason -- linking to the Architecture assessment section. When the verdict did not run, a notice saying why.
- A one-line notice when anything was skimmed, capped, or unverified, linking to the coverage notes at the bottom.

## Sections, in order

### 1. What this PR builds

One paragraph, five sentences at most, in product terms: the capability the system gains, who uses it, and the major moving parts. No file paths. If a spec governs the PR, name it (`specs/<slug>`).

### 2. Size and composition

One sentence that names the real size of the change ("Of 100,000 added lines, about 24,000 are production code"). Then the size chart from `references/page-style.md`: one horizontal bar per non-empty bucket on one scale, largest first, with the buckets counted as architecture in the accent and the rest in grey. Then the composition table from Phase 2 -- bucket, files, added, deleted, share -- with the totals in its footer, a notice reconciling git's and GitHub's counts when they differ, and a second, smaller table: production code by area, files and added lines, with its total in the footer. `references/page-style.md` gives the exact geometry and order.

### 3. Architecture

A component diagram of the system as the PR leaves it, scoped to what the PR touches:

- **drawn in horizontal layers, always**: one band per layer, its name in small capitals down the left edge, bands divided by a thin rule, ordered from the user down to storage -- for example UI, API, SERVICES, PLATFORM, AGENT, FILES, STORAGE. Name the layers after the system's own tiers; omit a layer the PR does not touch, and put an external system (a mailbox, a third-party API) in the layer it talks to
- the PR's new components, modified components, and the existing components they integrate with, visually distinguished (for example solid, dashed, and muted outlines, plus dotted for external systems) with a legend
- arrows labelled with the interface (HTTP, call, queue, event, workflow), dashed for a handoff that does not wait

**Every box is clickable, and its details show in a side panel** -- there is no list of boxes under the diagram. The panel sits beside the diagram on a wide screen and below it at phone width, and opens on a short prompt ("Select a box to see what it does"). Selecting a box shows, in the panel:

- its name, and whether it is new, modified, existing, or external;
- what it does in the system, in two to four sentences or a short list -- no per-file tables and no file paths beyond the one or two names a reader needs to find it;
- for a workflow, job, or scheduled task: what starts it, the model it runs on when it is an LLM workflow, and its run limits;
- the architecture findings it carries, by ID, linked to the Architecture assessment ("Findings A1, A5"). Code-review findings are not linked.

The selected box is visibly marked in the diagram. The mechanics are in the diagram guidance below.

### 4. Tables

The persisted schema the PR adds or changes, and the existing tables it references. When the PR changes no table or column, this section is one line saying so.

An entity-relationship diagram of the new and changed tables and the existing tables they relate to, new versus changed visually distinguished in the entity names. The diagram carries the key fields, and a JSON or JSONB column appears as a field of type `jsonb` -- its structure is drawn in the next section, not here.

Then a table: table, created or changed, role, notes. The role says what the table represents, who or what writes it and when, and how it lives over time (append-only with one row per reading, mutable under a version counter, removed on close). Notes hold the migration name and the keys, indexes, and constraints worth knowing. Do not list fields in the table -- the diagram already shows them. Field names only, anywhere on the page -- no data.

Close the section with the revision chain, one line in a notice: base revision, then each revision in order, naming any that is not purely autogenerated and why.

### 5. JSON shapes

The structures the code defines for the PR's JSON and JSONB columns -- a Pydantic model, a TypedDict, a JSON Schema, an LLM tool's argument schema. Omit the section when no column the PR adds or changes holds a defined structure.

An entity-relationship diagram with one entity per structure, named for the code's type (or `<table>.<column>` when the type is unnamed), joined to its table by a dotted (non-identifying) relationship labelled with the column. A list of items is one entity with a `0..many` relationship. Show its fields and their types; a nested structure is a further entity, joined to its parent by the field that holds it.

Then a table: shape, column, defined in, written by, read by. "Written by" names the code or tool that writes it and when; "read by" names what consumes it (a read projection, a rule, a UI component, another feature). A column whose content the code does not define is a row marked free-form, not drawn.

### 6. Spec data model

When the PR's specs declare a data model (`data-model.md`, and the entity and payload shapes in `contracts/`) -- one sub-section per spec slug, under its own `h3`. When no spec governs the PR, omit the section.

- **What the spec designed**: two to four sentences on the model as a whole -- its main entities, how they relate, and the design choices the spec or plan records for it (append-only history, a vocabulary table rather than an enum, state held on the parent row), with the reason the spec gives.
- **Diagram**: an entity-relationship diagram of the spec's model as the spec declares it, drawn with the same conventions as the Tables and JSON shapes diagrams. Give it one only when it differs from the built model in entities or relationships; when the two match, say so in one line instead of drawing the same picture twice.
- **Mapping table**: one row per declared entity -- tables, columns, JSON shapes, vocabularies, payloads, workflow state, and the migration plan -- giving the entity as the spec names it, its kind, its purpose in a sentence, what built it at head (the table, column, type, or vocabulary, by name), and the differences: fields declared but missing, fields added, and types, keys, constraints, relationships, or lifecycle rules that differ, each with both sides stated. "Matches" when nothing differs; "not built" when nothing at head implements it. Add a row for anything built that no spec entity declares, marked "not in the spec".

A not-built or differing entity is drift, so it also appears as a gap on its requirement's row in the spec map. A difference that is a design problem -- a declared foreign key built as a soft link, an append-only history built as an update in place -- is a candidate for the architecture assessment, which decides whether it is a finding.

### 7. Key flows

Two to four sequence diagrams, one per flow, each with a one-sentence caption naming the trigger and the outcome. Participants are components and external systems, not files. Pick the flows that best explain the capability in section 1; a flow per user story is a good default when a spec exists.

Above the first diagram, one line on how to read it: participants across the top, time runs down, a solid arrow is a call, a dashed arrow is its reply, an open arrowhead is a handoff that does not wait, `loop` repeats, and `alt` / `else` means one branch runs.

- **Number the steps.** Start every sequence diagram with `autonumber`, so the caption and the text can cite a step ("from step 6 the run is in the background").
- **Show every reply, and every handoff that does not wait.** An HTTP call gets its dashed reply (`-->>`) at the point the response is actually sent. Work that continues after the caller has its answer -- a background task, a queued job, an event, a workflow run -- is an async arrow (`-)`), and the caller's reply comes before it, so the diagram never implies a request waits for work it does not wait for.
- **Keep participants consistent across flows.** A component that sits between two others in one flow (a tool layer, a gateway) sits between them in every flow that crosses it, under the same name. Define the participant set once from the architecture diagram's boxes and draw each flow from that set.
- **Label arrows in plain words.** Each message says what is asked for in a few words ("store the file", "record the check"); the code name, when it helps the reader find it, goes after it in parentheses. Never a bare function or tool name.

### 8. State machines

One state diagram per state machine the PR adds or changes, with transition triggers on the arrows. Omit the section when there are none.

### 9. API surface

Method, path, purpose, area -- new and changed endpoints only. Omit the section when there are none.

The page does not describe the UI beyond its boxes in the architecture diagram: what a screen looks like and how it feels to use takes a person using it, which `omni-walkthrough` covers. Workflows, jobs, and tools are boxes in the architecture section, not a list here.

### 10. Spec map and drift

Only when a spec governs the PR. Open with: "A high-level comparison of the code with `specs/<slug>`, not a converge pass."

- **Requirement map**: each user story with its requirements, the area or areas implementing them, and a status (implemented, partial, not found). A partial or not-found row says on the row what is missing and the search that was run, so a gap is read where its story is -- there is no separate list of gaps.
- **Beyond spec**: capabilities with no requirement. Omit the heading when there are none.
- **Plan departures**: plan decisions the code does differently, with both sides stated. When there are none, write nothing -- no heading, no "none found", no note about the plan's own amendments.

A requirement that first looked missing but is satisfied by an existing mechanism is marked implemented in the map, and the mechanism goes in the coverage notes -- it is a record of how the analysis ran, not a fact about the PR.

When no spec governs the PR, replace the section with one line saying so and naming what intent was drawn from (PR body, linked issues).

### 11. Architecture assessment

The Phase 6 verdict, from `references/architecture-verdict.md`. Open with the verdict, its one-sentence reason, the commit assessed, and the rules it was judged against (by path). Say plainly that it weighs design only and that code-review defects never decide it.

- **Findings**: each in-change architecture finding, most severe first, as a collapsed `<details>`. Number them `A1`, `A2`, ... in display order -- the posted review uses the same IDs. A departure from the constitution, `AGENTS.md`, or the core standards is a finding like any other, in the Conformance category; there is no separate conformance list. The summary line carries its ID, severity pill, a "hard to reverse" pill naming the area when it applies, the headline, and the box or flow it touches. Expanded, it holds where, why it matters, the recommendation, and the standard or rule it cites -- credited and linked when a reviewer raised it first. A box in the architecture list with a finding links here.
- **Pending code-review fixes**: only for an Approve pending code-review fixes -- the must-fix items the approval waits on, one line each: ID, headline, status, linked. This is the only place code-review findings appear on the page.
- **Follow-ups for the author**: each with its reason and repository. Omit when none.
- The rubric's design themes are not shown; when one root cause spans several findings, the verdict's one-sentence reason names it. Its "checked and sound" line goes in the coverage notes, not here.

When the verdict did not run, replace the section with one line saying why and what to install. When it is not applicable (no executable code), say so in one line.

### 12. Questions for the author

Three to six questions the explanation raised, each about intent the code cannot reveal: a spec ambiguity, a design choice nothing explains, behaviour the code leaves undefined. Never repeat a question a reviewer has already asked on the PR, or one the architecture assessment already answers. Questions only -- no recommendations, priorities, or follow-ups; design judgments belong in the architecture assessment. These same questions go in the posted review (`references/architecture-verdict.md`). Omit the section when the explanation raised none.

### 13. Coverage notes

Collapsed by default. How the analysis ran (single pass, or M area analysts with the area plan table), what each analyst skimmed or could not read, claims dropped or marked unverified, requirements checked and resolved (each with the mechanism that satisfies it), which review sources were read and which status-only bots were skipped, how the architecture pass ran (inline or one critic), the rules conformance was checked against (by path, noting any the PR itself changes) and that it found no departures when it found none, the design decisions it checked and found sound, and the candidates it dropped past the budget, and what was sampled from the tests, seeds, and generated buckets (one line per bucket, describing coverage and entities, never values).

## Diagram guidance

- **Choose the medium by diagram type.** Artifacts render Mermaid natively from `<pre class="mermaid">` blocks, with no library to load. Use Mermaid for the entity-relationship, sequence, and state diagrams, whose layout it handles well, and leave theming to the renderer -- no `classDef` colors, which ignore dark mode. Hand-draw the architecture diagram and the size chart as inline SVG, on the grids `references/page-style.md` fixes and colored through its tokens and `currentColor`, because they need the new/modified/existing encoding and an exact scale.
- **Make every diagram enlargeable.** Wrap each diagram -- each hand-drawn SVG container and each `<pre class="mermaid">` -- in the `zoomable` element `references/page-style.md` defines, whose stylesheet draws the "Enlarge" badge. Wrap the Mermaid block rather than tagging the `<pre>`, because the renderer may replace the `<pre>` with its SVG. The viewer script in that file opens a full-screen viewer when a `zoomable` is clicked or activated with Enter or Space. It clones the diagram's `<svg>` (sized from its `viewBox`) into a stage with zoom by wheel, pinch, double-click and +/− buttons, drag to pan, a Fit button, a zoom percentage, and Escape to close and return focus. It is delegated on `document`, since Mermaid renders after the page loads, and the viewer is hidden with the `hidden` attribute, which the stylesheet's `[hidden]` rule enforces even outside the Artifact skeleton. Large sequence and architecture diagrams are unreadable at column width without it.
- **Make every architecture box clickable.** Each box is the SVG `<g class="box ...">` that `references/page-style.md` defines, with `role="button"`, `tabindex="0"`, `aria-controls="archpanel"`, an `aria-label` of its name, and a `data-box="<id>"`; Enter and Space activate it like a click. Each box's panel content is a hidden element in the page (`<div data-box-detail="<id>">` inside one `<div hidden>`), so the text exists without the diagram and screen readers reach it through the panel, which is an `aria-live="polite"` region. The same script copies the selected box's detail into the panel and marks the box selected (`aria-pressed="true"`, which the stylesheet draws as a heavier outline). On the architecture diagram, enlarging is only through its Enlarge button -- a real `<button>` -- so a click on a box selects it instead of opening the viewer. The enlarged viewer shows the same panel beside its stage (below it at phone width), and box clicks there select too, since the cloned boxes keep their `data-box`.
- **Keep Mermaid syntax plain.** Write path parameters as `:id` rather than `{id}` in sequence messages, give multi-word states an alias (`state "Follow-Up Sent" as FUS`), and keep `;` and `#` out of labels.
- Diagrams show the mechanism, not decoration. Every box is a real component, entity, or external system named in the code at head.
- Keep each diagram readable at phone width: at most about 15 nodes. Split a larger picture by area rather than shrinking it.
- Use the same encoding for new, modified, and existing across the architecture, Tables, JSON shapes, and Spec data model diagrams, with one shared legend.
- Every diagram has a text caption and a text alternative (the table beneath it), so the content survives without the picture.
