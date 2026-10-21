# Page Outline

The published page is a single HTML Artifact built under the `artifact-design` contract, with diagrams drawn under `artifact-diagramming`. Those skills own the visual system -- theme tokens, dark mode, typography, allowed CDNs, phone-width layout. This file owns the content: which sections exist, in what order, and what each must say.

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

The composition table from Phase 2 -- bucket, files, added, deleted, share -- with a horizontal stacked bar or bar chart of added lines by bucket. One sentence that names the real size of the change ("Of 100,000 added lines, about 24,000 are production code"). A second, smaller table: production code by area, files and added lines.

### 3. Architecture

A component diagram of the system as the PR leaves it, scoped to what the PR touches:

- the PR's new components, modified components, and the existing components they integrate with, visually distinguished (for example solid, outlined, and muted) with a legend
- grouped by layer or area (UI, API, services, workflows, storage, external systems)
- arrows labelled with the interface (HTTP, call, queue, event, workflow)

Below the diagram, a short list keyed to it: one line per box, named as the box is, saying what that component does in the system. No per-area component tables and no file paths -- the box is the unit of explanation, and the files behind it are detail the reader does not need to understand the design. A workflow, job, or scheduled task's line also gives what starts it, the model it runs on when it is an LLM workflow, and its run limits. A box with architecture findings ends its line with their IDs, linked to the Architecture assessment ("Findings A1, A5"). Code-review findings are not linked here.

### 4. Data model

An entity-relationship diagram of the new and changed entities and the existing entities they relate to, new versus changed visually distinguished. The diagram carries the key fields. Then a table: entity, created or changed, role, notes. The role says what the entity represents, who or what writes it and when, and how it lives over time (append-only with one row per reading, mutable under a version counter, removed on close). Notes hold the migration name and constraints worth knowing. Do not list fields in the table -- the diagram already shows them. Field names only, anywhere on the page -- no data.

### 5. Key flows

Two to four sequence diagrams, one per flow, each with a one-sentence caption naming the trigger and the outcome. Participants are components and external systems, not files. Pick the flows that best explain the capability in section 1; a flow per user story is a good default when a spec exists.

Above the first diagram, one line on how to read it: participants across the top, time runs down, a solid arrow is a call, a dashed arrow is its reply, an open arrowhead is a handoff that does not wait, `loop` repeats, and `alt` / `else` means one branch runs.

- **Number the steps.** Start every sequence diagram with `autonumber`, so the caption and the text can cite a step ("from step 6 the run is in the background").
- **Show every reply, and every handoff that does not wait.** An HTTP call gets its dashed reply (`-->>`) at the point the response is actually sent. Work that continues after the caller has its answer -- a background task, a queued job, an event, a workflow run -- is an async arrow (`-)`), and the caller's reply comes before it, so the diagram never implies a request waits for work it does not wait for.
- **Keep participants consistent across flows.** A component that sits between two others in one flow (a tool layer, a gateway) sits between them in every flow that crosses it, under the same name. Define the participant set once from the architecture diagram's boxes and draw each flow from that set.
- **Label arrows in plain words.** Each message says what is asked for in a few words ("store the file", "record the check"); the code name, when it helps the reader find it, goes after it in parentheses. Never a bare function or tool name.

### 6. State machines

One state diagram per state machine the PR adds or changes, with transition triggers on the arrows. Omit the section when there are none.

### 7. Surfaces

- **API surface**: method, path, purpose, area -- new and changed endpoints only.
- **UI surface**: a table of screen or major component, before, after. Before says what the reader saw there at the base commit ("did not exist" for a new screen); after says what they see at head. Describe what a user sees and can do, not components, and only what the diff changed.

Omit either table when it would be empty. Workflows, jobs, and tools are boxes in the architecture section, not a list here.

### 8. Spec map and drift

Only when a spec governs the PR. Open with: "A high-level comparison of the code with `specs/<slug>`, not a converge pass."

- **Requirement map**: each user story with its requirements, the area or areas implementing them, and a status (implemented, partial, not found). A partial or not-found row says on the row what is missing and the search that was run, so a gap is read where its story is -- there is no separate list of gaps.
- **Beyond spec**: capabilities with no requirement. Omit the heading when there are none.
- **Plan departures**: plan decisions the code does differently, with both sides stated. When there are none, write nothing -- no heading, no "none found", no note about the plan's own amendments.

A requirement that first looked missing but is satisfied by an existing mechanism is marked implemented in the map, and the mechanism goes in the coverage notes -- it is a record of how the analysis ran, not a fact about the PR.

When no spec governs the PR, replace the section with one line saying so and naming what intent was drawn from (PR body, linked issues).

### 9. Architecture assessment

The Phase 6 verdict, from `references/architecture-verdict.md`. Open with the verdict, its one-sentence reason, the commit assessed, and the rules it was judged against (by path). Say plainly that it weighs design only and that code-review defects never decide it.

- **Findings**: each in-change architecture finding, most severe first, as a collapsed `<details>`. The summary line carries its ID, severity pill, a "hard to reverse" pill naming the area when it applies, the headline, and the box or flow it touches. Expanded, it holds where, why it matters, the recommendation, and the standard or rule it cites -- credited and linked when a reviewer raised it first. A box in the architecture list with a finding links here.
- **Conformance**: each departure from the constitution, `AGENTS.md`, or the core standards, with its evidence, or one line saying there were none and naming what was read. Note any rule file the PR itself changes.
- **Pending code-review fixes**: only for an Approve pending code-review fixes -- the must-fix items the approval waits on, one line each: ID, headline, status, linked. This is the only place code-review findings appear on the page.
- **Follow-ups for the author**: each with its reason and repository. Omit when none.
- The rubric's design themes are not shown; when one root cause spans several findings, the verdict's one-sentence reason names it. Its "checked and sound" line goes in the coverage notes, not here.

When the verdict did not run, replace the section with one line saying why and what to install. When it is not applicable (no executable code), say so in one line.

### 10. Questions for the author

Three to six questions the explanation raised, each about intent the code cannot reveal: a spec ambiguity, a design choice nothing explains, behaviour the code leaves undefined. Never repeat a question a reviewer has already asked on the PR, or one the architecture assessment already answers. Questions only -- no recommendations, priorities, or follow-ups; design judgments belong in the architecture assessment. These same questions go in the posted review (`references/architecture-verdict.md`). Omit the section when the explanation raised none.

### 11. Coverage notes

Collapsed by default. How the analysis ran (single pass, or M area analysts with the area plan table), what each analyst skimmed or could not read, claims dropped or marked unverified, requirements checked and resolved (each with the mechanism that satisfies it), which review sources were read and which status-only bots were skipped, how the architecture pass ran (inline or one critic), the design decisions it checked and found sound, and the candidates it dropped past the budget, and what was sampled from the tests, seeds, and generated buckets (one line per bucket, describing coverage and entities, never values).

## Diagram guidance

- **Choose the medium by diagram type.** Artifacts render Mermaid natively from `<pre class="mermaid">` blocks, with no library to load. Use Mermaid for the entity-relationship, sequence, and state diagrams, whose layout it handles well, and leave theming to the renderer -- no `classDef` colors, which ignore dark mode. Hand-draw the architecture diagram and the size chart as inline SVG, colored through the page's theme tokens and `currentColor`, because they need the new/modified/existing encoding and an exact scale.
- **Make every diagram enlargeable.** Wrap each diagram -- each hand-drawn SVG container and each `<pre class="mermaid">` -- in an element with class `zoomable`, `tabindex="0"`, `role="button"` and `aria-label="Enlarge diagram"`, and give it a small "Enlarge" badge on its top edge. Wrap the Mermaid block rather than tagging the `<pre>`, because the renderer may replace the `<pre>` with its SVG. One page-level script opens a full-screen viewer when a `zoomable` is clicked or activated with Enter or Space. The viewer clones the diagram's `<svg>` (sized from its `viewBox`) into a stage with zoom by wheel, pinch, double-click and +/− buttons, drag to pan, a Fit button, a zoom percentage, and Escape to close and return focus. Use event delegation on `document`, since Mermaid renders after the page loads. Hide the viewer with the `hidden` attribute and put `[hidden] { display: none !important; }` in the page's own CSS, so a closed viewer can never cover the page when it is rendered outside the Artifact skeleton. Large sequence and architecture diagrams are unreadable at column width without it.
- **Keep Mermaid syntax plain.** Write path parameters as `:id` rather than `{id}` in sequence messages, give multi-word states an alias (`state "Follow-Up Sent" as FUS`), and keep `;` and `#` out of labels.
- Diagrams show the mechanism, not decoration. Every box is a real component, entity, or external system named in the code at head.
- Keep each diagram readable at phone width: at most about 15 nodes. Split a larger picture by area rather than shrinking it.
- Use the same encoding for new, modified, and existing across the architecture and data-model diagrams, with one shared legend.
- Every diagram has a text caption and a text alternative (the table beneath it), so the content survives without the picture.
