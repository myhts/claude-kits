# Step-by-step pathways

The page shows the system; the guides make the learner do it. Every guide is a checkbox list where each item is an
action plus a **Check:** (what they should see), with links to the exact code line and to the matching view on the page.
Tick a box when it's been seen happening, not when it's been read.

## The guides

| File | Written by | Contents |
|---|---|---|
| `TOUR.md` | hand | First hour: prerequisites, start the stack, run the app, attach the debugger, follow flow 1 with breakpoints, then flow 2. Ends with "where to go next" |
| `FLOWS.md` | `gen-guides.mjs` | Every flow, step by step: breakpoint, state checks, links. Regenerate after data changes |
| `LABS.md` | `gen-guides.mjs` | Every lab (if approved), plus a self-check list |
| `MEASURED.md` | hand, during labs | Date, machine, command, config, raw output for every `measured` number |
| `PROGRESS.md` | the agent | Phases, decisions at gates, verified breakpoints, bugs found, what's left. Lets a later session resume |

## The depth ladder (put it at the top of TOUR.md)

1. **Run it**: the stack starts, one request succeeds, you can see it in logs/UI.
2. **Follow one request**: flow 1 under the debugger, one thread, every step's breakpoint hit.
3. **Follow the real path**: the async/multi-process flow; see data cross process boundaries.
4. **Break it**: failure flows (bad input, auth, limits, dependency down, duplicate, crash and redelivery).
5. **Why it's built this way**: concept ladders, level by level.
6. **Make it happen**: labs (if approved): cross the thresholds yourself and measure.

## Writing good steps

- One action per checkbox. Commands in backticks, copy-pasteable, from the repo root.
- Every step has a **Check:** with something observable: a status code, a value in the debugger, a row, a log line,
  a number on a dashboard.
- Links: code as `[File.java:42](../../src/…/File.java#L42)` (relative to the guide, so they work in VS Code and on
  GitHub), and the page view as `[open on the page](explorer.html#flow=id&step=3)`.
- Say what to do when it doesn't happen ("no breakpoint hit? the worker isn't running: start `Debug · worker`").
- Plain words. Name the thing, then explain it once.
