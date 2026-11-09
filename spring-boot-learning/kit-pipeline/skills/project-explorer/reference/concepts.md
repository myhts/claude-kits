# Concept ladders

A concept page explains **why** a part is built the way it is, as a ladder: each level is a problem with a number,
the change it forced, and the result, whose cost becomes the next level's problem. It starts naive (L0: what happens
with nothing in place) and climbs to whatever the system needs at its target scale. The reader should be able to
predict the next level before pressing Next, and reuse the ladder in a different domain.

## Finding concepts in a codebase

Look for the mechanism, then for the threshold that justifies it. Signals to grep for:

| Concept | Signals in code / config |
|---|---|
| Rate limiting, quotas, fairness | token bucket, `RateLimiter`, bucket4j, express-rate-limit, `limit_req`, Redis `INCR`/Lua, `429`, `Retry-After` |
| Timeouts, retries, backoff, circuit breakers, bulkheads | resilience4j, Polly, opossum, tenacity, Hystrix, axios-retry, `timeout`, `maxAttempts`, `jitter`, `CircuitBreaker` |
| Idempotency, exactly-once effects | `Idempotency-Key`, dedupe tables, unique constraints, `ON CONFLICT`, upserts, outbox, inbox, message ids |
| Async / queue-first writes | Kafka, RabbitMQ, SQS, NATS, Pub/Sub, Celery, Sidekiq, BullMQ, `202 Accepted`, consumers, DLQs |
| Write scaling | connection pools (Hikari, pgbouncer), batching, partitioning, sharding, backpressure, load shedding |
| Read scaling | caches (Redis, Caffeine, CDN), read replicas, CQRS projections, materialized views, pagination, ETags |
| Consistency | transactions, isolation levels, optimistic locking (`version`), sagas, read-your-writes, eventual consistency |
| Capacity and resilience | autoscaling, health/readiness probes, graceful shutdown, Little's law, pool sizing, cells, multi-region |
| Data | indexes, N+1 queries, migrations (expand/contract), archival, hot keys |
| Front end | SSR/ISR/streaming, code splitting, client caches (TanStack Query, SWR), optimistic UI, polling vs push |
| Security and tenancy | authn/authz, tenant isolation, secrets, signed URLs |

Also note **gaps**: mechanisms the system will need at 10× or 100× but doesn't have. They become `proposed: true`
levels (shown as "What we'd change (proposed, not built)" with `model`/`calculated` numbers only).

Pick concepts the codebase actually exercises; 3–6 is a good page. Present the candidate list at the labs gate with,
for each: where it lives, a one-line ladder sketch, and what a lab would need.

## Building one ladder

1. **L0 is the naive version.** No limit, no timeout, no cache, one instance. Show what breaks and the number that
   says so ("6,945 req/s against a 2,500/s tier", "8 of 8 threads blocked"). If the codebase never had L0, it's still
   L0: the reader needs the "before".
2. **Each level is forced by a threshold.** A number crossed (latency, pool size, partitions, error rate, memory,
   cost), not a preference. Write it in `q`, `cap[0]`, `cause` and the `g1` gauges, with the threshold line (`thr`).
3. **The change is minimal and concrete.** `diff` lists what was added/changed/removed with a code link each. Frame 2
   shows it: green = added, amber = changed, dashed = gone.
4. **The result has numbers and a cost.** `g3` shows the improvement; `next` names the new problem this created.
   That cost is the next level's `q`. The ladder ends when the target scale is met or the next step is a different
   concept.
5. **Options.** What else could have been done and why not (`options`). Seniors are judged on the alternatives they
   rejected.
6. **Proof.** A verified breakpoint (`bp`), the test that proves the behaviour (`tests`), and a lab (`lab`) if labs
   were approved.
7. **Recap.** The pattern without this project's domain in it (`pattern`), the same ladder in other domains
   (`elsewhere`), a 45-second spoken answer (`say`), and what evidence would change the design (`undo`).

Levels that exist in the code but have a bug found while measuring keep the bug in `lesson` and in the final report;
don't fix it.

## Numbers

Every number on a concept page carries a tag:

- `measured`: we ran it, on this machine, recorded in MEASURED.md (date, machine, command, raw output, config).
- `calculated`: arithmetic from config or a capacity model (show the formula in `note`).
- `rule`: an industry ballpark ("one Redis shard ~100k ops/s"). Say "verify on your hardware".
- `model`: simulated, for designs that aren't built.

Never present a calculated or ballpark number as measured. If a measurement surprises you, re-run it before writing
it down, and say what was surprising in `lesson`.

## Diagram craft

- 3–6 boxes per scene; the scene is 1000 × 340. Columns 0–4, rows 0–2 with `at: [col, row]`.
- Keep the same box in the same place across levels so frame 2 reads as a diff. Replace a box in place (same `at`)
  when it changes role; the engine hides the old one.
- Opposite arrows between the same pair: `{ off: 9 }` on one of them.
- Labels ≤ 30 chars. The engine places them clear of boxes; `check-explorer.mjs` flags any that couldn't be.
- `hurt` marks where it hurts in frame 1; `changed` marks amended boxes in frame 2.
