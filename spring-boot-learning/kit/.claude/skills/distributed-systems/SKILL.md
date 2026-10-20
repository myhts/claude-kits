---
name: distributed-systems
description: Building and explaining a distributed backend with Spring Boot, Kafka, Redis and Postgres - accept-fast write paths, keys and partitions, at-least-once with idempotent consumers, publish-after-commit vs outbox, poison messages, rebalancing and shutdown, exactly-once trade-offs, Redis caching with a version guard, read-your-writes, atomic rate limiting in Lua, locks, sharding and hot keys, plus consistency and consensus basics. Patterns proven in a real project's test suite (Boot 4.1.1, Kafka 4.1, Redis 7.4). Use when designing or reviewing messaging, caching, idempotency, scaling or failure handling, or preparing distributed-systems interview answers.
---

# Distributed systems, with proof

Every pattern here runs in **EventStorm**, the author's Kafka-first insurance platform (a private project; if you
have access, it's the full worked example). Its tests are the proof, named under each section, so you can write the
same test in your own project; its explorer page shows each idea as a ladder of levels with measured numbers. Copy the
shape, not the domain.

**The questions to ask about any flow:** What happens if this message arrives **twice**? **Out of order**? **Never**?
What if the process dies **between** two steps? What does the client see while it's **pending**?

## 1. The write path: accept fast, work in batches

| Level | Shape | When it breaks |
|---|---|---|
| Synchronous | request → transaction → 201 | throughput = DB transactions per second; bursts queue on the pool |
| Queue first | validate → produce to Kafka (`acks=all`) → **202 + `Location`** → poll for status | needs status, idempotency and a read model |
| Batch the drain | consumer takes up to 500 records → **one** DB transaction → publish events → ack | a poison record would block the batch (§4) |
| Scale out | more partitions × more consumers; then shard the database (§7) | hot keys; cross-shard invariants |

A 202 must mean "durably stored": produce with `acks=all` before answering. Proof: `QueuedFlowIT`,
`QuoteBatchHandlerIT`, `PolicyBatchHandlerIT`. Measured there: burst ingest ~290/s → ~1,000/s; drain 60 s → 7 s.

## 2. Kafka: keys, partitions, ordering

- **Order exists only within a partition**, and the key picks the partition. Key by the entity whose events must stay
  in order (the quote, the account), never by something random.
- **Fix the partition count up front** (EventStorm: 64). Changing it later remaps keys and breaks per-key order.
- Consumers in a group share partitions; useful consumer threads ≤ partitions (`listener.concurrency`).
- Producer settings that matter:

```yaml
spring.kafka:
  producer:
    acks: all                       # a 202 must mean "stored on the in-sync replicas"
    properties:
      enable.idempotence: true      # the broker drops the producer's own retried duplicates
      linger.ms: 5                  # small batching window
      delivery.timeout.ms: 5000     # fail fast when Kafka is down…
      max.block.ms: 2000            # …including send() waiting for metadata (default 60 s hangs every request)
  consumer:
    enable-auto-commit: false       # commit offsets only after the work is done
    max-poll-records: 500
  listener:
    type: batch
    ack-mode: manual
```

Replication (production): `replication.factor=3`, `min.insync.replicas=2`, `acks=all`: a write survives one broker
loss; with `acks=1` the leader can ack and then die before replicating. Proof: `KafkaBehaviourIT` (redelivery of
uncommitted vs committed offsets), `KafkaUnreachableFailsFastTest`, `KafkaQuoteCommandBusBreakerTest`.

## 3. At-least-once, made safe

Kafka redelivers anything not acked (crash, rebalance, timeout). So **every consumer must be idempotent**, end to end:

1. **Idempotency key from the client** (`Idempotency-Key` header) → becomes the command id.
2. **Deterministic ids for follow-ups**: `bind-<quoteId>`, not a random UUID, so a redelivered event creates the same
   command, not a second one.
3. **A command log in the same transaction as the state change**:
   ```sql
   INSERT INTO command_log (command_id, …) SELECT * FROM unnest(:ids, …)
   ON CONFLICT (command_id) DO NOTHING RETURNING command_id     -- the ids NOT returned were seen before
   ```
   A replayed command returns the stored outcome and **re-emits its stored events**. It never applies twice.
4. **Concurrent duplicates** (two copies at once): the unique key makes one transaction fail; treat it as transient
   (retry, then the log answers) or answer 409 + `Retry-After` on a synchronous API.

**Publishing after commit.** Two correct options:
- **Outbox**: write the event to an `outbox` table in the same transaction; a relay publishes it and marks it sent
  (`SKIP LOCKED`, at-least-once): see the `design-patterns` skill.
- **Publish, then ack** (EventStorm's choice): commit state + events + command log, then publish, then ack the input.
  A crash after commit redelivers the input; the command log recognises it and re-publishes the stored events.

Never publish **inside** the DB transaction (rollback after the publish = a phantom event) or ack **before** the
work (crash = lost work). Proof: `CrashAfterCommitIT` (kill between commit and publish), `JdbcCommandLogIT`,
`QuoteCommandHandlerIT`.

**Pitfall found by EventStorm's labs:** with sharding, a retry that gets a *fresh* id can route to another shard
whose command log has never seen the key → bound twice. Derive the routing id from (tenant, idempotency key).

## 4. Poison messages and failures

```java
// decode first, outside the transaction: what can't be decoded is parked, never retried
for (record : records) try { decoded.add(decode(record)); } catch (RuntimeException e) { park(record, "undecodable", e); }
try {
    return transactions.execute(s -> handleAll(decoded));          // the fast path: one transaction per batch
} catch (RuntimeException e) {
    if (isTransient(e)) throw e;                                   // DB down, lock timeout: retry the whole batch
    return oneByOne(decoded);                                      // a bug: isolate it, park only the bad one
}
```

- **Transient** (connection lost, optimistic lock, concurrent duplicate): rethrow → the error handler retries with
  **exponential backoff and full jitter** (200 ms doubling to 30 s), forever, so nothing is skipped.
- **Permanent** (bad data, a bug): **park** it on `<topic>.parked` with the reason in headers; the partition moves on.
- Keep the retry cap below `max.poll.interval.ms`, or the consumer is evicted mid-retry.
- Every consumer needs this, including projectors, not only command handlers.

Proof: `PoisonCommandsIT`, `CommandErrorHandlingTest`, `JitteredExponentialBackOffTest`, `RetryStormSimulationTest`
(fixed 1 s retry: peak 1,000; full jitter: 167).

## 5. Rebalancing, shutdown and exactly-once

- **Rebalance**: a consumer joining, leaving or missing `max.poll.interval.ms` moves partitions. Uncommitted work is
  redelivered elsewhere, which is safe because of §3. Cooperative-sticky assignment moves fewer partitions; static
  membership (`group.instance.id`) avoids a rebalance on a quick restart.
- **Graceful shutdown**: stop polling, finish the in-flight batch, commit offsets, then exit. Container stop timeout
  < Spring's shutdown phase < Kubernetes grace period (EventStorm: 20 s < 25 s < 30 s). Proof: `GracefulShutdownIT`.
- **Exactly-once** (`transactional.id`, read-process-write, consumers on `read_committed`) covers Kafka-to-Kafka only.
  The moment a database write is involved you still need idempotency, so most systems choose **at-least-once +
  idempotent consumers**, and say so.
- Watch **consumer lag** per group and partition: it's the queue's real age. Alert on it.

## 6. Redis: caching and reads

- **Cache-aside with a version guard**: the projector writes the read model to Postgres, then puts it in Redis only if
  newer, atomically:
  ```lua
  local current = redis.call('HGET', KEYS[1], 'v')
  if current and tonumber(current) >= tonumber(ARGV[1]) then return 0 end   -- an older event never wins
  redis.call('HSET', KEYS[1], 'v', ARGV[1], 'd', ARGV[2]); redis.call('EXPIRE', KEYS[1], tonumber(ARGV[3])); return 1
  ```
- **Redis serves, it never decides**: anything that must be correct (ownership, idempotency, balances) is checked in
  Postgres. If Redis is slow or down, skip it behind a circuit breaker and read Postgres.
- **Read-your-writes** after an async write: the 202 returns the version written; the read asks `?minVersion=n` and
  waits briefly (≤ 1 s) for the read model to catch up, else answers with `X-Data-Stale` + `Retry-After`. Don't wait
  when no version was asked for; cache "not found" briefly (negative caching) so unknown ids stay cheap.
- **Stampede**: when a hot key expires, many requests miss at once. Use single-flight per key, early refresh, or jittered
  TTLs.

Proof: `PolicyViewCacheIT`, `PolicyViewReaderIT`, `PolicyViewReaderFallbackIT`, `PoisonedCacheIT`,
`PolicyViewProjectorIT` (old events must not win).

## 7. Rate limiting, locks, sharding, hot keys

- **Token bucket in one Lua script** (read, refill, take, write is one atomic step; two instances share it):
  ```lua
  local tokens = tonumber(state[1]) or capacity; local ts = tonumber(state[2]) or now
  tokens = math.min(capacity, tokens + math.max(0, now - ts) * rate / 1000)
  if tokens >= 1 then tokens = tokens - 1; allowed = 1 else retry = math.ceil((1 - tokens) * 1000 / rate) end
  redis.call('HSET', KEYS[1], 'tokens', tostring(tokens), 'ts', now); redis.call('PEXPIRE', KEYS[1], ttl)
  ```
  Answer **429 with `Retry-After`**. Separate budgets per kind of call (writes vs status polls). If Redis is down, fall
  back to a per-instance local bucket. **Hot key**: lease a block of tokens locally instead of one Redis call per
  request. Proof: `RedisTokenBucketIT`, `LeasedTokenBucketIT`, `RateLimitFairnessIT`, `RedisRateLimiterFallbackTest`.
- **Locks**: `SET key token NX PX ttl`, release only if the token still matches (Lua). A lock with a TTL can expire
  while the holder still works, so protect the resource with a **fencing token** (a version the database checks). Prefer
  a database constraint or a conditional update when one exists. Redlock is debated for exactly this reason.
- **Sharding**: pick the key that keeps related writes together (quote and its policy on one shard), route with a
  stable function of it, give each shard its own sequences, and prove linear scaling by measuring. Cross-shard
  invariants are the cost. Proof: `ShardRouterTest`, `ShardRoutingDataSourceIT`, `ShardedWritePathIT`.
- **Batch the round trips** before adding hardware: one `unnest` insert per batch, not one per row (`PolicyBatchHandlerIT`).

## 8. Consistency and consensus, briefly

- **Know which guarantee each part gives**: the command path is strongly consistent in Postgres; the read model is
  eventually consistent; read-your-writes is a per-client guarantee on top.
- **CAP**: during a partition, choose consistency or availability. **PACELC**: otherwise, choose latency or
  consistency.
- **Quorums**: with N replicas, R + W > N makes reads see the latest write.
- **Raft**: a leader is elected for a term, appends to its log, replicates, and commits when a majority has it. Kafka's
  KRaft controller and etcd use it.

## 9. Testing distributed behaviour

- **Real infrastructure** in tests: Testcontainers for Kafka, Redis and Postgres, never in-memory fakes.
- **Kill it on purpose**: crash between commit and publish, pause Redis, stop Kafka, inject a slow or failing partner
  behind a dev-only switch, and assert what the client sees.
- **No sleeps**: wait on conditions (status endpoint, row present, lag zero).
- Load-test bursts with k6 and reconcile afterwards (count in = count out, zero duplicates).
- `/project-explorer` turns these into labs with measured numbers for a new project.

## Learn by doing

1. Draw the write path of the project you're in and answer the four questions at the top for each arrow.
2. Make one consumer idempotent with a command log, then write the test that redelivers the same record twice.
3. Kill the process between commit and publish (a test hook), and prove nothing is lost or doubled.
4. Add a version guard to a cache write, and a test where an older event arrives last.
