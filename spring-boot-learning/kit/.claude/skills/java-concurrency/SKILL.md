---
name: java-concurrency
description: Java concurrency as it really behaves, for teaching, reviewing and interview prep - thread states, the Java Memory Model (atomicity vs visibility, happens-before, volatile vs synchronized, safe publication), and, section by section, locks and conditions, deadlock and interruption, atomics and concurrent collections, coordinators, executors, CompletableFuture, virtual threads, and concurrency LLD. Each claim proven by a test in kit-check on Java 21. Use when writing, reviewing or explaining concurrent Java code, or preparing concurrency interview answers.
---

# Java concurrency

Built section by section alongside a 10-session sprint. **Done:** section 1. **Coming:** 2 locks and conditions,
3 deadlock and interruption, 4 atomics and concurrent collections, 5 coordinators, 6 executors, 7 CompletableFuture,
8 virtual threads (21 vs 24 vs 25), 9 concurrency LLD.

**Verified** (2026-10-26) on Java 21.0.12 by kit-check's `com.example.kitcheck.concurrency` tests; every state and
rule below with "(test)" is asserted there. Rules marked (JLS) are the specification's, and can't be proven by a
test (a test can show a bug, never the absence of one).

## The two questions before any concurrent code

1. **What is shared and mutable?** Locals and confined objects are safe. Anything on the heap two threads can reach
   is shared. No shared mutable state, no concurrency problem.
2. **What is the smallest step that must be atomic?** Usually "read-modify-write" or "check-then-act". Name it,
   then pick the tool.

## 1. Threads and the Java Memory Model

### Thread states (`Thread.State`): six, and what puts a thread in each

| State | Caused by | Notes |
|---|---|---|
| `NEW` | created, `start()` not called | (test) |
| `RUNNABLE` | running or ready to run; **also blocking I/O** (socket read, `accept`) | (test) There is no RUNNING state |
| `BLOCKED` | waiting to enter a `synchronized` block/method another thread holds | (test) **Keeps every lock it already holds**: that's how deadlocks form |
| `WAITING` | `Object.wait()`, `Thread.join()`, `LockSupport.park()` with no timeout | (test) `join()` is WAITING, not TIMED_WAITING |
| `TIMED_WAITING` | `sleep(n)`, `wait(n)`, `join(n)`, `parkNanos` | (test) `sleep` **keeps** the monitor |
| `TERMINATED` | `run()` returned or threw | (test) A thread can't be restarted |

- `wait()` releases **only the monitor it waits on** (test), and must be called holding it.
- `Thread.stop()` throws `UnsupportedOperationException` since Java 20. Stopping is cooperative: interruption
  (section 3) or a flag.
- Daemon threads don't keep the JVM alive: it exits when every **non-daemon** thread has ended (not when `main`
  returns).

### Two different failures: atomicity and visibility

| | What goes wrong | Example | Fix |
|---|---|---|---|
| **Atomicity** | Two threads interleave inside a compound action | `count++` (read-modify-write); `if (!map.containsKey(k)) map.put(k, v)` (check-then-act) | Make the compound step atomic: a lock, an atomic class, `ConcurrentHashMap.compute` |
| **Visibility** | One thread's write is never (or late, or partly) seen by another | A loop on a plain `boolean` flag never stops: the JIT may read it once | A happens-before edge: `volatile`, a lock, a thread start/join, a concurrent collection |

`volatile` fixes visibility, **not** atomicity: `volatile long count; count++` still loses updates.

### Happens-before (JLS 17.4.5): the rules that matter in practice

If X happens-before Y, Y sees X's writes and everything before X in X's thread. Without an edge there is **no
guarantee**, not even "eventually".

| Edge | |
|---|---|
| Program order | within one thread |
| Monitor | unlock of M → every later lock of the **same** M |
| Volatile | write of v → every later read of v |
| Thread start | everything before `t.start()` → everything in `t` |
| Thread join | everything in `t` → `t.join()` returning (test: results read after `join` are complete) |
| Transitivity | X→Y and Y→Z give X→Z (this is why a volatile flag can "publish" plain fields written before it) |
| Executors, concurrent collections, `CompletableFuture` | putting/submitting → the consumer that takes/runs it (their Javadoc's "memory consistency effects") |

### `synchronized` vs `volatile`

| | One thread at a time | Writes visible | Use |
|---|---|---|---|
| `synchronized` | yes | yes (monitor edge) | compound actions on shared state |
| `volatile` | no | yes, plus no reordering across it | a flag, a status, a reference to an immutable object, written by one thread at a time |

Both the writer **and** the reader must use the same lock (or the same volatile field). A synchronized writer with
an unsynchronized reader has no edge.

### Safe publication and immutability

An object is safely published (its fields seen fully initialised) when the reference is handed over through an
edge: a `volatile` or `final` field, a lock, a static initialiser, a concurrent collection, a thread start.

- **Immutable objects** (all fields `final`, no `this` escape in the constructor; records count) are safe to share
  once constructed: the `final` field semantics guarantee readers see the constructed values (JLS 17.5).
- **Swap, don't mutate**: shared settings as a `volatile` reference to an immutable object (a record, `Map.copyOf`);
  the writer builds a new one and replaces the reference. Readers take no lock and always see a complete version.
- **Double-checked locking** works only with the field `volatile` (since Java 5); without it a reader can see a
  non-null reference to a not-yet-initialised object. Simpler: the holder-class idiom
  (`private static class Holder { static final Config INSTANCE = ...; }`), lazily initialised by class loading.
- Non-volatile `long`/`double` writes may tear into two 32-bit halves (JLS 17.7); `volatile` ones never do.

### Testing concurrent code (applies to every section)

- **Release threads together** (a start gate: `CountDownLatch`) or they may never overlap.
- **Enough iterations to collide**: on Java 21, 8 threads × 100,000 increments of an unsafe counter failed only 2
  runs in 5; × 1,000,000 failed 5 in 5 (2026-10-26).
- **Time-limit everything** that can hang (`join(timeout)`, Awaitility), and make possibly-spinning threads daemons
  so a failure doesn't hang the build.
- **Wait for conditions, never sleep a guess** (`await().until(...)`).
- **A green test is evidence, not proof.** A visibility bug may hide on one JIT/CPU and appear on another; the
  happens-before argument is the proof. jcstress (OpenJDK) is the tool when it matters.

## Interview angles (section 1)

- "Is `volatile` enough?" → only if there's one writer at a time and no compound action (no read-modify-write).
- "Why does my loop never see the flag?" → no happens-before edge; the JIT hoisted the read; `volatile` adds the edge.
- "Thread state of a thread stuck on a slow HTTP call?" → RUNNABLE: thread dumps show RUNNABLE in a socket read.
- Production: a counter under-reports only under load → lost updates; confirm with a concurrency test at the
  real thread count; fix with a lock, or `AtomicLong`/`LongAdder` for hot counters (section 4).
- Staff: hot config read path → `volatile` reference to an immutable snapshot; no read locks; copy-on-write updates.
