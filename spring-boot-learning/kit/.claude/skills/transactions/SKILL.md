---
name: transactions
description: Spring @Transactional as it really behaves - rollback rules (checked exceptions commit), proxies (self-invocation, private and final methods), propagation (REQUIRES_NEW, rollback-only and UnexpectedRollbackException), what commits without @Transactional, JPA dirty checking and readOnly, @Async and event listeners vs the transaction, isolation on joined transactions, and the check-then-act race with its three fixes. Each answer proved by a test on Boot 4.1.1 + Postgres. Use when writing or reviewing transactional code, debugging "why did this commit/not commit", or practising interview questions on transactions.
---

# Transactions, with proof

Each answer below is a test in `kit-check` (`TransactionTrapsTest`, 18 tests, Spring Boot 4.1.1, Hibernate 7,
Postgres 16, 2026-10-20; stable over 5 repeated runs). **Predict before you read the answer**: that's the exercise.

## The one idea behind most traps

`@Transactional` is applied by a **proxy** wrapped around your bean. Only a call that **comes in through the proxy**
gets transaction behaviour: a call from another bean does; `this.method()` doesn't; the proxy can't intercept
`private` or `final` methods. And a transaction belongs to **one thread**.

## Rollback rules

| Situation | What happens | Test |
|---|---|---|
| `@Transactional` method saves, then throws `IOException` | **Commits.** By default only `RuntimeException` and `Error` roll back | `aCheckedExceptionCommits` |
| Same with `@Transactional(rollbackFor = Exception.class)` | Rolls back | `rollbackForMakesACheckedExceptionRollBack` |

Team rule worth having: either use unchecked exceptions for failures, or set `rollbackFor` deliberately.

## Proxies

| Situation | What happens | Test |
|---|---|---|
| `placeOrder()` (`@Transactional`) calls `this.audit()` (`REQUIRES_NEW`) in the same class | **One transaction.** `REQUIRES_NEW` is never seen; if `placeOrder` fails, the audit rolls back too | `selfInvocationIgnoresRequiresNewSoOneTransactionRollsBackBoth` |
| `audit()` moved to **another bean** | Two transactions: the audit commits even when the order rolls back | `requiresNewThroughAnotherBeanSurvivesTheOuterRollback` |
| `@Transactional` on a **private** method | **No transaction.** A proxy can't intercept private methods (Spring 6+ handles protected and package-private ones with class proxies) | `aPrivateTransactionalMethodHasNoTransaction` |
| `@Transactional` on a **public final** method, called from another bean | **No transaction**, because the CGLIB subclass can't override it. Worse: the call runs on the **proxy instance**, whose fields were never injected, so using a dependency throws `NullPointerException` | `aFinalTransactionalMethodHasNoTransaction`, `aFinalMethodRunsOnTheProxyWhoseFieldsAreNull` |

Fixes for self-invocation: move the method to another bean (cleanest), or use `TransactionTemplate` for an explicit
inner transaction. Kotlin classes are final by default: the `kotlin-spring` plugin opens them for this reason.

## What commits

| Situation | What happens | Test |
|---|---|---|
| No `@Transactional`: `orderRepo.save()`, then `paymentRepo.save()` throws | **The order stays.** Each Spring Data call runs in its own transaction | `withoutTransactionalEachSaveCommitsOnItsOwn` |
| Bean A (`@Transactional`) calls bean B (`@Transactional`, default `REQUIRED`); B throws, A catches and returns normally | **Nothing commits**, and A's caller gets `UnexpectedRollbackException`. B's proxy marked the shared transaction rollback-only; A can't un-mark it | `swallowingAnInnerFailureStillRollsBackEverything` |
| JPA: load a `User` in a `@Transactional` method, change the email, never call `save()` | **Persisted.** The entity is managed; Hibernate's dirty checking flushes the change at commit | `aChangedManagedEntityIsSavedWithoutCallingSave` |
| The same in `@Transactional(readOnly = true)` | **Not persisted.** Hibernate doesn't flush in a read-only transaction | `inAReadOnlyTransactionTheChangeIsNotSaved` |

If B's failure really is optional, B needs its own transaction (`REQUIRES_NEW` on another bean), or A must not call it
inside its transaction. Catching is not enough.

## Threads and events

| Situation | What happens | Test |
|---|---|---|
| `@Transactional` method calls an `@Async` method on another bean that inserts a row, then throws | **The row stays.** The async method runs on another thread, outside the caller's transaction | `anAsyncInsertIsNotRolledBackWithTheCaller` |
| Publish `OrderPlaced` inside a transaction; an `@EventListener` sends the email; the transaction then rolls back | **The customer gets an email for an order that doesn't exist.** A plain `@EventListener` runs immediately, inside the transaction | `aPlainEventListenerActsEvenWhenTheTransactionRollsBack` |
| The listener uses `@TransactionalEventListener(phase = AFTER_COMMIT)` | Runs only after a commit | `anAfterCommitListenerActsOnlyAfterACommit` |

`AFTER_COMMIT` still loses the email if the process dies right after the commit. When it must not be lost, write an
**outbox** row in the same transaction and send from that (see the `design-patterns` skill).

## Isolation and locking

| Situation | What happens | Test |
|---|---|---|
| A `@Transactional` method calls another bean's `@Transactional(isolation = SERIALIZABLE)` | **The caller's isolation applies** (Postgres reports `read committed`): the inner method joins the existing transaction and its isolation setting is ignored. Called on its own, it gets `serializable` | `anIsolationLevelIsIgnoredWhenTheMethodJoinsAnExistingTransaction` |
| Wallet holds ₹500; two concurrent requests each load it, check ≥ ₹400, deduct ₹400 | **Both succeed.** ₹800 handed out, balance ends at ₹100: a lost update. `@Transactional` alone doesn't prevent it | `checkThenActWithoutLockingLetsBothWithdrawalsSucceed` |

Three fixes for the wallet, each with different trade-offs:

| Fix | How | What the second request sees | Test |
|---|---|---|---|
| Optimistic locking | `@Version` on the entity: `UPDATE … WHERE version = ?` | `ObjectOptimisticLockingFailureException`, so retry or answer 409 | `withVersionTheSecondWithdrawalFails` |
| Conditional update | `UPDATE wallet SET balance = balance - :amt WHERE id = :id AND balance >= :amt`, check the row count | 0 rows changed, so "insufficient funds" | `aConditionalUpdateLetsOnlyOneWithdrawalThrough` |
| Pessimistic lock | `@Lock(PESSIMISTIC_WRITE)` (`SELECT … FOR UPDATE`) on the load | Waits, then sees ₹100 | (not in the tests: explain it) |

Use optimistic locking when conflicts are rare, the conditional update when a single statement can express the rule,
and a pessimistic lock when the rule needs several reads and conflicts are common. In Postgres, `REPEATABLE READ`
would also stop the naive version (the second writer gets a serialization error, which you must retry).

## Other rules worth knowing

- Keep transactions short: no HTTP calls or message sends inside one. A slow partner holds a database connection and
  row locks for its whole duration.
- `TransactionTemplate` makes the boundary explicit and has no proxy rules: good for loops, batches and consumers.
- With `@SpringBootTest`, a test annotated `@Transactional` rolls back at the end, so you never see commit-time behaviour
  (flushes, constraint violations, `AFTER_COMMIT` listeners). These tests use `@Transactional(propagation = NOT_SUPPORTED)`
  on the class for exactly that reason.
- `spring.jpa.open-in-view=false`: otherwise a request-wide session hides lazy-loading mistakes until production.

## Learn by doing

1. Cover the answers above, predict each of the 18 test names' outcomes, then run
   `./mvnw test -Dtest=TransactionTrapsTest` in `kit-check` and compare.
2. Fix the self-invocation trap two ways (another bean; `TransactionTemplate`) and make its test assert the new
   behaviour.
3. Add the pessimistic-lock fix for the wallet with a test. Careful: the barrier in the naive test would deadlock
   with `FOR UPDATE`; explain why.
4. Turn the email listener into an outbox write and say what that changes when the process crashes after commit.
