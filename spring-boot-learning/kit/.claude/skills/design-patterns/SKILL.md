---
name: design-patterns
description: Patterns that matter in backend systems - a correct transactional outbox (SKIP LOCKED, acks before marking, at-least-once), idempotent consumers, sagas with compensation, CQRS and read-your-writes, plus when classic GoF patterns help. Outbox verified on Boot 4.1.1 + Postgres. Use when designing how components exchange data or keep consistent.
---

# Design patterns for backend systems

Start from the problem, not the pattern. Each section: the problem, the pattern, what it costs.

## Transactional outbox (verified)

**Problem:** you update the database *and* publish an event. Two systems, no shared transaction: a crash between
them loses the event, or publishes an event for a change that rolled back.

**Pattern:** write the event to an `outbox` table in the **same transaction** as the change; a relay publishes
unpublished rows and marks them only after the broker acknowledged them.

```java
@Transactional(propagation = Propagation.MANDATORY)   // refuses to run outside the business transaction
public void append(String topic, String key, String payload) { /* insert into outbox … */ }

@Transactional
public int publishBatch(int max) {
    List<OutboxRow> rows = jdbc.sql("""
            select id, topic, message_key, payload from outbox
            where published_at is null
            order by id
            limit :max
            for update skip locked""")          // several relays run without blocking or double-sending
        .param("max", max).query(OutboxRow.class).list();
    // send all, then wait for every ack (with a timeout) before marking
    CompletableFuture.allOf(acks).get(10, TimeUnit.SECONDS);   // failure → exception → rollback → retried later
    jdbc.sql("update outbox set published_at = now() where id in (:ids)")…
}
```

Verified by tests: the event row is written with the business row; `append` outside a transaction fails; two relays
running at the same moment send 10 rows exactly once (and the test **fails without `SKIP LOCKED`**); a failed send
leaves the rows unpublished and the next run sends them.

The common broken version, and why each line matters:
- Marking rows published **without waiting for the ack** (fire-and-forget `send`) → a failed send is lost forever.
- No `SKIP LOCKED` → two instances either block each other or publish the same rows.
- No `LIMIT` → one run tries to publish the whole backlog in one transaction.
- **It's at-least-once**: a crash after the ack but before the commit re-sends. Consumers must be idempotent.
- Holding the transaction while waiting for acks holds row locks: keep batches small and the ack timeout bounded.
- Alternatives: change data capture (Debezium reads the database log; no polling), or "store the outcome and replay
  on redelivery" when the command itself comes from a broker.

## Idempotent consumer

**Problem:** brokers and clients redeliver. **Pattern:** record each processed message id (or command id) with a
unique constraint, in the same transaction as the effect; on a duplicate, skip or return the stored result
(`insert … on conflict do nothing`). Derive ids for follow-up messages from the incoming id so a replay produces the
same ids. For HTTP, the client sends an `Idempotency-Key`.

## Saga

**Problem:** a business action spans services, each with its own database. **Pattern:** a sequence of local
transactions, each publishing an event (choreography) or driven by a coordinator (orchestration); on failure,
**compensating** actions undo earlier steps (refund, release stock). Costs: every step and compensation must be
idempotent; there are visible intermediate states ("payment pending"); orchestration is easier to follow and test
once there are more than ~3 steps.

## CQRS and read models

**Problem:** the shape that's good for writing (normalised, validated) is bad for reading (joins, aggregates, search).
**Pattern:** keep the write model; project events into read-optimised tables or a cache. Costs: the read side lags,
so plan for **read-your-writes** (return the new state in the write response; or let the client ask for "at least
version N" and wait briefly); projections must be idempotent and handle out-of-order events (keep a version per row).

## Classic patterns, when they earn their place

- **Strategy**: several interchangeable rules chosen at runtime (pricing per tier) → an interface + a map of beans.
- **Decorator**: add behaviour around a call without touching it (retry, metrics, a fault-injection switch for labs).
- **Adapter / ports**: keep a third-party API's shape out of your domain.
- **Factory / Builder**: complex construction with invariants (records with a compact constructor often suffice).
- **Observer / events**: decouple "something happened" from "who cares" (Spring application events in-process,
  a broker across processes).
If a pattern adds an interface with one implementation and no test seam, you probably don't need it yet.

## Learn by doing

1. Build the naive outbox (send without waiting, no SKIP LOCKED); write the concurrency test; watch it fail; fix it.
2. Make a consumer idempotent with a unique constraint; send the same message twice; check one effect.
3. Draw a 3-step saga with compensations; list which step can fail after which, and what the user sees.
