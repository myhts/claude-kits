# The bar for Diagnose and Fix

One honest limit: a short round can't test everything. The best practice, and what interviewers mark, is to rank cases
by risk, test the ones that matter, and say aloud which you skipped.

The method comes from the pipeline's skills: `pipeline:diagnosing-bugs` (a tight feedback loop first), `pipeline:tdd`
(tests at agreed seams; when to mock), `pipeline:codebase-design` (seams, deep modules, design it twice) and
`pipeline:design-patterns` (start from the problem, not the pattern).

## Diagnose

### 1. Prove the cause

Up to three suspects, each with the one check that rules it out: a line to read, a log line, a debugger stop, a
narrower test, or `git log -p` / `git bisect` on the file. The human runs the checks, cheapest first. A cause counts
when code the human has read, or a narrower test, shows it.

In a Build round this step is **where the slice goes**: two or three placements, each with the seam it's tested at.

### 2. Map the edges

Start from the inputs of the code that holds the cause, and walk this list. Propose at most eight cases:

- **Boundaries:** 0, 1, the limit, one past it; empty and missing.
- **Repeats:** the same call twice, and two at once. Always include these where state is shared.
- **Dependencies:** each one failing with an error, a timeout, or a half-done change.
- **Time and money,** where they appear: time zones, month end, rounding, currency.
- **Permission:** someone else's record, or a missing right.

Each case gets:

- **input → expected:** the expected result comes from the brief or the interviewer, never from the code, or the test
  only confirms the bug;
- **risk:** high or low;
- **where it's tested:** `unit`, or `db` when only a real database can show it.

When nobody knows the expected result, the case becomes a question for the interviewer. Name what you skip and why.

```text
Step 3 of 6 · Diagnose · until 14:35
Cause: check-then-act in pay() (service.ts:34–39), shown by the red test.
Edges (OK, or CHANGE):
  unit 1 two pays at once → one charge                    high  red today: the bug
  unit 2 pay a paid order → 409, no charge                high
  unit 3 gateway fails → order back to UNPAID, retryable  high
  unit 4 unknown order → 404                              low   green today
  db   5 two pays race in Postgres → one PAYING row       high  Testcontainers, background
Skipped, say so: refunds (out of scope), currency (not on this path).
```

### 3. Lay the tests out properly

- The name says the behaviour: "charges once when two payments arrive together".
- One behaviour per test, with arrange, act and assert visibly apart.
- Edge cases go in one table (`it.each`, `@ParameterizedTest`), so the table reads as the spec.
- Fakes only at the edges, such as a payment gateway. Never mock the code's own classes.
- Deterministic: the clock injected, no sleeps (wait for a condition), each test owns its data.
- Fast and slow kept apart: unit tests in the normal suite; database tests in their own files (`*.int.test.ts`, or
  `*IT` in Java), so the quick loop stays at seconds.
- The repo's own test style wins over these rules.

After the human's `OK`, run them. A red case is a bug. A green one documents today's behaviour; label it.

### 4. Database cases in the background

What only a real database shows becomes an integration test with Testcontainers: atomic updates, constraints,
transactions, real SQL. After the human's `OK`, a background agent writes and runs it while the round moves on. It
writes only that test file, and reports pass or fail as a card.

- **Docker first:** `docker info` must answer. Without Docker, write the test, mark it as not run, and say what it
  would prove.
- **Pull the image before the round.** A first pull can take longer than the start timeout. This was seen when the
  snippet below was checked: the first run failed while `postgres:16-alpine` downloaded, and the second passed in 8.5
  seconds.
- **Cap every container's memory.** Postgres gets 256 MB.
- One container per test file, started once; Testcontainers removes it afterwards.

**TypeScript** (checked 2026-11-12: Node 24, Vitest 5.1, `@testcontainers/postgresql` 12.2.1, `pg` 8.23; the cap was
read back from `docker inspect` as 256 MB):

```ts
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import pg from 'pg';
import { afterAll, beforeAll, expect, it } from 'vitest';

let db: StartedPostgreSqlContainer;
let pool: pg.Pool;

beforeAll(async () => {
  db = await new PostgreSqlContainer('postgres:16-alpine')
    .withResourcesQuota({ memory: 0.25 })          // 256 MB: a cap on every container
    .start();
  pool = new pg.Pool({ connectionString: db.getConnectionUri(), max: 4 });
  await pool.query(`create table orders (id int primary key, status text not null)`);
}, 60_000);

afterAll(async () => {
  await pool?.end();
  await db?.stop();
});

const claimForPayment = async (id: number) =>
  (await pool.query(`update orders set status = 'PAYING' where id = $1 and status = 'UNPAID'`, [id])).rowCount === 1;

it('lets only one of two simultaneous payments claim the order', async () => {
  await pool.query(`insert into orders values (1, 'UNPAID')`);

  const claims = await Promise.all([claimForPayment(1), claimForPayment(1)]);

  expect(claims.filter(Boolean)).toHaveLength(1);
  expect((await pool.query(`select status from orders where id = 1`)).rows[0].status).toBe('PAYING');
});
```

In a real repo the test uses the repo's own repository class and migrations, not a hand-made table.

**Java:** follow the `testing-patterns` skill in the spring pack (Testcontainers 2 with `@ServiceConnection`). The
memory cap isn't checked in the kit for Java yet, so read it back once with
`docker inspect -f '{{.HostConfig.Memory}}' <container>`.

## Fix

### 1. Options before code

Two or three options, the smallest first. Each says:

- where the change lives;
- the pattern, if any, and the problem it solves;
- what it costs;
- roughly how many lines.

"No pattern" is a real option, and often the best one. The human chooses and says the trade-off aloud.

```text
Step 4 of 6 · Fix · until 14:45
Options (you choose):
  a claim the order atomically: UPDATE … SET status='PAYING' WHERE id=? AND status='UNPAID'   ~10 lines
  b a lock in memory: passes the test, breaks with two instances                           ~6 lines
  c an idempotency key to the gateway: stops the double charge there, not the double work  ~25 lines
```

### 2. The human writes the core rule

`MINE`: the rule that fixes the cause is theirs. Claude wires it in and reviews it against this bar.

### 3. Prefactor if needed

If the code makes the fix awkward, first make the fix easy, as its own commit, green before and after. Then make the
easy fix.

### 4. The bar

- At the cause, not the symptom.
- In the right layer: the handler parses, the service decides, the repository stores, the gateway talks out.
  Dependencies point inward.
- The repo's conventions over our taste: naming, errors, folders.
- Names from the domain. One job per function, about 20 lines at most. Early returns. Comments say why.
- No error swallowed. Nothing speculative: no interface with one implementation unless it's a seam for tests.
- Small: about 40 changed lines outside tests. Over that, stop and choose again, or split.

### 5. A pattern only for a named problem

If you can't name both the problem it solves and what it costs, leave it out.

| Problem | Pattern | Cost |
|---|---|---|
| two requests race on the same row | an atomic conditional update, or a version column (optimistic lock) | a retry path for the loser |
| a client retries | an idempotency key | a table of seen keys |
| a side effect must follow a commit | a transactional outbox | a relay, and delivery at least once |
| a rule varies by type or customer | a strategy | one more interface |
| storage details leak into the logic | a repository method with a domain name | usually none |

### 6. Checks: facts from Claude, judgements from the human

**Facts,** which Claude runs and reports as they are:

- the Diagnose tests pass;
- the whole unit suite passes;
- lint and types pass;
- the database test result, or "running";
- `git diff` on the test files shows no existing test edited, skipped or loosened;
- changed lines against the budget.

**Judgements,** which Claude asks and never marks ✓: is it in the right layer? Does it read top to bottom? Does the
pattern earn its place? A fresh reader checks the same in Review.

```text
Step 4 of 6 · Fix · until 14:45
Done: OrderRepository.claimForPayment (yours, 6 lines); pay() uses it (4 lines). 10 of 40 lines.
Checks: Diagnose tests 4/4 · unit 46/46 · lint ✓ · types ✓ · no test edited · db test running
Yours: is the claim in the right layer? Does pay() read top to bottom?
You: read the diff. OK commits "Charge once per order: claim it atomically before charging".
```

### 7. Tidy, commit, sweep

One tidy pass while green: a rename or an extract. Commit with a message that says why. Then ask where else the same
mistake appears: fix it within the budget, or note it in `DECISIONS.md`.
