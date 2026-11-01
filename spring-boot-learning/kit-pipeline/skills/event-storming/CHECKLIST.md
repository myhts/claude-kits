# Board audit

The consistency audit for an Event Storming board. A fresh subagent runs it, with no part in the facilitation, so it
judges the files as written rather than the conversation remembered.

## Dispatch

Send the subagent this prompt with the paths filled in (`<skill>` is this skill's base directory, shown when the skill
loads), and nothing else about the board:

> Audit the Event Storming board in `docs/eventstorming/` (`01-big-picture.md` to `04-contexts.md`), with the glossary
> (`GLOSSARY.md`, or `GLOSSARY-MAP.md` and every glossary it lists) and the ADRs in `docs/adr/`. The file formats are
> in `<skill>/CARDS.md`. Apply every check in `<skill>/CHECKLIST.md` to every item of its kind. Report findings in the
> format the checklist gives; change no files.

## Report

One line per finding, most serious first: the check, the place, what is wrong, and the smallest fix.

```text
<check> · <file> › <card or section> · <what is wrong> · <smallest fix>
C4 · 03-design.md › Card 7: Pay a fine · 🟩 Fines owed lists no feeding events · name the events that feed it
C5 · 01-big-picture.md › Hotspots › H9 · still Open · resolve it on a card, or name the ticket
```

A clean board is one line, with the counts that prove every item was read:

```text
CLEAN · C1–C10 · <n> commands, <n> events, <n> policies, <n> read models, <n> hotspots, <n> contexts
```

The facilitator settles each finding with the human, fixes the board, and dispatches a fresh audit until it comes back
clean.

## Checks

Each check covers every item of its kind; it passes only when every item passes.

- **C1 Commands.** Every 🟦 command has a card with a role (an actor or a policy), a decider (an aggregate, or an
  external system named in the aggregate row) and outcomes: an event on success, and each way of saying no listed as
  a business "no" event or a rejection code. A row with nothing in it says None.
- **C2 Events.** Every 🟧 event has exactly one producer, the decider of one command, is a past-tense fact in glossary
  words, and appears on the big-picture timeline.
- **C3 Policies.** Every 🟪 policy names its trigger (an event, or a ⏰ time trigger shown on the timeline) and the
  command it issues, and is idempotent: it says how the command's id derives from the trigger, so a redelivered trigger
  issues the same command.
- **C4 Read models.** Every 🟩 read model lists the events that feed it, and each of those events has a producer.
- **C5 Hotspots.** Every 🟥 hotspot is resolved, pointing at the card, spec row or ADR that resolves it, or ticketed,
  naming the ticket.
- **C6 Language.** Every name on the board (commands, events, aggregates, policies, read models) uses glossary terms,
  each with one meaning in its context, and the board is free of _Avoid_ words.
- **C7 Aggregates.** Every aggregate is small: its invariants must change together, it decides only commands that
  touch them, and its key exists before it does. Every rule that spans aggregates is named as such in a card's
  hotspots or in an ADR.
- **C8 Boundaries.** Every aggregate and policy sits in exactly one module, and contexts meet only through published
  events or published interfaces: each card reads its own context's state, plus read models fed by other contexts'
  published events. Every relationship in `GLOSSARY-MAP.md` names its kind.
- **C9 Critical path.** The big picture names a critical path, its flow has a section in `02-processes.md`, and the
  command behind every event on it has a card.
- **C10 Specs.** Every card has Given/When/Then rows in CARDS.md's format, covering every outcome, every rejection code
  and a repeat with the same `commandId`. Each Then holds exactly one kind of result, and When carries a time wherever a
  rule depends on it. A policy's card also has rows for its trigger.
