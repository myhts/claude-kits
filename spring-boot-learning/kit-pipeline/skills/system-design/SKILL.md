---
name: system-design
description: System design for Senior/Staff backend interviews and real projects - the 45-minute shape, requirements and numbers first, back-of-envelope sizing, Little's law and pool sizing, a 1×/10×/100× capacity model with the next bottleneck at each level, the building blocks and when each earns its place, non-functional checklists (SLOs, failure, migration, cost), 14 classic designs with the point each one tests, a scoring rubric, and how to turn your own project into your best answer. Use when designing a system, writing a design doc, sizing capacity, or practising a design interview.
---

# System design

The method behind the design of EventStorm, the author's private example project (its sizing, Little's law,
capacity and mock-interview material). The worked numbers below are invented; use your own system's measurements in
an interview: a measured number beats a guessed one every time.

## The 45 minutes

| Minutes | Phase | What good looks like |
|---|---|---|
| 0–5 | **Requirements** | functional (the 3–5 core operations), non-functional (latency, durability, consistency, availability), scale. Write them down. Ask about **bursts** and **who the clients are** |
| 5–10 | **Numbers** | average vs peak vs burst; ingest vs drain; storage per year; read:write ratio |
| 10–25 | **Design** | API → the write path → storage → the read path. Every box justified by a number or a requirement |
| 25–35 | **Deep dives** (they pick) | correctness (idempotency, ordering, uniqueness), the hot path, the bottleneck, consistency |
| 35–42 | **Scale + failure** | 10×, 100×: what breaks next and what you change; failure modes and the degradation order |
| 42–45 | **Wrap-up** | the trade-offs you made, and what you'd measure or build next |

**Habits that score:** say the number, then the consequence ("4,000/s for 10 s is 40k commands; draining at 600/s
takes ~70 s, so put a queue in front"). Name the trade-off when you choose. Find the bottleneck before they do. Put
correctness before scale ("at-least-once delivery, idempotent processing", never "exactly-once" by itself). Check in:
"Deeper on the write path, or on scaling?"

## Numbers, fast

1. **Per day → per second**: 1 day ≈ 86,400 s ≈ 10⁵ s, so 1M/day ≈ 12/s on average.
2. **Peak**: if the busiest hour carries 10% of the day, it runs at 2.4× the daily average.
3. **Bursts are not peaks**: a burst is seconds long. Size the **queue** for bursts and the **database** for
   sustained load.
4. **Storage**: rows/year × bytes/row × 2–3 (indexes, history, replicas).
5. **Sanity-check** against rough capacities (verify on your hardware):

| Thing | Rough capacity |
|---|---|
| Postgres primary, indexed inserts | ~1–10k rows/s single; ~10–50k rows/s batched |
| Kafka broker | ~50–100 MB/s writes |
| Redis node | ~100k+ simple ops/s |
| App instance, simple request | ~1–10k req/s |
| Same-region round trip | ~0.5 ms; cross-region 50–150 ms |

*Worked example (invented):* 2M orders/day ≈ 23/s average; busiest hour 12% → ~67/s; a partner's batch dumps 20k in
10 s → 2,000/s for 10 s. So the API must accept 2,000/s; the database must sustain ~70/s with headroom; a queue absorbs
the burst and drains it in a few minutes.

## Little's law and pools

| Form | Answers | Example |
|---|---|---|
| **L = λ × W** | how many are in flight | 1,000 req/s × 34 ms = 34 busy connections |
| **λmax = L ÷ W** | the most a pool can do | 10 connections ÷ 34 ms ≈ 290/s (measured: EventStorm's first bottleneck) |
| **W = L ÷ λ** | how long a backlog takes | 40,000 queued ÷ 2,000/s = 20 s |

Waiting grows like ρ ÷ (1 − ρ): 70% busy ≈ 2.3× the service time, 90% ≈ 9×. Size pools for ~70%:
**pool = ⌈λ × W ÷ 0.7⌉**. But the database is the real resource: ~2 × cores + 1 active connections does its best work,
so a bigger pool only moves the queue into the database. The two ways out: **shrink W** (fewer round trips, batching)
or **add independent capacity** (more instances, then shards).

## Capacity model: 1×, 10×, 100×

For each tier: **measured per-unit capacity × target utilisation → units needed**, then name **what breaks next**.
Mark every number as *measured*, *calculated* or *assumed*, and say which assumption to measure first.
Typical ladder for a write-heavy system: connection pool → DB transactions/s (batch) → one primary (shard) → partition
count (fixed up front) → hot keys (leasing, splitting) → one region's blast radius (**cells**: independent copies of
the whole stack, routed by tenant).

## Building blocks, and when each earns its place

| Block | Use when | The cost you must name |
|---|---|---|
| Queue / log (Kafka) | bursts, decoupling, replay, fan-out | at-least-once → idempotency; ordering only per key; async status for clients |
| Cache (Redis) | read-heavy, tolerable staleness | invalidation, stampede, must never decide correctness |
| Read model (CQRS) | reads shaped differently from writes | eventual consistency → read-your-writes |
| Sharding | one primary can't take the writes | cross-shard queries and invariants, rebalancing |
| Read replicas | read scale on the same shape | replica lag |
| Search index | text, facets, typeahead | a second copy to keep in sync |
| Blob store + CDN | files, media, static content | presigned uploads, cache invalidation |
| WebSockets / SSE | real-time push | connection servers, fan-out, reconnects |
| Rate limiter | protect shared capacity, fairness | per-tenant budgets, 429 + `Retry-After` |
| Circuit breaker, timeouts | any remote call | the fallback: what the user gets when it's open |

Patterns and code for these: the `distributed-systems`, `resilience-patterns` and `design-patterns` skills.

## Non-functional checklist (Staff interviews probe these)

- **SLOs**: two or three SLIs with targets and an error budget (e.g. 99.9% of purchases accepted in < 300 ms).
- **Failure**: each dependency down or slow: what the user sees, what is queued, what is dropped first.
- **Consistency**: which data must be strongly consistent, and which may lag (and by how much).
- **Security and tenancy**: authentication, authorization **per resource**, data isolation between tenants.
- **Operability**: metrics (RED/USE), tracing across the queue, alerts on symptoms, runbooks.
- **Evolution**: expand/contract migrations, backfills, canary or blue-green, feature flags, versioned events.
- **Cost**: the biggest line item at 10×, and one way to cut it.
- **Phasing**: v1 that ships in weeks, v2 when the numbers demand it. Staff answers say what **not** to build yet.

## Fourteen designs and what each one tests

| Design | The point it tests |
|---|---|
| Rate limiter | token bucket vs window; atomicity across instances; hot keys |
| Payment / ledger | idempotency keys, double entry, exact money, reconciliation |
| Notification system | fan-out, retries with jitter, dedupe, user preferences, provider failover |
| News feed | fan-out on write vs read, the celebrity problem, ranking |
| Distributed job scheduler | leases, at-least-once jobs, `SKIP LOCKED` vs a broker, time zones |
| Metrics / logging pipeline | ingest at volume, batching, backpressure, retention and downsampling |
| Chat / messaging | connection servers, per-conversation order, delivery receipts, offline users |
| Distributed key-value store | consistent hashing, replication, quorums, hinted handoff, partitions |
| Search / typeahead | inverted index, prefix tries, top-k, index updates from events |
| Proximity / ride-hailing | geohash or quadtree, location update rate, matching |
| URL shortener | unique ids at scale, redirects from cache, analytics off the hot path |
| File upload (Dropbox-style) | presigned multipart uploads, metadata vs blobs, dedupe, sync |
| LLM gateway | routing, quotas, caching, cost per request, fallbacks |
| RAG assistant | ingestion, retrieval quality (recall@k), grounding, evals |

## Rubric (score 1–4 each; aim for 3+ everywhere)

| Area | 1 | 4 |
|---|---|---|
| Requirements | jumped into boxes | functional + non-functional + scale written down; asked about bursts |
| Numbers | none, or 10× wrong | peak vs burst, ingest vs drain, used them to choose |
| Design | boxes without reasons | each box justified by a number or a requirement |
| Correctness | "Kafka gives exactly-once" | at-least-once + idempotency, ordering by key, uniqueness |
| Scale | "add more servers" | per-unit × utilisation; the next bottleneck named at each level |
| Failure | not discussed | breakers, fallbacks, jittered retries, a degradation order |
| Communication | monologue, out of time | checked in, kept time, summarised trade-offs |

A round type is ready when **two mocks in a row** score 3 or better everywhere.

## Your own project as the answer

1. Write its requirements and numbers as above, from **measurements**, not guesses (load-test one unit).
2. Keep a **"why not X?" sheet**: each major decision, the alternative you rejected, and the number that decided it.
3. Write the capacity model with the next bottleneck at each tier.
4. Prepare 60-second war stories: something you measured that surprised you, and what you changed.
5. Run `/project-explorer` to build the map, the request flows and concept ladders with labs. Present from that page.
6. Practise the 45 minutes with a timer, record it, score it with the rubric.

## Learn by doing

1. Size the invented example above for 10× and 100×, naming the bottleneck at each step.
2. Do one design from the table per session, 45 minutes out loud, then compare with a reference (Alex Xu vol. 1–2,
   Hello Interview, *Designing Data-Intensive Applications* ch. 5–7 and 11).
3. Ask Claude to interview you (`/interview-drill`), with twists: "the partner's API goes down", "traffic is 100×".
