# Page Style

The fixed visual system for the explanation page. Every run builds the page from this file, so every page looks the same: the same fonts, palette, ruled sections, tables, pills, size chart, architecture drawing, and diagram viewer. `references/page-outline.md` owns the content; this file owns how it looks.

Copy the font link, the stylesheet, the viewer markup, and the script below verbatim. Do not choose another palette, typeface, or layout, and do not rename a class or a token. The `artifact-design` skill gives an existing design system precedence over its own choices, and this file is that system. Its page contract still applies -- the `<title>`, the allowed CDNs, phone width, both themes -- and this stylesheet already meets it. Mermaid diagrams are themed by the Artifact runtime, so they get no `classDef` colors.

## Skeleton

Write the page in this order. The Artifact publish step wraps it in the document skeleton, so it has no `<!doctype>`, `<html>`, `<head>`, or `<body>` of its own.

```html
<title>PR <n> Explained</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Serif:wght@500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
  /* the stylesheet below, verbatim */
</style>

<div class="page">
  <header class="stack">...</header>
  <section id="builds">...</section>
  <section id="size">...</section>
  <section id="architecture">...</section>
  <section id="tables">...</section>
  <section id="json-shapes">...</section>
  <section id="spec-data-model">...</section>
  <!-- the remaining sections, in page-outline.md order -->
  <section id="coverage-wrap">...</section>
</div>

<!-- the viewer markup below, verbatim -->
<script>
  /* the script below, verbatim */
</script>
```

## Stylesheet

```css
/* Layout: one reading column (~76ch) with wide figures that may break out to 1100px; ruled sections, no cards except tables, figures, findings and the box panel. */
:root {
  --bg: #f6f8f9;
  --surface: #ffffff;
  --fg: #17232b;
  --muted: #5a6b76;
  --rule: #d5dee3;
  --accent: #0b6e7f;
  --accent-soft: #dff0f2;
  --warn: #9a5b00;
  --warn-soft: #fbeed8;
  --crit: #b3261e;
  --crit-soft: #fbe3e1;
  --ok: #2c6e3f;
  --ok-soft: #e1f1e5;
  --violet: #6a3fb0;
  --violet-soft: #ece4f8;
  --font-display: "IBM Plex Serif", Georgia, "Times New Roman", serif;
  --font-body: "IBM Plex Sans", system-ui, -apple-system, "Segoe UI", sans-serif;
  --font-mono: "IBM Plex Mono", ui-monospace, "SFMono-Regular", Menlo, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #0f171c; --surface: #16222a; --fg: #e3eaee; --muted: #9aabb5; --rule: #2a3a44;
    --accent: #5cc3d3; --accent-soft: #123a42; --warn: #e9b35c; --warn-soft: #3a2a10;
    --crit: #f0857d; --crit-soft: #431c1a; --ok: #7fcf96; --ok-soft: #173322;
    --violet: #b89cf0; --violet-soft: #2c2142; color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #0f171c; --surface: #16222a; --fg: #e3eaee; --muted: #9aabb5; --rule: #2a3a44;
  --accent: #5cc3d3; --accent-soft: #123a42; --warn: #e9b35c; --warn-soft: #3a2a10;
  --crit: #f0857d; --crit-soft: #431c1a; --ok: #7fcf96; --ok-soft: #173322;
  --violet: #b89cf0; --violet-soft: #2c2142; color-scheme: dark;
}
[hidden] { display: none !important; }
* { box-sizing: border-box; }
body { background: var(--bg); color: var(--fg); font-family: var(--font-body); font-size: 15.5px; line-height: 1.6; margin: 0; }
.page { max-width: 1100px; margin: 0 auto; padding-inline: 16px; padding-block: 28px 64px; }
.col { max-width: 76ch; }
h1, h2, h3 { font-family: var(--font-display); text-wrap: balance; line-height: 1.25; margin: 0; }
h1 { font-size: clamp(1.6rem, 3.2vw, 2.2rem); font-weight: 600; }
h2 { font-size: 1.45rem; font-weight: 600; padding-top: 10px; }
h3 { font-size: 1.1rem; font-weight: 600; }
section { display: flex; flex-direction: column; gap: 14px; padding-block: 30px; border-top: 1px solid var(--rule); }
p { margin: 0; }
a { color: var(--accent); }
a:focus-visible, button:focus-visible, .zoomable:focus-visible, summary:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
code, .mono { font-family: var(--font-mono); font-size: 0.86em; }
code { background: var(--accent-soft); padding: 0 4px; border-radius: 3px; overflow-wrap: anywhere; }
.eyebrow { font-family: var(--font-mono); font-size: 0.75rem; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); }
.meta { display: flex; flex-wrap: wrap; gap: 6px 18px; color: var(--muted); font-size: 0.9rem; }
.verdict-line { display: flex; flex-wrap: wrap; align-items: baseline; gap: 10px; padding: 12px 14px; border: 1px solid var(--crit); background: var(--crit-soft); border-radius: 6px; }
.verdict-line.pending { border-color: var(--warn); background: var(--warn-soft); }
.verdict-line.approve { border-color: var(--ok); background: var(--ok-soft); }
.verdict-line.none { border-color: var(--rule); background: var(--surface); }
.notice { font-size: 0.9rem; color: var(--muted); }
.pill { display: inline-block; font-family: var(--font-mono); font-size: 0.72rem; letter-spacing: 0.04em; padding: 1px 8px; border-radius: 999px; border: 1px solid currentColor; white-space: nowrap; font-weight: 500; }
.pill.crit { color: var(--crit); background: var(--crit-soft); }
.pill.warn { color: var(--warn); background: var(--warn-soft); }
.pill.ok { color: var(--ok); background: var(--ok-soft); }
.pill.dec { color: var(--violet); background: var(--violet-soft); }
.pill.neutral { color: var(--muted); }
.tablewrap { overflow-x: auto; border: 1px solid var(--rule); border-radius: 6px; background: var(--surface); }
table { border-collapse: collapse; width: 100%; font-size: 0.9rem; }
th, td { text-align: left; vertical-align: top; padding: 7px 10px; border-bottom: 1px solid var(--rule); }
th { font-weight: 600; font-size: 0.8rem; color: var(--muted); letter-spacing: 0.02em; background: var(--bg); }
tr:last-child td { border-bottom: 0; }
td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
tfoot td { font-weight: 600; border-top: 1px solid var(--rule); }
figure { margin: 0; display: flex; flex-direction: column; gap: 8px; }
figcaption { font-size: 0.88rem; color: var(--muted); max-width: 76ch; }
.zoomable { position: relative; overflow-x: auto; background: var(--surface); border: 1px solid var(--rule); border-radius: 6px; padding: 14px; cursor: zoom-in; }
.zoomable::before { content: "Enlarge"; position: absolute; top: 6px; right: 8px; font-family: var(--font-mono); font-size: 0.7rem; color: var(--muted); border: 1px solid var(--rule); background: var(--bg); padding: 0 6px; border-radius: 3px; }
.zoomable svg { display: block; max-width: 100%; height: auto; margin: 0 auto; }
pre.mermaid { margin: 0; background: transparent; }
.legend { display: flex; flex-wrap: wrap; gap: 8px 18px; font-size: 0.85rem; color: var(--muted); align-items: center; }
.sw { display: inline-block; width: 22px; height: 12px; border-radius: 2px; vertical-align: -1px; margin-right: 6px; }
.sw.new { background: var(--accent-soft); border: 2px solid var(--accent); }
.sw.mod { background: transparent; border: 1.5px dashed var(--accent); }
.sw.old { background: transparent; border: 1px solid var(--muted); opacity: 0.7; }
.sw.ext { background: transparent; border: 1px dotted var(--muted); }
dl.keyed { display: grid; grid-template-columns: minmax(0, 15rem) minmax(0, 1fr); gap: 6px 18px; margin: 0; }
dl.keyed dt { font-weight: 600; }
dl.keyed dd { margin: 0; }
@media (max-width: 640px) { dl.keyed { grid-template-columns: minmax(0, 1fr); } dl.keyed dd { margin-bottom: 8px; } }
ul, ol { margin: 0; padding-left: 1.3em; display: flex; flex-direction: column; gap: 4px; }
details.finding { border: 1px solid var(--rule); border-radius: 6px; background: var(--surface); }
details.finding > summary { cursor: pointer; padding: 10px 12px; display: flex; flex-wrap: wrap; gap: 6px 8px; align-items: baseline; list-style: none; }
details.finding > summary::-webkit-details-marker { display: none; }
details.finding > summary::before { content: "+"; font-family: var(--font-mono); color: var(--muted); width: 1ch; }
details.finding[open] > summary::before { content: "\2212"; }
details.finding .body { padding: 0 14px 14px 30px; display: flex; flex-direction: column; gap: 8px; font-size: 0.93rem; }
.fid { font-family: var(--font-mono); font-weight: 600; }
.hl { font-weight: 500; }
.touches { color: var(--muted); font-size: 0.85rem; }
details.coverage > summary { cursor: pointer; font-family: var(--font-display); font-size: 1.45rem; font-weight: 600; }
details.coverage .inner { display: flex; flex-direction: column; gap: 12px; padding-top: 12px; font-size: 0.93rem; }
.stack { display: flex; flex-direction: column; gap: 12px; }
/* Architecture: clickable boxes and the side panel */
.archgrid { display: grid; grid-template-columns: minmax(0, 1fr) 300px; gap: 16px; align-items: start; }
@media (max-width: 860px) { .archgrid { grid-template-columns: minmax(0, 1fr); } }
.zoomable.arch { cursor: default; }
.zoomable.arch::before { content: none; }
.zoombtn { position: absolute; top: 6px; right: 8px; z-index: 1; font-family: var(--font-mono); font-size: 0.7rem; color: var(--muted); border: 1px solid var(--rule); background: var(--bg); padding: 0 6px; border-radius: 3px; cursor: zoom-in; }
.panel { background: var(--surface); border: 1px solid var(--rule); border-radius: 6px; padding: 12px 14px; font-size: 0.92rem; display: flex; flex-direction: column; gap: 8px; min-width: 0; }
.panel h4 { font-family: var(--font-display); font-size: 1.05rem; font-weight: 600; margin: 0; }
.box { cursor: pointer; }
.box:focus { outline: none; }
.box rect { fill: var(--surface); stroke: var(--muted); stroke-width: 1; }
.box.new rect { fill: var(--accent-soft); stroke: var(--accent); stroke-width: 2; }
.box.mod rect { fill: var(--surface); stroke: var(--accent); stroke-width: 1.5; stroke-dasharray: 5 3; }
.box.old rect { fill: var(--surface); stroke: var(--muted); stroke-width: 1; }
.box.ext rect { fill: none; stroke: var(--muted); stroke-width: 1.2; stroke-dasharray: 2 3; }
.box text { fill: currentColor; }
.box text.name { font-weight: 600; }
.box text.sub { fill: var(--muted); font-size: 11px; }
.box:hover rect, .box:focus-visible rect { stroke-width: 2.5; }
.box[aria-pressed="true"] rect { stroke: var(--fg); stroke-width: 3; stroke-dasharray: none; }
/* Viewer */
.viewer { position: fixed; inset: 0; z-index: 50; background: var(--bg); display: flex; flex-direction: column; }
.viewer-bar { display: flex; gap: 8px; align-items: center; padding: calc(8px + env(safe-area-inset-top, 0px)) 12px 8px; border-bottom: 1px solid var(--rule); background: var(--surface); }
.viewer-bar button { font: inherit; font-size: 0.85rem; padding: 4px 10px; border: 1px solid var(--rule); background: var(--bg); color: var(--fg); border-radius: 4px; cursor: pointer; }
.viewer-bar .pct { font-family: var(--font-mono); font-size: 0.8rem; color: var(--muted); min-width: 5ch; }
.viewer-bar .spacer { flex: 1; }
.viewer-body { flex: 1; display: grid; grid-template-columns: minmax(0, 1fr); min-height: 0; }
.viewer.with-panel .viewer-body { grid-template-columns: minmax(0, 1fr) 300px; }
@media (max-width: 860px) { .viewer.with-panel .viewer-body { grid-template-columns: minmax(0, 1fr); grid-template-rows: minmax(0, 1fr) auto; } }
.viewer-panel { border: 0; border-left: 1px solid var(--rule); border-radius: 0; overflow: auto; max-height: 100%; }
@media (max-width: 860px) { .viewer-panel { border-left: 0; border-top: 1px solid var(--rule); max-height: 40vh; } }
.stage { flex: 1; overflow: hidden; position: relative; cursor: grab; touch-action: none; min-height: 0; }
.stage.dragging { cursor: grabbing; }
.stage > .canvas { position: absolute; left: 0; top: 0; transform-origin: 0 0; }
.stage svg { display: block; }
@media (prefers-reduced-motion: no-preference) { details.finding > summary { transition: background 0.15s; } }
details.finding > summary:hover { background: var(--bg); }
```

## Viewer markup and script

Place the markup after `.page` and the script after it.

```html
<div class="viewer" id="viewer" hidden role="dialog" aria-modal="true" aria-label="Diagram viewer">
  <div class="viewer-bar">
    <button type="button" id="vz-out" aria-label="Zoom out">&minus;</button>
    <span class="pct" id="vz-pct">100%</span>
    <button type="button" id="vz-in" aria-label="Zoom in">+</button>
    <button type="button" id="vz-fit">Fit</button>
    <span class="spacer"></span>
    <button type="button" id="vz-close">Close</button>
  </div>
  <div class="viewer-body">
    <div class="stage" id="vz-stage"><div class="canvas" id="vz-canvas"></div></div>
    <aside class="panel viewer-panel" id="vz-panel" aria-live="polite" hidden></aside>
  </div>
</div>
```

```js
(function () {
  var viewer = document.getElementById('viewer');
  var stage = document.getElementById('vz-stage');
  var canvas = document.getElementById('vz-canvas');
  var vpanel = document.getElementById('vz-panel');
  var pct = document.getElementById('vz-pct');
  var scale = 1, tx = 0, ty = 0, w = 0, h = 0, opener = null, moved = false;
  function apply() { canvas.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + scale + ')'; pct.textContent = Math.round(scale * 100) + '%'; }
  function fit() {
    var sw = stage.clientWidth, sh = stage.clientHeight;
    if (!w || !h || !sw || !sh) return;
    scale = Math.min(sw / w, sh / h) * 0.95;
    tx = (sw - w * scale) / 2; ty = (sh - h * scale) / 2; apply();
  }
  function zoomAt(f, cx, cy) {
    var ns = Math.max(0.1, Math.min(8, scale * f));
    tx = cx - (cx - tx) * (ns / scale); ty = cy - (cy - ty) * (ns / scale); scale = ns; apply();
  }
  function archPanel() { return document.getElementById('archpanel'); }
  function open(el) {
    var svg = el && el.querySelector('svg');
    if (!svg) return;
    opener = el;
    var clone = svg.cloneNode(true);
    var vb = svg.viewBox && svg.viewBox.baseVal;
    if (vb && vb.width) { w = vb.width; h = vb.height; }
    else { var r = svg.getBoundingClientRect(); w = r.width || 800; h = r.height || 600; }
    clone.setAttribute('width', w); clone.setAttribute('height', h);
    clone.style.maxWidth = 'none'; clone.style.width = w + 'px'; clone.style.height = h + 'px';
    canvas.innerHTML = ''; canvas.appendChild(clone);
    canvas.style.color = getComputedStyle(el).color;
    var arch = el.classList.contains('arch') && !!archPanel();
    viewer.classList.toggle('with-panel', arch);
    vpanel.hidden = !arch;
    vpanel.innerHTML = arch ? archPanel().innerHTML : '';
    viewer.hidden = false;
    document.body.style.overflow = 'hidden';
    document.getElementById('vz-close').focus();
    requestAnimationFrame(fit);
  }
  function close() {
    viewer.hidden = true; canvas.innerHTML = ''; vpanel.innerHTML = '';
    document.body.style.overflow = '';
    if (opener) opener.focus();
  }
  function select(id) {
    var detail = document.querySelector('[data-box-detail="' + id + '"]');
    if (!detail) return;
    document.querySelectorAll('.box[data-box]').forEach(function (b) {
      b.setAttribute('aria-pressed', b.getAttribute('data-box') === id ? 'true' : 'false');
    });
    if (archPanel()) archPanel().innerHTML = detail.innerHTML;
    if (!viewer.hidden && !vpanel.hidden) vpanel.innerHTML = detail.innerHTML;
  }
  document.addEventListener('click', function (e) {
    if (!e.target.closest) return;
    if (moved && stage.contains(e.target)) { moved = false; return; }
    var box = e.target.closest('.box[data-box]');
    if (box) { select(box.getAttribute('data-box')); return; }
    var btn = e.target.closest('.zoombtn');
    if (btn) { open(btn.closest('.zoomable')); return; }
    var z = e.target.closest('.zoomable');
    if (z && !z.classList.contains('arch') && viewer.hidden) open(z);
  });
  document.addEventListener('keydown', function (e) {
    if (!viewer.hidden && e.key === 'Escape') { close(); return; }
    if (e.key !== 'Enter' && e.key !== ' ') return;
    var box = e.target.closest && e.target.closest('.box[data-box]');
    if (box) { e.preventDefault(); select(box.getAttribute('data-box')); return; }
    var z = e.target.classList && e.target.classList.contains('zoomable') && !e.target.classList.contains('arch') ? e.target : null;
    if (z) { e.preventDefault(); open(z); }
  });
  document.getElementById('vz-close').addEventListener('click', close);
  document.getElementById('vz-fit').addEventListener('click', fit);
  document.getElementById('vz-in').addEventListener('click', function () { zoomAt(1.25, stage.clientWidth / 2, stage.clientHeight / 2); });
  document.getElementById('vz-out').addEventListener('click', function () { zoomAt(0.8, stage.clientWidth / 2, stage.clientHeight / 2); });
  stage.addEventListener('wheel', function (e) { e.preventDefault(); var r = stage.getBoundingClientRect(); zoomAt(e.deltaY < 0 ? 1.12 : 0.89, e.clientX - r.left, e.clientY - r.top); }, { passive: false });
  stage.addEventListener('dblclick', function (e) { var r = stage.getBoundingClientRect(); zoomAt(1.6, e.clientX - r.left, e.clientY - r.top); });
  var pointers = new Map(), lastDist = 0, startX = 0, startY = 0;
  stage.addEventListener('pointerdown', function (e) {
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    startX = e.clientX; startY = e.clientY; moved = false;
    stage.classList.add('dragging');
  });
  stage.addEventListener('pointermove', function (e) {
    var last = pointers.get(e.pointerId);
    if (!last) return;
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 2) {
      var p = Array.from(pointers.values());
      var d = Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y);
      var r = stage.getBoundingClientRect();
      if (lastDist) zoomAt(d / lastDist, (p[0].x + p[1].x) / 2 - r.left, (p[0].y + p[1].y) / 2 - r.top);
      lastDist = d; moved = true;
    } else {
      tx += e.clientX - last.x; ty += e.clientY - last.y; apply();
      if (Math.abs(e.clientX - startX) + Math.abs(e.clientY - startY) > 4) moved = true;
    }
  });
  function up(e) { pointers.delete(e.pointerId); if (pointers.size < 2) lastDist = 0; if (!pointers.size) stage.classList.remove('dragging'); }
  stage.addEventListener('pointerup', up); stage.addEventListener('pointercancel', up); stage.addEventListener('pointerleave', up);
})();
```

## Class vocabulary

Use these classes for these jobs, and no others.

| Element | Markup |
| ------- | ------ |
| Page wrapper | `<div class="page">`; running text that should stay at reading width gets `class="col"`; a vertical group gets `class="stack"` |
| Section | `<section id="...">` with an `h2`; sub-heads are `h3`. Sections are ruled by the stylesheet, so add no dividers |
| Header | `<header class="stack">` holding `<div class="eyebrow">Architecture explanation</div>`, the `h1`, a `<div class="meta">` of `<span>` facts, the verdict line, and the skimmed/unverified `<p class="notice">` |
| Verdict line | `<div class="verdict-line">` (Request changes), `verdict-line pending` (Approve pending code-review fixes), `verdict-line approve` (Approve), `verdict-line none` (did not run or not applicable), holding the verdict pill and its one-sentence reason |
| Pills | `pill crit`: Request changes, Blocker, Critical, hard to reverse, not found. `pill warn`: Major, Approve pending code-review fixes, partial. `pill ok`: Approve, implemented. `pill dec`: Decision needed. `pill neutral`: anything else |
| Notes and captions | `<p class="notice">` for secondary lines; every figure has a `<figcaption>` |
| Tables | `<div class="tablewrap"><table>` with `thead`, `tbody`, and a `tfoot` for totals; number cells and their headers get `class="num"` |
| Diagram | `<figure>` holding `<div class="zoomable" tabindex="0" role="button" aria-label="Enlarge diagram">` around the `<svg>` or `<pre class="mermaid">`, then the `figcaption`. The stylesheet draws the Enlarge badge |
| Legend | `<div class="legend">` of `<span><span class="sw new"></span>New</span>`, with `sw mod` (Modified), `sw old` (Existing), `sw ext` (External), and a plain span for the dashed-arrow meaning |
| Architecture | `<div class="archgrid">` holding the figure and `<aside class="panel" id="archpanel" aria-live="polite">`. The figure's container is `<div class="zoomable arch">` (no `tabindex` or `role`) with `<button type="button" class="zoombtn">Enlarge</button>` as its first child. Box details sit in one `<div hidden>` as `<div data-box-detail="<id>">`, each opening with an `h4` and an `eyebrow` reading New, Modified, Existing, or External |
| Key-value list | `<dl class="keyed">` |
| Finding | `<details class="finding" id="A1">`; its `summary` holds `<span class="fid">A1</span>`, the pills, `<span class="hl">` headline, and `<span class="touches">` naming the box or flow; the expanded `<div class="body">` holds `<p><strong>Where:</strong> ...</p>` paragraphs |
| Coverage notes | `<section id="coverage-wrap"><details class="coverage" id="coverage"><summary>Coverage notes</summary><div class="inner">...</div></details></section>` |

## Size and composition chart

A horizontal bar chart of added lines by bucket, hand-drawn as inline SVG on one scale. Fill in this template; nothing else about it changes.

- **Rows:** one per bucket with added lines above zero, largest first. Row `i` (from 0) has its bar at `y = 15 + 32*i`, and its label and value baselines at `y + 13`.
- **Height:** the `viewBox` is `0 0 900 H`, with `H = 32 * rows + 26`.
- **Scale:** the largest bucket's bar is 600 wide. Every other bar is `600 * added / largest`, rounded to one decimal, and at least 2 so a small bucket still shows.
- **Labels:** right-aligned at `x = 200`, in `currentColor`. Use the bucket names Tests, Production code, Spec artifacts, Docs, Migrations and schema, Code loaded as text (name what it is, for example "Workflow prompt (code as text)"), Config and infrastructure, Seed and fixture data, and Generated and lockfiles.
- **Values:** the added-line count with thousands separators, in mono 12, at `x = 212 + width + 8`.
- **Color:** buckets counted as architecture -- Production code, Code loaded as text, Migrations and schema, Config and infrastructure -- fill `var(--accent)`. Spec artifacts fill `var(--muted)` at opacity 0.35. Every other bucket fills `var(--muted)` at opacity 0.55.
- **Axis:** one vertical line at `x = 212`, from `y = 8` to `y = H - 18`.

```html
<figure>
  <div class="zoomable" tabindex="0" role="button" aria-label="Enlarge diagram">
    <svg viewBox="0 0 900 H" role="img" aria-label="Added lines by bucket: <bucket> <count>; ..." font-family="IBM Plex Sans, system-ui, sans-serif" font-size="13">
      <text x="200" y="28" text-anchor="end" fill="currentColor">Tests</text>
      <rect x="212" y="15" width="600" height="18" rx="2" fill="var(--muted)" opacity="0.55"/>
      <text x="820" y="28" fill="currentColor" font-family="IBM Plex Mono, monospace" font-size="12">50,771</text>
      <text x="200" y="60" text-anchor="end" fill="currentColor">Production code</text>
      <rect x="212" y="47" width="241.5" height="18" rx="2" fill="var(--accent)"/>
      <text x="461.5" y="60" fill="currentColor" font-family="IBM Plex Mono, monospace" font-size="12">20,435</text>
      <!-- one label, bar and value per remaining bucket -->
      <line x1="212" y1="8" x2="212" y2="H - 18" stroke="currentColor" stroke-width="1"/>
    </svg>
  </div>
  <figcaption>Added lines by bucket, one scale. Teal marks production code, counted as architecture; grey marks everything else. The table below carries the same numbers.</figcaption>
</figure>
```

Write `H` and `H - 18` as the computed numbers. The section around the chart is, in order:

1. the `h2` "Size and composition";
2. a `<div class="col"><p>` sentence naming the real size of the change;
3. the chart;
4. the composition table: Bucket, Files, Added, Deleted, Share of added, with every bucket as a row including the empty ones on one combined row, and the totals in `tfoot`;
5. a `<p class="notice col">` reconciling git's and GitHub's counts when they differ, and naming the classification judgment calls;
6. the `h3` "Production code by area", with a table of Area, Files and Added, and its total in `tfoot`.

## Architecture drawing

The architecture diagram is inline SVG drawn on a fixed grid, so every page's drawing reads the same.

- **Canvas:** `viewBox="0 0 1080 <100 * layers>"`, with `font-family="IBM Plex Sans, system-ui, sans-serif"` and `font-size="12.5"` on the `<svg>`.
- **Layers:** each layer is a band 100 high. Its name sits at `x = 12`, 52 below the band's top, in `font-family="IBM Plex Mono, monospace"`, `font-size="11"`, `letter-spacing="0.06em"`, filled `var(--muted)`. A `var(--rule)` line from `x = 12` to `x = 1068` divides each band from the next.
- **Boxes:** 220 wide and 56 high with `rx="5"`, at 20 below their band's top, in four columns at `x = 110, 350, 590, 830`. Each box is a `<g class="box new|mod|old|ext" data-box="<id>" role="button" tabindex="0" aria-controls="archpanel" aria-label="<name>" aria-pressed="false">` holding the `rect`, a `<text class="name">` centered 24 below the box's top, and a `<text class="sub">` centered 42 below it.
- **Arrows:** `stroke="currentColor"` at width 1.3 with `marker-end`, dashed `6 4` for a handoff that does not wait. The marker is a `<marker>` whose path fills `currentColor`.
- **Arrow labels:** `font-size="11"`, filled `var(--muted)`, placed beside the line and clear of every box.
