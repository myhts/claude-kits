# Bounded contexts

Settle contexts after the design level, once you know which aggregate decides what. Candidate boundaries surface
earlier, at pivotal events and wherever a lane's language changes; this step confirms them. **Writes:**
`docs/eventstorming/04-contexts.md` (format in [CARDS.md](CARDS.md#04-contextsmd)), and through `domain-modeling`
either one `GLOSSARY.md` or `GLOSSARY-MAP.md` plus a glossary per context.

One context is a fine answer: one glossary, one module, no map.

## Finding them

| Signal | Ask | Library example |
|---|---|---|
| **The language changes** | Does this word mean the same thing on both sides? | "Copy" in Catalogue is an item with a barcode, shelf mark and condition; in Lending it is on the shelf, on loan or set aside |
| **Different owners** | Who decides these rules? Who do you call when they're wrong? | The catalogue team, the membership office, the circulation desk |
| **Different rates of change** | How often do these rules change, and for what reason? | Reminder wording changes each term; loan rules about once a year |
| **What a decision needs** | Does deciding B need A's current state, or only what A's events carry? | Return and set-aside both decide on the Copy's state, so both sit in Lending; reminders need only Lending's events, so Notifications can sit apart |

The last signal is the strongest. Group "command A → event A → state A is needed to decide command B" into one
context. Where B needs only what A's events carry, the two can live apart, joined by an event.

## Rounds

1. **Candidates.** Draft the modules table with your recommended boundaries: every aggregate and policy placed, with a
   "why grouped" line from the signals above. Put it to the human.
2. **Language.** For each term used in more than one candidate context, ask whether it means the same thing. If not:
   inside one team's language, prefix it first ("overdue reminder" and "collection notice", rather than two meanings of
   "notice"); when owners and languages differ, split the glossary.
3. **Relationships.** For each pair of contexts that talk: which is upstream, and what crosses (the kinds below)?
4. **Modules.** Confirm one module per context, and name the module-boundary check from `docs/agents/stack.md`.

**Done when** `04-contexts.md` places every aggregate and policy in exactly one module, every term clash is prefixed
or split, every relationship is in `GLOSSARY-MAP.md` with its kind, and the boundary check is named.

## Relationships, kept simple

| Kind | Means | Use when | Library example |
|---|---|---|---|
| **Upstream → downstream** | Upstream's changes reach downstream, never the other way | Every relationship: always name the direction | Catalogue → Lending |
| **Published events** | Upstream publishes events in its own language as a contract; downstream subscribes and keeps its own copy of what it needs | The default between contexts | Lending publishes `CopyReturned`; Notifications builds 🟩 Overdue loans from it |
| **Published interface** | Upstream offers a small query or command API that downstream calls | Downstream needs a current answer at the moment it acts | Notifications asks Membership for a member's contact details as it sends |
| **Anti-corruption layer** | Downstream translates a model it doesn't control into its own words, at the boundary | External systems, legacy systems, any model you'd rather not adopt | Notifications' adapter keeps the email provider's message format out of its own language |

Contexts share ids (`copyId`, `memberId`, `titleId`) and nothing else.

## Glossaries

The format is `domain-modeling`'s own, from its [GLOSSARY-FORMAT.md](../../upstream/domain-modeling/GLOSSARY-FORMAT.md). A split gives each context its own
`GLOSSARY.md` in its module folder, and `GLOSSARY-MAP.md` at the root lists the contexts and records the
relationships, naming each one's kind. `04-contexts.md` links to the map rather than repeating it.

```markdown
# Glossary Map

## Contexts

- [Catalogue](./src/catalogue/GLOSSARY.md): titles and the copies the library owns
- [Membership](./src/membership/GLOSSARY.md): members, their contact details and standing
- [Lending](./src/lending/GLOSSARY.md): loans, returns and reservations
- [Notifications](./src/notifications/GLOSSARY.md): reminders and notices sent to members

## Relationships

- **Catalogue → Lending** (published events): Catalogue emits `CopyAdded` and `CopyWithdrawn`; Lending keeps its own Copy
- **Membership → Lending** (published events): Membership emits `MemberJoined`, `MemberSuspended` and `MemberReinstated`; Lending keeps each member's standing
- **Lending → Notifications** (published events): Lending emits `CopyBorrowed`, `CopyReturned` and `CopySetAside`; Notifications sends reminders and collection notices
- **Membership → Notifications** (published interface): Notifications asks for a member's contact details when it sends
- **Email provider → Notifications** (anti-corruption layer): the provider's message format stays inside Notifications' adapter
```

The same word, two models, so two glossaries. Lending's opens like this (paths follow the stack's module layout):

```markdown
# Lending

Lends copies to members, takes them back, and keeps reservations for titles with no copy on the shelf.

## Language

**Copy**:
One physical item of a title, as lending sees it: on the shelf, on loan, or set aside.
_Avoid_: book, volume

**Reservation**:
A member's request for the next copy of a title that comes back.
_Avoid_: hold, booking

**Set aside**:
Kept back for three days for the member whose reservation a returned copy fills.
_Avoid_: on hold, held
```

## Modules

- **Start as a modular monolith**: one deployable, one module per context.
- **Each module owns its aggregates and tables.** Others reach it through its published events and published
  interfaces only.
- **A check enforces the boundary**: the module-boundary command in `docs/agents/stack.md` (Spring Modulith or
  ArchUnit; dependency-cruiser), run in CI, so a breach fails the build.
- **A module becomes a service** when the numbers or team ownership call for it. Its published events move onto a
  broker and its published interface becomes an API; the board stays the same. Record the trigger for splitting in an
  ADR.
