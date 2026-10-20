---
name: java-modern
description: Modern Java (21+) features that change how backend code is written - records, sealed types with pattern-matching switch, virtual threads (what they fix, what they don't, pinning), sequenced collections, text blocks. Use when writing Java or modernising code.
---

# Modern Java for backend code

## Records: data with no ceremony

```java
public record Money(BigDecimal amount, Currency currency) {
    public Money {                                   // compact constructor: validate once, here
        Objects.requireNonNull(currency);
        if (amount.scale() > currency.getDefaultFractionDigits()) throw new IllegalArgumentException("too many decimals");
    }
}
```

Use for DTOs, value objects, events, configuration properties, query results. Not for JPA entities (they need a
no-arg constructor, mutability and identity). Money is never a `double`.

## Sealed types + pattern-matching switch: make illegal states unrepresentable

```java
public sealed interface PaymentResult permits Paid, Declined, Pending {}
public record Paid(String reference) implements PaymentResult {}
public record Declined(String reason) implements PaymentResult {}
public record Pending(Instant retryAt) implements PaymentResult {}

String message = switch (result) {                   // the compiler checks every case is handled
    case Paid p -> "paid: " + p.reference();
    case Declined d -> "declined: " + d.reason();
    case Pending p -> "try again at " + p.retryAt();
};
```

Add a fourth result and every `switch` that doesn't handle it stops compiling: that's the feature. Good for domain
decisions, command results, events.

## Virtual threads: cheap threads, same bottlenecks

`spring.threads.virtual.enabled: true` runs request handling (and `@Async`, scheduling) on virtual threads.
- **Fixes:** the thread-per-request cap. Thousands of requests can wait on I/O without thousands of OS threads.
- **Doesn't fix:** everything downstream. They still queue for 10 database connections; Little's law still holds
  (in-flight = throughput × latency). Limit concurrency to slow dependencies explicitly (bulkhead/semaphore).
- **Pinning:** on Java 21–23, blocking inside `synchronized` pins the carrier thread (prefer `ReentrantLock` around
  blocking I/O); Java 24+ removed that for `synchronized` (JEP 491). Find pinning with JFR's `jdk.VirtualThreadPinned`.
- **Don't pool them**, and be careful with large `ThreadLocal` caches (one per virtual thread).
- **Long-lived loops** (message consumers polling forever) gain nothing; platform threads are fine there.
- CPU-bound work gains nothing either.

## Smaller things worth using

- **Text blocks** for SQL and JSON in code and tests (`"""…"""`).
- **Sequenced collections**: `list.getFirst()`, `getLast()`, `reversed()`.
- **`var`** for locals when the type is obvious from the right-hand side.
- **`Stream.toList()`** (unmodifiable) instead of `collect(Collectors.toList())`.
- **Pattern matching for `instanceof`**: `if (e instanceof DataIntegrityViolationException d) …`.

## Learn by doing

1. Model a command's outcome as a sealed interface; handle it in a switch; add a case and follow the compile errors.
2. Turn virtual threads on; fire 500 concurrent requests at an endpoint that holds a DB connection for 100 ms with a
   pool of 10; predict the latency with Little's law, then measure.
