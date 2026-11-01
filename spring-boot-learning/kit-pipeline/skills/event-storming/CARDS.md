# Card formats

The Markdown formats for the four board files. Every example comes from one invented board for a library: members
borrow copies of titles, return them, reserve titles with no copy on the shelf, and get reminded when a loan is
overdue. Commands named here without a card (`SetAsideCopy`, `ReleaseCopy`, `CancelReservation`, `CloseReservation`,
`SendCollectionNotice`), the flow of the Set-aside expiry policy, and the commands of Catalogue and Membership belong
to the same board but are left out to keep this file short; a real board cards every command.

## Legend

Each board file opens with the one-line legend:

```markdown
Legend: 🧍 Role · 🟦 Command · 🟩 Read model · 🟨 Aggregate · 🟧 Event · 🟥 Rejection or hotspot · 🟪 Policy · 🩷 External system · ⏰ Time trigger
```

| Sticky | Grammar | Library example |
|---|---|---|
| 🟧 Domain event | Past tense, business words. Sentence case on the timeline, a type name on cards | `Copy returned` / `CopyReturned` |
| 🟦 Command | Imperative: a request that can be refused | `BorrowCopy` |
| 🧍 Role | Who issues a command: a person, or a machine through an API | Member, Librarian |
| 🟨 Aggregate | A noun that accepts or rejects commands to keep its invariants true | Copy |
| 🟪 Policy | "Whenever <event>, <command>" | Whenever `CopyReturned`, `SetAsideCopy` |
| 🟩 Read model | What an actor needs to see, or a decider needs to know | Member standing |
| 🩷 External system | Something we use but don't own | Email provider |
| ⏰ Time trigger | A moment the business reacts to, raised by the scheduler | ⏰ Daily reminder run |
| 🟥 Hotspot or rejection | A risk, an open question, or a broken rule | H1: two members, one copy |

## 01-big-picture.md

Actors and external systems on one line, the timeline in lanes with ★ on pivotal events, the critical path with the
backlog order, then the hotspot table. Hotspots are numbered here, once; cards and flows refer to them by number.

````markdown
# 01: Big picture

Actors: 🧍 Member · 🧍 Librarian · 🧍 Membership officer. External systems: 🩷 Email provider.

## Timeline (order = time; ★ = pivotal)

```text
CATALOGUE     Title added ─► Copy added ─► Copy withdrawn

MEMBERSHIP    Member joined ─► Member suspended ─► Member reinstated

LENDING       ★ Copy borrowed ──────────────► ★ Copy returned
              Borrow refused                    (a business "no", counted by reason)
              ⏰ Daily reminder run ─► Overdue reminder sent         (per loan past due: weekly, up to 3)

RESERVATIONS  Title reserved ─► ★ Copy set aside ─► Collection notice sent ─► Copy borrowed ─► Reservation closed
                                                   └─► ⏰ Set-aside period ended ─► Copy released ─► Reservation closed
              Reservation cancelled
```

## Critical path

```text
Copy borrowed ─► Copy returned
```

Backlog, in order: overdue reminders → reservations → suspensions → branch transfers.

## Hotspots

| # | Hotspot | Where it's resolved |
|---|---|---|
| H1 | Two members borrow the last copy at the same instant | Resolved: Card 1, Borrow a copy |
| H2 | A copy is returned at a different branch from its own | Ticketed: "Copy transfer between branches" |
| H3 | Member standing lags: can a member at 2 loans reach 4 with two borrows in one second, or a member suspended a moment ago still borrow? | Resolved: Card 1, and ADR 0001 |
| H4 | A reminder goes out for a copy returned that morning | Resolved: Card 4, Send an overdue reminder |
| H5 | A member reserves a title while a copy sits on the shelf | Resolved: Card 3, Reserve a title |
| H6 | Should the third reminder suspend the member automatically? | Ticketed: "Suspend after repeated overdue reminders" |
| H7 | A double tap or a retried request sends a command twice | Resolved: `commandId` on every card |
````

While a level is in progress, "Open" is a valid entry in the last column; the audit requires every row resolved or
ticketed.

## 02-processes.md

One `##` section per flow: the chain, one line per step, each line starting from the trigger of the step before; then
the policies and read models the flow uses, and its new hotspots.

````markdown
## Flow: Return a copy

```text
🧍 Librarian ─► 🟦 ReturnCopy ─► 🟨 Copy ─► 🟧 CopyReturned
🟧 CopyReturned ─► 🟪 Set-aside policy ─► 🟦 SetAsideCopy ─► 🟨 Copy ─► 🟧 CopySetAside
🟧 CopySetAside ─► 🟪 Collection-notice policy ─► 🟦 SendCollectionNotice ─► 🩷 Email provider ─► 🟧 CollectionNoticeSent
```

| 🟪 Policy | Whenever | Then | Command id from |
|---|---|---|---|
| Set-aside | `CopyReturned` or `CopyReleased`, and 🟩 Waiting reservations has a member for the title | `SetAsideCopy` for the member waiting longest | the trigger event's id |
| Collection-notice | `CopySetAside` | `SendCollectionNotice` to that member | the trigger event's id |

| 🟩 Read model | Used by | Fed by |
|---|---|---|
| Copies on loan, by member | 🧍 Librarian's return screen | `CopyBorrowed`, `CopyReturned` |
| Waiting reservations, by title, oldest first | 🟪 Set-aside policy | `TitleReserved`, `ReservationCancelled`, `CopySetAside` |

New hotspots: H2.
````

## 03-design.md

One card per command, each a `##` heading, followed by the aggregates summary.

### The command card

````markdown
## Card N: <the command in plain words>

| | |
|---|---|
| 🧍 **Role** | The actor who issues it, or 🟪 **<Name> policy** (automated): "whenever <trigger>, <what it does>" |
| 🟦 **Command** | `CommandName { commandId, <key>, <fields> }`, and where each id comes from |
| 🟩 **Info needed to decide** | The aggregate's own state · each 🟩 read model, with the events that feed it · `now`, when a rule depends on time |
| 🟨 **Aggregate** | **Name**, keyed by `<id>`; or "None: decided by 🩷 <system>" |
| 🟧 **Event on success** | `EventName { <what downstream needs> }` |
| 🟧 **Event on a business "no"** | `EventName { reason }` with each reason code, or None |
| 🟥 **Rejections (no event)** | Invalid shape → refused at the edge · `CODE` (when) · same `commandId` → the original outcome |
| 🟪 **Policy triggered next** | Whenever `Event` → `NextCommand`, or None |
| 🩷 **External systems** | Each system, what we ask of it, and what happens when it fails; or None |
| 🟥 **Hotspots** | **Hn resolved:** how · **Hn ticketed:** the ticket's name |

**Why these choices:**

- One bullet per choice a newcomer would question.

**Specs:**

| # | Given | When | Then |
|---|---|---|---|
````

### Given/When/Then specs

Every card ends with its decider specs, one row per case:

- **Given**: the past events that matter to the case, oldest first; then, after a 🟩, the read-model facts the decision
  reads. `(none)` for an aggregate that doesn't exist yet.
- **When**: one command, or for a policy its trigger, with the time whenever a rule depends on it.
- **Then**: exactly one of: the new events; one rejection, written `✗ CODE`; `↺ the original outcome` for a repeat
  with the same `commandId`; for a policy, the command it issues, or `nothing` when it stays quiet.
- **Coverage**: one row per outcome, one per rejection code, and one repeat with the same `commandId`. Ids are short
  and invented (`C7`, `L1`, member `A`).

Each row becomes one test at the design seam: call the decider with Given and When, and compare its result with Then.
`tdd` covers how to write them.

### Card 1: Borrow a copy

| | |
|---|---|
| 🧍 **Role** | **Member** (in the app, collecting at the desk) or **Librarian** (at the desk, for a member) |
| 🟦 **Command** | `BorrowCopy { commandId, loanId, copyId, memberId }`. `loanId` is generated at the edge; the key, `copyId`, exists from the moment the copy was added |
| 🟩 **Info needed to decide** | The **Copy's own state**: on the shelf, on loan, or set aside for a member · 🟩 **Member standing** (active or suspended; open loans), fed by `MemberJoined`, `MemberSuspended`, `MemberReinstated`, `CopyBorrowed`, `CopyReturned` · `now`, for the due date |
| 🟨 **Aggregate** | **Copy**, keyed by `copyId` |
| 🟧 **Event on success** | `CopyBorrowed { loanId, copyId, titleId, memberId, borrowedAt, dueOn }`, with `dueOn` 14 days after `borrowedAt` |
| 🟧 **Event on a business "no"** | `BorrowRefused { copyId, memberId, reason }`, reason one of `LOAN_LIMIT_REACHED` (3 open loans), `MEMBER_SUSPENDED` |
| 🟥 **Rejections (no event)** | Invalid shape → refused at the edge, nothing recorded · `COPY_NOT_FOUND` · `COPY_NOT_AVAILABLE` (on loan, or set aside for another member) · same `commandId` → the original outcome (H7) |
| 🟪 **Policy triggered next** | 🟪 **Reservation-closing policy:** whenever `CopyBorrowed` → `CloseReservation` (collected) for that `titleId` and `memberId`, if one is open; the command id comes from the event's id. ⏰ The overdue-reminder policy finds the loan later, through 🟩 Overdue loans |
| 🩷 **External systems** | None |
| 🟥 **Hotspots** | **H1 resolved:** both commands carry `copyId`, so the Copy decides them one at a time; the first wins and the second gets `COPY_NOT_AVAILABLE`. An optimistic version check on save is the backstop. · **H3 resolved:** standing comes from a read model, so a member at 2 loans who borrows two copies in the same second can reach 4, and a member suspended a moment ago can still borrow. The library accepts both, since staff see them at collection; ADR 0001 records why Copy, not Member, decides a borrow |

**Why these choices:**

- **`BorrowRefused` is an event; `COPY_NOT_AVAILABLE` is a rejection.** The library reviews refusals by reason each
  term ("is three loans the right limit?"), so a refusal is a fact worth keeping. A copy that is already out leaves
  nothing to count: the member picks another copy.
- **Copy is the aggregate, not Member.** The rule that must never break is one borrower per copy. Member as the
  aggregate would protect the loan limit exactly but let two members take the same copy. The loan limit is the softer
  rule, so it is read from a read model.
- **`loanId` is generated at the edge**, so the loan, its reminders and its return share one id from the first moment.

**Specs:**

| # | Given | When | Then |
|---|---|---|---|
| BC1 | `CopyAdded(C7)` · 🟩 A: active, 0 loans | `BorrowCopy(L1, C7, A)` at 1 Mar | `CopyBorrowed(L1, C7, A, due 15 Mar)` |
| BC2 | `CopyBorrowed(L1, C7, A)` | `BorrowCopy(L2, C7, B)` | ✗ `COPY_NOT_AVAILABLE` |
| BC3 | `CopyAdded(C7)` · 🟩 B: active, 3 loans | `BorrowCopy(L2, C7, B)` | `BorrowRefused(C7, B, LOAN_LIMIT_REACHED)` |
| BC4 | `CopyAdded(C7)` · 🟩 B: suspended | `BorrowCopy(L2, C7, B)` | `BorrowRefused(C7, B, MEMBER_SUSPENDED)` |
| BC5 | `CopySetAside(C7, for A, until 7 Mar)` | `BorrowCopy(L2, C7, B)` at 5 Mar | ✗ `COPY_NOT_AVAILABLE` |
| BC6 | `CopySetAside(C7, for A, until 7 Mar)` · 🟩 A: active, 1 loan | `BorrowCopy(L3, C7, A)` at 5 Mar | `CopyBorrowed(L3, C7, A, due 19 Mar)` |
| BC7 | `CopyBorrowed(L1, C7, A)` from command K1 | `BorrowCopy(L1, C7, A)` again as K1 | ↺ the original outcome |
| BC8 | (none) | `BorrowCopy(L1, C9, A)` | ✗ `COPY_NOT_FOUND` |

### Card 2: Return a copy

| | |
|---|---|
| 🧍 **Role** | **Librarian** (scanning at the desk) or **Member** (at a returns kiosk) |
| 🟦 **Command** | `ReturnCopy { commandId, copyId, branchId }` |
| 🟩 **Info needed to decide** | Only the **Copy's own state** (its open loan and due date) and `now`. No outside read model, a sign the boundary is right |
| 🟨 **Aggregate** | **Copy**, keyed by `copyId` |
| 🟧 **Event on success** | `CopyReturned { loanId, copyId, titleId, memberId, branchId, returnedAt, dueOn }` |
| 🟧 **Event on a business "no"** | None |
| 🟥 **Rejections (no event)** | Invalid shape → refused at the edge · `COPY_NOT_FOUND` · `COPY_NOT_ON_LOAN` (scanned twice, or never borrowed) · same `commandId` → the original outcome |
| 🟪 **Policy triggered next** | 🟪 **Set-aside policy:** whenever `CopyReturned` and 🟩 Waiting reservations has a member for the title → `SetAsideCopy` (see the Return a copy flow) |
| 🩷 **External systems** | None |
| 🟥 **Hotspots** | **H2 ticketed:** "Copy transfer between branches". v1 records `branchId` on the event, so that flow can start from it later |

**Why these choices:**

- **A late return is the same event.** `returnedAt` and `dueOn` both travel on `CopyReturned`, so anything that cares
  about lateness later (fines, say) works it out from them. Nothing reacts to lateness on its own in v1.
- **`COPY_NOT_ON_LOAN` is a rejection.** A second scan changes nothing in the world; the desk shows "already returned".
- **`memberId` and `titleId` travel on the event**, so the set-aside policy and the reminders work from the event
  alone.

**Specs:**

| # | Given | When | Then |
|---|---|---|---|
| RC1 | `CopyBorrowed(L1, C7, A, due 15 Mar)` | `ReturnCopy(C7, North)` at 10 Mar | `CopyReturned(L1, C7, A, North, 10 Mar, due 15 Mar)` |
| RC2 | `CopyBorrowed(L1, C7, A, due 15 Mar)` | `ReturnCopy(C7, North)` at 20 Mar | `CopyReturned(L1, C7, A, North, 20 Mar, due 15 Mar)` |
| RC3 | `CopyBorrowed(L1, C7, A)`, `CopyReturned(L1, C7, A)` | `ReturnCopy(C7, North)` as a new command | ✗ `COPY_NOT_ON_LOAN` |
| RC4 | `CopyBorrowed(L1, C7, A)`, `CopyReturned(L1, C7, A)` from command K2 | `ReturnCopy(C7, North)` again as K2 | ↺ the original outcome |
| RC5 | (none) | `ReturnCopy(C9, North)` | ✗ `COPY_NOT_FOUND` |

### Card 3: Reserve a title

| | |
|---|---|
| 🧍 **Role** | **Member** (in the app) |
| 🟦 **Command** | `ReserveTitle { commandId, titleId, memberId }` |
| 🟩 **Info needed to decide** | The **Reservation's own state** (is this member's reservation of this title open?) · 🟩 **Title availability** (copies on the shelf now), fed by `CopyAdded`, `CopyWithdrawn`, `CopyBorrowed`, `CopyReturned`, `CopySetAside`, `CopyReleased` · 🟩 **Member standing**, as in Card 1 |
| 🟨 **Aggregate** | **Reservation**, keyed by (`titleId`, `memberId`). A member's later reservation of the same title reuses the key once the earlier one has closed |
| 🟧 **Event on success** | `TitleReserved { titleId, memberId, reservedAt }` |
| 🟧 **Event on a business "no"** | None |
| 🟥 **Rejections (no event)** | Invalid shape → refused at the edge · `ALREADY_RESERVED` (this member's reservation of this title is open) · `COPY_AVAILABLE` (a copy is on the shelf: borrow it) · `MEMBER_SUSPENDED` · same `commandId` → the original outcome |
| 🟪 **Policy triggered next** | None. The set-aside policy acts later, on `CopyReturned` |
| 🩷 **External systems** | None |
| 🟥 **Hotspots** | **H5 resolved:** `COPY_AVAILABLE` sends the member to borrow instead. Availability is a read model, so a copy can reach the shelf just after the check; the reservation then waits for the next return. Accepted for v1. · **H3** applies here too: standing comes from the same read model |

**Why these choices:**

- **No business "no" event.** A refused reservation leaves the world unchanged and nobody counts them, so every
  refusal is a rejection. Compare Borrow a copy, where refusals are counted.
- **The key is (`titleId`, `memberId`).** It exists before the reservation does, and it makes "one open reservation per
  member per title" true by construction: a second `ReserveTitle` lands on the same aggregate.
- **Queue order is not an invariant.** `reservedAt` orders 🟩 Waiting reservations, and the set-aside policy reads the
  oldest. A queue aggregate per title would push every reservation for a bestseller through one writer.

**Specs:**

| # | Given | When | Then |
|---|---|---|---|
| RT1 | (none) · 🟩 T1: none on the shelf · 🟩 A: active | `ReserveTitle(T1, A)` at 2 Mar | `TitleReserved(T1, A, 2 Mar)` |
| RT2 | `TitleReserved(T1, A)` | `ReserveTitle(T1, A)` as a new command | ✗ `ALREADY_RESERVED` |
| RT3 | (none) · 🟩 T1: 1 on the shelf | `ReserveTitle(T1, A)` | ✗ `COPY_AVAILABLE` |
| RT4 | (none) · 🟩 A: suspended | `ReserveTitle(T1, A)` | ✗ `MEMBER_SUSPENDED` |
| RT5 | `TitleReserved(T1, A)`, `ReservationClosed(T1, A, collected)` · 🟩 T1: none on the shelf | `ReserveTitle(T1, A)` at 1 Apr | `TitleReserved(T1, A, 1 Apr)` |
| RT6 | `TitleReserved(T1, A)` from command K3 | `ReserveTitle(T1, A)` again as K3 | ↺ the original outcome |

### Card 4: Send an overdue reminder

| | |
|---|---|
| 🧍 **Role** | 🟪 **Overdue-reminder policy** (automated): whenever ⏰ the daily reminder run finds a loan past due with the copy still out, remind the member; again every 7 days, up to 3 reminders |
| 🟦 **Command** | `SendOverdueReminder { commandId, loanId, memberId, reminderNo }`. A ⏰ trigger has no id of its own, so `commandId` is derived from (`loanId`, `reminderNo`), and a re-run of the daily reminder run issues the same command |
| 🟩 **Info needed to decide** | 🟩 **Overdue loans** (loans past due and still out, with the reminders sent), fed by `CopyBorrowed`, `CopyReturned`, `OverdueReminderSent` · the member's email and name, from Membership's published interface · `now` |
| 🟨 **Aggregate** | None: the Notifications module re-reads 🟩 Overdue loans, then 🩷 **Email provider** decides the send, through the module's adapter |
| 🟧 **Event on success** | `OverdueReminderSent { loanId, memberId, reminderNo, sentAt }`, recorded when the provider accepts the message |
| 🟧 **Event on a business "no"** | None |
| 🟥 **Rejections (no event)** | `NO_LONGER_OVERDUE` (the loan has left 🟩 Overdue loans when re-read just before sending; H4) · same `commandId` → the original outcome |
| 🟪 **Policy triggered next** | None in v1 (H6) |
| 🩷 **External systems** | **Email provider**: a timeout on every call, retries with jittered backoff, then the dead-letter path |
| 🟥 **Hotspots** | **H4 resolved:** the read model lags returns by seconds, so a reminder can cross a return made just before the daily run. Re-reading 🟩 Overdue loans just before each send narrows the window, and the wording covers the rest ("if you've already returned it, thank you"). · **H6 ticketed:** "Suspend after repeated overdue reminders" |

**Why these choices:**

- **The trigger is time.** Nothing happens in Lending when a due date passes, so there is no event to react to. The
  scheduler raises ⏰ Daily reminder run at 08:00, and the policy scans 🟩 Overdue loans.
- **No aggregate.** The only rule is "never the same reminder twice", and the derived `commandId` makes that
  structural. An aggregate would add a writer and a table that protect nothing.
- **Reminders live in Notifications, not Lending.** They need only what Lending's events carry, and their wording
  changes far more often than the lending rules.

**Specs:**

| # | Given | When | Then |
|---|---|---|---|
| OR1 | `CopyBorrowed(L1, C7, A, due 15 Mar)` | ⏰ Daily reminder run, 16 Mar 08:00 | `SendOverdueReminder(L1, A, no. 1)` |
| OR2 | `CopyBorrowed(L1, C7, A, due 15 Mar)`, `CopyReturned(L1, 15 Mar)` | ⏰ Daily reminder run, 16 Mar 08:00 | nothing |
| OR3 | `CopyBorrowed(L1, C7, A, due 15 Mar)`, `OverdueReminderSent(L1, no. 1, 16 Mar)` | ⏰ Daily reminder run, 17 Mar 08:00 | nothing (the next is due 23 Mar) |
| OR4 | `CopyBorrowed(L1, C7, A, due 15 Mar)`, `OverdueReminderSent(L1, no. 1, 16 Mar)` | ⏰ Daily reminder run, 23 Mar 08:00 | `SendOverdueReminder(L1, A, no. 2)` |
| OR5 | `CopyBorrowed(L1, C7, A, due 15 Mar)`, reminders no. 1–3 sent by 30 Mar | ⏰ Daily reminder run, 6 Apr 08:00 | nothing (staff take over; H6) |
| OR6 | (none) · 🟩 Overdue loans: L1 overdue | `SendOverdueReminder(L1, A, no. 1)` at 16 Mar 08:01, provider accepts | `OverdueReminderSent(L1, A, no. 1, 16 Mar 08:01)` |
| OR7 | `OverdueReminderSent(L1, A, no. 1)` | `SendOverdueReminder(L1, A, no. 1)` again, same `commandId` | ↺ the original outcome |
| OR8 | (none) · 🟩 Overdue loans: L1 gone (returned 16 Mar 07:59) | `SendOverdueReminder(L1, A, no. 1)` at 16 Mar 08:01 | ✗ `NO_LONGER_OVERDUE` |

### Aggregates summary

| Aggregate | Key | Commands it decides | Invariants it protects |
|---|---|---|---|
| **Copy** | `copyId` | BorrowCopy, ReturnCopy, SetAsideCopy, ReleaseCopy | One state at a time: on the shelf, on loan to one member, or set aside for one member · a loan ends at most once |
| **Reservation** | (`titleId`, `memberId`) | ReserveTitle, CancelReservation, CloseReservation | At most one open reservation per member per title · an open reservation closes once: collected, expired or cancelled |

## 04-contexts.md

The modules table, then the boundary check and a pointer to the relationships; the method is in
[CONTEXTS.md](CONTEXTS.md).

```markdown
# 04: Contexts

| Module | Aggregates | Policies | Publishes | Why grouped |
|---|---|---|---|---|
| **catalogue** | Title (cards not shown) | none | `CopyAdded`, `CopyWithdrawn` | Changes with every acquisition, on its own lifecycle, owned by the catalogue team |
| **membership** | Member (cards not shown) | none | `MemberJoined`, `MemberSuspended`, `MemberReinstated`; the member-contact interface | Owned by the membership office; others need only a member's standing and contact details |
| **lending** | Copy, Reservation | Set-aside, Set-aside expiry, Reservation-closing | `CopyBorrowed`, `CopyReturned`, `CopySetAside` | Borrowing, returning and setting aside all decide on the Copy's state; reserving needs copy availability |
| **notifications** | none: policies and projections only | Overdue-reminder, Collection-notice | nothing yet | Needs only what Lending's events carry; its wording changes far more often than lending rules; owns the adapter in front of 🩷 Email provider |

Boundary check: the module-boundary command in `docs/agents/stack.md`, run in CI.
Relationships between the modules: [GLOSSARY-MAP.md](../../GLOSSARY-MAP.md).
```
