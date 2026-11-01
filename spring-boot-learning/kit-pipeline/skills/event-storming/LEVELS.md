# The three levels

Each level is a run of grilling rounds. A round's questions join the frontier once the round before it is settled.
Draft your recommended answers from the conversation, the glossary, existing docs and code before you ask. The library
examples come from the worked board in [CARDS.md](CARDS.md).

## Big picture

**Unit:** the whole domain, usually one session. **Writes:** `docs/eventstorming/01-big-picture.md`.

1. **Chaotic exploration.** Draft every domain event you can find, then put the list to the human to add, strike and
   rename. An event is a past-tense fact the business would notice, in glossary words: `Copy returned`, not
   `Return handled`. Overlaps and duplicates are welcome here; the timeline sorts them. Ask:
   - What happens before the first event, and after the last?
   - What else would someone in the business notice, count or complain about?
   - Who takes part (🧍 actors), and what do we depend on without owning it (🩷 external systems)?
   - Which moments in time does the business react to (⏰ a daily reminder run, the end of a set-aside period)?
2. **Timeline.** Order the events in time and group them into lanes, one per phase or area. Merge synonyms into one
   event and hand the losing words to the glossary as _Avoid_ words. Ask where the order is uncertain and which lanes
   run in parallel.
3. **Pivotal events.** Mark the few events after which the world is different: a phase ends, ownership passes, the
   language changes. Ask the human to confirm each one. Context boundaries often fall at a pivotal event; note it for
   [CONTEXTS.md](CONTEXTS.md).
4. **Hotspots.** Walk every lane's unhappy paths and number each 🟥: two at once (races), time (late, never,
   expired), repeats (a double tap, a retried request), money, an external system that is slow or down, the wrong
   actor. Each row says where it will be resolved: a card, an ADR, a ticket, or open for now.
5. **Critical path.** Propose the smallest run of events that still delivers value, and the order of everything else.
   Ask: "Is this the smallest flow worth shipping?" It becomes the first process flow and the tracer bullet.

**Done when** `01-big-picture.md` holds the timeline in lanes with pivotal events marked, the actors and external
systems, every hotspot numbered with where it will be resolved, and a critical path and backlog order the human has
confirmed.

## Process level

**Unit:** one flow, critical path first. **Writes:** one section of `docs/eventstorming/02-processes.md`.

Every flow reads left to right in one grammar, repeated:

```text
🧍 Actor ──issues──► 🟦 Command ──decided by──► 🟨 Aggregate or 🩷 System ──produces──► 🟧 Event
                         ▲                        │ reads                                │
                         │                   🟩 Read model                               ▼
                         └───────────── 🟪 Policy ("whenever <event>, <command>") ◄──────┘
```

1. **Causes.** For each event in the flow: which command produced it, or which ⏰ time trigger? Who issues that
   command: an actor, or a policy?
2. **Deciders.** For each command: which aggregate or external system can say no? A working name is enough here; the
   design level sharpens it.
3. **Reactions.** For each event: does anything happen because of it? Write each reaction as a policy, "whenever
   <event>, <command>". Ask whether it is automatic or a person's judgement. A judgement call is an actor working from
   a read model (a to-do list), and the policy becomes that actor's command.
4. **Information.** For each command: what must the issuer see to issue it, and what must the decider know to decide?
   Each answer is a read model; name the events that feed it. Every screen in the flow is a read model too.
5. **Outside.** Which external systems does the flow call or hear from? What happens when one is slow, down, or says
   no?
6. **Hotspots.** Number the new ones in the big picture's table.

**Done when** the flow's section reads left to right with no gap: every event has a command or ⏰ trigger, every
command an issuer and a decider, every policy its trigger and its command, every read model its feeding events, and the
new hotspots are in the table.

## Design level

**Unit:** one command; in Wayfinder, one ticket per aggregate covers its commands. **Writes:** one card in
`docs/eventstorming/03-design.md` and the aggregate's row in its summary.

1. **Decider.** "Who can say no, and based on what?" Name the invariant behind each rule, then choose the smallest
   aggregate that protects it, and its key.
2. **Information.** List what the decision reads: the aggregate's own state, read models, the command's fields, and the
   current time. A decision that needs only the aggregate's own state is a sign the boundary is right.
3. **Outcomes.** The event on success, carrying what downstream needs, so consumers work from the event alone. Then
   every way the answer can be no, sorted by the rules below into business "no" events and rejections, each rejection
   with a code.
4. **Repeats and races.** The same command sent twice; two commands for one aggregate at once; a rule that spans two
   aggregates. Settle each with the rules below.
5. **Next.** The policies the outcome triggers, and the external systems involved, with what happens when they fail.
6. **Specs.** Draft the Given/When/Then rows in CARDS.md's format and put them to the human; "yes" accepts a row.

**The rules of the design level:**

- **A business "no" is an event when someone will read it or react to it later**: refusals counted for a report, a
  decision kept for audit. A refusal nobody will read is a rejection, and so are invalid input and broken rules:
  nothing in the world changed, so the command gets an answer and the history stays as it was.
- **Time is an input.** The decider receives `now` as a parameter. When something reacts to time passing, model a ⏰
  time trigger raised by the scheduler; otherwise the aggregate compares `now` with a stored deadline.
- **Small aggregates.** An aggregate is the smallest set of data that must change together, atomically, to keep its
  invariants true. One aggregate means one writer at a time and one ordering key, so an oversized one becomes a hot
  spot.
- **A rule spanning aggregates** becomes either one bigger aggregate (one writer, less throughput) or eventual
  consistency through a read model, with a way to detect or compensate a breach. Put the choice to the human; it
  usually passes `domain-modeling`'s three-part ADR bar.
- **Keys exist before the aggregate.** The id that orders and partitions a command is known when the command is
  issued: generated at the edge, or derived from ids that already exist.
- **Idempotent by command id.** Every command carries a `commandId`; a repeat returns the original outcome and adds no
  event. A policy derives its command's id from its trigger: the event's id, or for a ⏰ trigger the ids it acts on
  (a loan and a reminder number). A redelivered trigger then issues the same command.
- **An external system can be the decider.** The card names it in the aggregate row, and the event records its answer.

**Done when** every row of the card is filled (None written out where nothing applies), "Why these choices" explains
each choice a newcomer would question, the specs cover every outcome and every rejection code and the human has
accepted them, and the aggregates summary has the aggregate's row.
