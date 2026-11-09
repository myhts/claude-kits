# Explorer data format

One ES module, `explorer-data.js`, default-exports everything the page shows. The engine has no project knowledge;
all of it lives here. A complete working example: `template/data/explorer-data.example.js`.

```js
import { G } from "./explorer-engine.js";      // gauge helper (only import you usually need)
const S = "src/orders/";                         // path prefixes keep links short; paths are repo-relative
export default { meta, modules, map, flows, concepts, widgets };
```

Split big data into several files (`data/flows-orders.js`, `data/concept-retries.js`) and import them; the bundler
inlines relative imports. Allowed forms: `import { a } from "./x.js"`, `import x from "./x.js"`, `export default`,
`export const x =`, `export function f`, `export { a, b }`. Nothing else (no `export *`, no bare package imports).

Text fields accept a little markdown: `` `code` ``, `**bold**`, `*italic*`, bare `https://` links, and in-page links
`[label](#concept=id&level=L2)`.

## meta

| field | meaning |
|---|---|
| `title`, `subtitle` | header text |
| `pagePath` | repo-relative path of the generated HTML (e.g. `docs/explorer/explorer.html`). From `file://` the engine strips it from the URL to find the repo root, so code links open the editor |
| `repoRoot` | absolute repo path. **Don't commit it**: framework shells pass it from an env var instead |
| `repoUrl` | e.g. `https://github.com/org/repo/blob/main`: link target when there's no local root |
| `editor` | `vscode` (default), `cursor`, `windsurf`, `idea` |
| `measuredOn` | "2026-10-16, M2 laptop, Docker 8 GB": shown next to every `measured` number |
| `labsDoc` | repo-relative path of LABS.md, linked from every lab |
| `startHere` | one or two sentences: which flow to follow first |
| `guides` | `[[label, path], …]`: listed on the start panel |
| `howto` | replaces the whole start panel (markdown-ish string) |

## modules

`{ key: { label, color, dark? } }`. The coloured bar on each map box and the legend. Use mid-tone colours that work on
light and dark; give `dark` only for very dark colours. Modules = ownership/deployment units (service, module, team),
not technical layers.

## map

```js
map: {
  lanes: [{ id: "api", label: "API" }, …],          // top to bottom: client → edge → services → async → workers → data → external
  nodes: [{ id, lane, col, row?, span?, label, sub, mod, what, files, docs, observe }],
  edges: [{ from, to, label?, dashed?, around?, offset?, fromX?, toX?, pts?, labelAt? }],
  nodeWidth?: 190, nodeHeight?: 50, gapX?: 50, gapY?: 26, width?, height?,
}
```

- **Placement**: `lane` + `col` (0, 1, 2…) + optional `row` inside the lane. `span: 2` makes a box two columns wide.
  Explicit `x`/`y` (and `lane.y`/`lane.h`) override the grid; avoid them unless the grid can't express it.
- **Node**: `label` (≤ 24 chars), `sub` (≤ 30 chars, one line), `what` (2–4 sentences: its job, the one thing that
  surprises people), `files: [[path, line, note?], …]` (entry point first), `docs: [[label, path, line?], …]`,
  `observe` (how to watch it live: a URL, a CLI command, a log line).
- **Edge routing**: default is automatic (vertical with an elbow, or horizontal in a row). When it would cross a box,
  use `around: "left" | "right"` (+ `offset` to separate parallel ones) or `fromX`/`toX` to pick the exit/entry
  x, or `pts: [[x, y], …]` as a last resort. `check-explorer.mjs` reports every arrow that passes through a box.
- Edge id is `"from>to"`; flows refer to edges by that id.

## flows

```js
{ id: "place-order", title: "1. Place an order (happy path)", intro: "…", steps: [
  { n: ["ctl", "redis"],                 // boxes to light up
    e: ["ctl>limiter", "limiter>redis"], // arrows to light up (ids from map.edges)
    t: "Is there budget left?",          // step title: a question or an action, ≤ 60 chars
    x: "One atomic script takes a token…", // what happens and why, 1–4 sentences
    d: "POST /orders\n…",                // real data captured at this point (request, row, message, log). Scrubbed.
    bp: [path, line, "what to inspect"], // a breakpoint that was VERIFIED to hit during this flow
    st: [["add" | "chg" | "del", "Where", "what changed"], …],  // the state strip: new / changed / gone-or-untouched
    obs: "how to see it live",
    why: ["concept-id", "L2"] },         // link to the concept level that explains this design
]}
```

Number flows in the title (`1.`, `2.`…) in the order a learner should do them: the simplest single-thread path
first, the real (async, multi-component) path next, then failure paths, then reads/ops.

## concepts

```js
{ id: "partner-calls", title: "Calling a flaky partner", intro: "…", docs: [[label, path]],
  boxes: { w: { at: [col, row], label, sub, w?, h? }, … },   // the concept's own small diagram: 1000 × 340
  levels: [ LEVEL, … ],
  recap: { pattern, elsewhere: [[domain, how], …], say, undo: [ … ] } }
```

Scene grid: `at: [col, row]` → x = 16 + col × 210, y = 24 + row × 115. Four or five columns (0–4) and three rows (0–2)
fit; boxes default to 180 × 62. `x`/`y` work too. `sub` may contain `\n` for a second line.

**LEVEL**

| field | meaning |
|---|---|
| `id`, `name`, `q` | `"L1"`, short name, the question this level answers ("The partner is down for minutes. Why keep calling it?") |
| `proposed: true` | not built in this codebase: frames 2–3 become "What we'd change" / "Expected result" |
| `before`, `after` | scenes: `{ b: [boxId \| [boxId, overrides]], e: [[from, to, label?, flow?, opts?]], hurt?: [ids], changed?: [ids] }` |
| edge `flow` | moving dots: `ok` (blue), `heavy` (many, orange), `reject` (red, arrow stays red), `slow` (amber, one) |
| edge `opts` | `{ off: ±9 }` separate a pair of opposite arrows · `cls: "hurt"` red arrow · `ss`/`ts`: side `l r t b` · `la: [x, y]` label position · `dashed` |
| `cap` | three captions, one per frame: what's happening · what we changed · the result |
| `cause` | root cause, one sentence: why this hurts (not the symptom) |
| `g1`, `g3` | gauges for frames 1 and 3: `G(label, value, max, { text, st: "bad"\|"good", tag, note, thr, log })` |
| `diff` | `[["add"\|"chg"\|"del", "text", [path, line]?], …]`: what changed, each with a code link |
| `next` | the cost of this level: the new problem that forces the next level |
| `options` | `[["yes"\|"no"\|"alt", "option", "why"], …]`: what else was considered |
| `lesson` | optional: what building/measuring it taught (a surprise, a bug found) |
| `senior`, `staff` | optional: how to explain the decision at each level (interview prep) |
| `lab` | `{ cfg: "launch config name" \| "(no special config: …)", steps: ["…", …] }`: steps say what to run and what to **Check:** |
| `bp`, `tests` | verified breakpoint; `[[path, line, testName], …]` tests that prove the behaviour |
| `widget` | `"token-bucket" \| "circuit-breaker" \| "partitions"` or `{ name, args }`, or a project widget from `widgets` |

Gauge `tag` is mandatory in practice: `measured` (we ran it: put the run in MEASURED.md), `calculated` (arithmetic from
config/capacity model), `rule` (industry ballpark), `model` (simulated: a design not built). A proposed level can't
have `measured` results. `thr` draws a threshold line; `log` (the minimum) makes the bar logarithmic.

## widgets (optional)

`widgets: { name(host, api) { … } }`: render into `host`. `api` = `{ args, G, gaugeHtml, esc, fmt, tag, every(ms, fn) }`
(`every` timers stop when the reader navigates). Build one only when interaction teaches something a static frame can't
(a simulator, a calculator). Built-ins and their `args`:

- `token-bucket`: `{ capacity, refill }`: fixed window vs bucket, with a "straddle the boundary" replay
- `circuit-breaker`: `{ window, minCalls, failureRate, openSeconds, trials, failMs, rejectMs }`
- `partitions`: `{ partitions }`: consumers vs partitions, idle consumers past the count
