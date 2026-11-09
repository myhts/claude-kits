---
name: project-explorer
description: Turn any codebase (any language or framework) into an interactive architecture explorer with end-to-end debugging walkthroughs, step-by-step learning pathways and, if the user wants them, scaling labs with concept ladders. Use when the user wants to understand, onboard onto, debug end to end, or learn the system design of a project, or runs /project-explorer.
---

# Project explorer

You turn the current repository into something a learner can **walk through with a debugger**:

1. an interactive page: the architecture map, every important request path as a step-by-step flow (what happens,
   what changed, real captured data, a verified breakpoint), and optionally concept ladders that explain why it's
   built that way, level by level;
2. working debugger configs for every part of the system;
3. checkbox guides that go from "run it" to "break it";
4. optionally, labs that make scaling thresholds cross on the learner's machine, with measured numbers.

The page is generated from a data file by a fixed, tested engine. You write **data**, never page code.

## Files in this skill

| Path | What |
|---|---|
| `template/engine/explorer-engine.js`, `explorer.css` | The engine. Copy into the project unchanged |
| `template/data/explorer-data.example.js` | A complete small example: the format by example |
| `template/shells/{react,next,vue,svelte}/` | Wrappers for showing the page inside the project's own front end |
| `tools/bundle-html.mjs` | data → one standalone HTML file |
| `tools/validate-data.mjs` | checks ids, file paths and line numbers against the repo |
| `tools/check-explorer.mjs` | headless Chrome: visits every view in light and dark, reports hidden/overlapping labels, arrows through boxes, JS errors |
| `tools/gen-guides.mjs` | data → FLOWS.md and LABS.md checkbox guides |
| `tools/lab-kit.mjs` | localhost-only HTTP load/probe/poll driver for labs |
| `reference/data-schema.md` | the data format. **Read before writing data** |
| `reference/debuggers.md` | per-stack debugger configs and how to verify a breakpoint hits |
| `reference/concepts.md` | finding concepts and building ladders |
| `reference/labs.md` | the labs gate, failure switches, measuring |
| `reference/guides.md` | the pathways and how to write steps |
| `reference/ui-shells.md` | standalone HTML vs framework page |
| `reference/safety.md` | confidential data, shared resources, what needs asking. **Read first** |
| `reference/survey.md` | the survey on a big repository: readers on Sonnet, their fact sheet, merging and checking |

Tools need Node 22+; `check-explorer.mjs` also needs Chrome or Chromium. If Node is missing, ask before installing.

## Output in the target repo

```
docs/explorer/                    (or the folder agreed at gate 1)
  explorer.html                   generated: never edit by hand
  src/explorer-engine.js          copied from the skill: don't edit
  src/explorer.css                copied from the skill: don't edit
  src/explorer-data.js            the project's data (may import src/data/*.js)
  tools/                          copies of the five tools, so teammates without this skill can rebuild
  survey.json                     big repositories: what each service exposes, calls and stores, with file:line
  TOUR.md  FLOWS.md  LABS.md  MEASURED.md  PROGRESS.md
```

Framework option: the engine, css, data and wrapper go into the app (e.g. `src/dev/explorer/`); the guides and
tools stay in `docs/explorer/`. The data file still has one home; the bundler and the app import the same file.

## How to run

Work in phases. **Stop at every gate** and ask with AskUserQuestion; don't continue past a gate on assumptions.
After every phase, update `PROGRESS.md` (phase checklist, decisions, constraints, verified breakpoints, bugs found,
what's next). **If PROGRESS.md already exists, read it first and resume from it.** Say in one line which phase
you're starting.

**Who does what.** The judgement stays in this session, on Opus: the map, the flows, the explanations, the gates, the
screenshots. On a big repository the reading doesn't: survey with one Explore subagent per service or module, each
started with `model: "sonnet"`, as `reference/survey.md` says, and keep their fact sheets, not the file dumps. Start
any other subagent with `model: "opus"`. If this session isn't on Opus, say so in one line at the start.

### Phase 0: Safety and setup

1. Read `reference/safety.md`. Check for confidential data, secrets, shared infrastructure and other projects'
   containers/ports. Write the constraints into PROGRESS.md.
2. Check tools: `node --version` (22+), Chrome/Chromium, Docker if the project needs it, free disk.
3. If anything sensitive or shared turned up, that's an immediate question to the user before going further.

### Phase 1: Survey, then gate 1

1. Find the stack(s), the entry points (HTTP routes, message consumers, schedulers, CLIs, UI pages), the runtime
   dependencies (DBs, brokers, caches, external partners) and how the project is normally run (README, scripts,
   compose files, Makefile). On a big repository, the readers find these and you merge and check their sheets into
   `survey.json` (`reference/survey.md`).
2. **Run it** if you can, the normal way. A flow can only be captured from a running system. If it can't run here,
   say why; flows then come from reading code and are marked "traced from code, not run".
3. Draft the map: lanes top to bottom (client → edge → services/API → async → workers → data → external); 8–30 boxes,
   each one something a request passes through (a component, not every class); arrows for calls and messages.
4. Draft the flow list: the happy path of each major entry point; failure paths (validation, auth, limits,
   dependency down, duplicate/retry, crash and redelivery, timeouts); reads; ops paths (startup, shutdown, a migration).
   Order them simplest-first (a single-thread path before the async one).
5. Detect the front end for the UI choice (`reference/ui-shells.md`).
6. **Gate 1**: ask, in one AskUserQuestion call:
   - Which flows to build (multi-select; recommend the top 4–8).
   - Where the page lives: **standalone HTML (recommended)** · inside the detected `<framework>` app on a dev-only
     route · both. Only offer the framework option when one was detected; name it.
   - Output folder (default `docs/explorer/`).
   - Anything the survey left unclear that changes the work (which service matters most, a part to skip).

### Phase 2: Debuggers, then gate 2 if needed

Follow `reference/debuggers.md`: detect existing configs, add the missing ones for every process role, the browser
and lab variants. **Ask before** adding dependencies, build plugins, Dockerfile changes, or editing a tracked
`.vscode/`. Then verify: start under the debugger and prove a breakpoint hits in each role.

### Phase 3: Flows

1. Copy the engine, css and tools into the output folder. Start `src/explorer-data.js` from the example's shape
   (`reference/data-schema.md`): meta, modules, map.
2. For each approved flow: run it for real, capture the data at each step (request/response, rows, messages, cache
   keys, logs), **scrub it**, choose a breakpoint per step and **verify it hits** during that flow (record how in
   PROGRESS.md). Write the steps: `n`, `e`, `t`, `x`, `d`, `bp`, `st` (what changed: new / changed / untouched),
   `obs`. Keep `x` plain: what happens and why, 1–4 sentences.
3. After each flow or two:
   ```
   node <out>/tools/validate-data.mjs <out>/src/explorer-data.js --repo .
   node <out>/tools/bundle-html.mjs <out>/src/explorer-data.js <out>/explorer.html
   node <out>/tools/check-explorer.mjs <out>/explorer.html
   ```
   Fix every error and every reported view: move boxes, use `around`/`fromX`/`toX`, shorten labels. Look at a
   few screenshots yourself (`--shots <scratch dir>`); the checker catches geometry, not meaning.
4. Framework option: copy the wrapper, add the dev-only route, start the dev server, run `check-explorer.mjs` against
   its URL too.

### Phase 4: Pathways

Write `TOUR.md` by hand (`reference/guides.md`: the depth ladder, first hour, flow 1 and 2 under the debugger,
"if it doesn't stop here, …"). Generate `FLOWS.md` with `gen-guides.mjs`. Ask before adding links to the project's
README or other docs.

### Phase 5: Concepts, then gate 3 (labs)

1. Find the concepts the code exercises and the gaps that matter at scale (`reference/concepts.md`). For each:
   where it lives, a one-line ladder sketch (L0 → … → Ln), whether parts would be "proposed", and what a lab needs
   (load, a failure switch, a second instance, a stopped container).
2. **Gate 3**: show that table, then ask (`reference/labs.md`):
   - Which concepts get ladder pages (multi-select).
   - **Do you want labs to scale it?** For all of them / chosen ones / none (pages only).
   - May I add dev-only failure switches (off by default, tested), or only use existing seams?
   - Scale target (today / 10× / 100×) and where load may run (this laptop only, by default).
   If the user doesn't want concept pages at all, skip to Phase 7.

### Phase 6: Ladders, and labs if approved

Build each ladder per `reference/concepts.md`. With labs: per level a run config, a driver command (extend
`lab-kit.mjs` as needed), steps with **Check:**, a failure switch only if approved (with tests), and a real
measurement in `MEASURED.md`, tagged `measured` on the page. Without labs: numbers are `calculated`, `rule` or `model`,
never `measured`. Generate `LABS.md` with `gen-guides.mjs`. Validate, bundle and check after every concept.

### Phase 7: Verify and hand over

1. `validate-data.mjs` 0 errors; `check-explorer.mjs` all views clean; the project's own tests still pass (run
   them if any app code changed, e.g. a failure switch).
2. Stop everything you started; note any data left behind.
3. Update PROGRESS.md and reply to the user, briefly:
   - how to open it (the file path, or the dev URL) and which flow to start with;
   - what's on it (flows, concepts, labs), and the debugger configs added;
   - what was verified and how (breakpoints, measurements), and what wasn't, with the reason;
   - bugs or doc mismatches found (not fixed), each with a repro;
   - anything that needs their decision.

## Rules that keep the result trustworthy

- **Never invent data or numbers.** Captured data comes from a real run; every number has a tag and a source.
  Unsure? It's `calculated` or `rule`, not `measured`.
- **Every breakpoint is verified.** Nested classes, lambdas, async callbacks, cache hits and blank lines silently
  never hit. Prove it, or move it, or say it's unverified.
- **Report bugs, don't fix them.** The labs exist to find out how the system really behaves; the user decides what
  to change.
- **Data, not page code.** Change the data, rebuild, re-check. Never hand-edit `explorer.html` or the engine copy. If
  the engine truly lacks something, add it to the data's `widgets`, or tell the user what the engine needs.
- **Readable beats complete.** 8–30 map boxes, 3–6 boxes per concept scene, labels ≤ 30 characters, step text ≤ 4
  sentences. Split a flow that passes 20 steps.
- **Simple first.** Flow order and ladder order both go from the simplest version to the real one, so each step
  is a small surprise, not a wall.
- **Gates are real.** Ask, wait, record the answer. A "go" for one thing isn't a "go" for the next.
