---
name: event-storming
description: Event Storming - domain events, aggregates and bounded contexts for event-driven domains, with commands, policies and read models written as Markdown cards and Given/When/Then specs. Use alongside grilling and domain-modeling when a domain has several actors, things that happen over time or background reactions; when settling an aggregate's invariants and outcomes; when drawing bounded contexts or module boundaries; or when auditing docs/eventstorming/.
---

# Event Storming

Event Storming is the **breadboard** rung of the fidelity ladder: domain events, commands, actors, policies, read
models, external systems, aggregates and bounded contexts, settled as a board before any wireframe or prototype.
**The human decides every sticky.** You facilitate: rounds of questions in `grilling`'s format, a recommended answer
for each, and concrete scenarios that test the language the way `domain-modeling` does ("a member returns a copy at
another branch: which event is that, and whose word is 'branch'?").

## When it pays

The domain is **event-driven**: several actors, things that happen over time, or reactions in the background
("whenever a copy is returned, set it aside for the next reservation"). For a CRUD screen, a form over one table with
nothing reacting, the glossary is enough: tell the human, and carry on with grilling alone.

## How it runs inside grilling

`grilling` supplies the rounds and the frontier; `domain-modeling` supplies `GLOSSARY.md` and ADRs, written inline.
This skill supplies the board: what to ask at each level, and where it is written.

- Every event, command, aggregate, policy and read model name is a glossary term. Challenge a clash or an _Avoid_ word
  on the board exactly as you would in conversation.
- Write each board file as its decisions land, the way the glossary is written: create it when its level starts.

**In a `/grill-with-docs` session**, work the steps below in one sitting or across several.

**In Wayfinder**, the map's Destination is the event model, and its Notes say "also call the Skill tool with
`event-storming`". Its grilling tickets follow the steps: one for the big picture, one per flow, one per aggregate
(covering that aggregate's commands) and one for the contexts, beside research and prototype tickets. Flows and
aggregates you can't name yet stay in the fog of war until the big picture reveals them.

## Steps

1. **Check it pays** (above). Done when the human agrees the domain is event-driven, or you have switched to plain
   grilling.
2. **Big picture**, for the whole domain: [LEVELS.md](LEVELS.md#big-picture). Done on that level's criterion.
3. **Process**, one flow at a time, critical path first: [LEVELS.md](LEVELS.md#process-level). Done on its criterion,
   per flow.
4. **Design**, one command at a time: [LEVELS.md](LEVELS.md#design-level). Done on its criterion, per command.
5. **Contexts**: group aggregates and policies into bounded contexts and modules with [CONTEXTS.md](CONTEXTS.md). Done
   on its criterion there.
6. **Audit**: dispatch a fresh subagent with [CHECKLIST.md](CHECKLIST.md) and the file paths, not your summary. Settle
   each finding with the human, fix the board, and dispatch a fresh audit. **The board is done when the audit comes
   back clean.** In Wayfinder, it runs before the map's last ticket closes.

Every file's format, with a worked library board, is in [CARDS.md](CARDS.md).

## Outputs

| File | Holds | Written in |
|---|---|---|
| `docs/eventstorming/01-big-picture.md` | timeline with pivotal events, actors, external systems, hotspot table, critical path | step 2 |
| `docs/eventstorming/02-processes.md` | one section per flow | step 3 |
| `docs/eventstorming/03-design.md` | one card per command with its Given/When/Then specs; the aggregates summary | step 4 |
| `docs/eventstorming/04-contexts.md` | the modules table and the boundary check | step 5 |
| `GLOSSARY.md`, or `GLOSSARY-MAP.md` plus per-context glossaries | the language, through `domain-modeling` | every step, inline |
| `docs/adr/NNNN-slug.md` | decisions that pass `domain-modeling`'s three-part bar | whenever one lands |

## Hand-off

- `/to-spec` cites the model: the cards by name, the ADRs, and the seams the board implies (each card's
  Given/When/Then specs, each projection).
- `/to-tickets` cuts every vertical slice as **one command → its events → its read model**, end to end. The critical
  path is the tracer bullet.
- The spec axis of `code-reviewer` checks the code against these files, so a design change updates the board in the
  same PR.

## How the board maps to code

Technology-neutral. Broker, outbox and framework specifics live in `design-patterns`, `distributed-systems` and the
stack pack named in `docs/agents/stack.md`.

| On the board | In code | What follows |
|---|---|---|
| 🟧 Event catalogue | Versioned event schemas | An event is a contract: add fields and versions, keep old meanings |
| 🟨 Aggregate | The transaction boundary; its id is the ordering and partition key | One writer per aggregate at a time, and its events stay in order |
| 🟦 Command card | A decider: `decide(command, state, info, now)` → events or a rejection; `evolve(state, event)` → state | The card's Given/When/Then rows are its tests at the design seam |
| 🟪 Policy | A consumer with its own subscription | Delivery is at least once, so it must be idempotent |
| 🟩 Read model | A projection | It lags its events, and tolerates replays and out-of-order delivery |
| 🩷 External system | An adapter behind an interface | Timeouts, retries with backoff, and a dead-letter path |
| Bounded context | A module whose boundaries are enforced | Crossed only by published events and published interfaces, checked by the stack card's module-boundary command |
