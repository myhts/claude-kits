---
name: resilience-patterns
description: Calling other services safely - timeouts first, then retries with jittered backoff, circuit breakers (incl. the half-open-only-on-traffic behaviour), bulkheads, rate limits and fallbacks, in the right order. Verified with Resilience4j 2.4 on Boot 4.1.1. Use when code calls another service, a broker or any remote dependency.
---

# Resilience patterns

Verified on Spring Boot 4.1.1 + Resilience4j 2.4.0 (2026-10-17) against a real slow local HTTP server.
Learn them in this order; each one fixes the previous one's remaining problem.

## 1. Timeouts (always, first)

A call without a timeout lets the other side decide how long your thread is stuck. A hung partner then exhausts your
threads or connection pool and your service goes down with it.

```java
HttpClient jdk = HttpClient.newBuilder().connectTimeout(Duration.ofMillis(200)).build();
JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(jdk);
factory.setReadTimeout(Duration.ofMillis(150));
RestClient http = RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
```

Verified: against a partner that sleeps 2 s, the call fails with `ResourceAccessException` in ~150 ms. Pick the
timeout from the partner's measured p99 plus margin, and keep it below your own caller's timeout.

## 2. Retries, with jitter, only for transient failures

```java
Retry.of("partner", RetryConfig.custom()
        .maxAttempts(3)
        .intervalFunction(IntervalFunction.ofExponentialRandomBackoff(Duration.ofMillis(100), 2.0, 0.5))
        .retryExceptions(ResourceAccessException.class)       // timeouts, connection errors
        .ignoreExceptions(CallNotPermittedException.class)    // breaker open: retrying is pointless
        .build());
```

- **Jitter** (the random factor) stops every client that failed together from retrying together.
- Retry only what's transient and **idempotent** (GET, or writes with an idempotency key). Never retry a 4xx.
- Retries multiply load: 3 attempts at every layer of a 3-layer call chain is 27 calls. Retry at one layer.

## 3. Circuit breaker

When a partner is down, every call still waits for the timeout. The breaker counts failures and, past a threshold,
fails calls immediately without calling the partner, then lets a few trial calls through to test recovery.

```java
CircuitBreaker.of("partner", CircuitBreakerConfig.custom()
        .slidingWindowSize(10).minimumNumberOfCalls(5).failureRateThreshold(50)
        .waitDurationInOpenState(Duration.ofSeconds(5))
        .permittedNumberOfCallsInHalfOpenState(2)
        .automaticTransitionFromOpenToHalfOpenEnabled(false)   // the default
        .build());
```

**Order: Retry(CircuitBreaker(call)).** Every attempt is recorded by the breaker, and once it opens the retries stop.
Verified: 3 timed-out attempts = 3 failures in the breaker; the 5th failure opens it; the next call fails in
< 50 ms with `CallNotPermittedException` and the partner receives nothing.

**OPEN → HALF_OPEN happens only when a call arrives**, by default. With no traffic, a breaker stays OPEN forever
(verified: OPEN after 2× the wait). `automaticTransitionFromOpenToHalfOpenEnabled(true)` moves it on a timer instead
(verified: HALF_OPEN with no calls). That matters for health checks and dashboards that read the state.

With annotations (`@CircuitBreaker`, `@Retry` from `resilience4j-spring-boot4`), configure instances in YAML under
`resilience4j.circuitbreaker.instances.<name>`; Resilience4j's documented default aspect order puts Retry outermost.
Verify the order you get with a test like the one above rather than assuming.

## 4. Bulkhead

Limit concurrent calls to one partner (a semaphore or a dedicated pool), so a slow partner can only take a slice of
your threads. With virtual threads, threads are cheap but the partner and your connection pool aren't: still limit.

## 5. Rate limiting

Inbound: protect yourself per client (token bucket: a burst size plus a refill rate; answer 429 with `Retry-After`).
Outbound: respect the partner's quota. In a cluster, a per-instance limit allows N × the limit; a shared limit
(Redis + an atomic script) is exact but adds a dependency that itself needs a fallback.

## 6. Fallbacks are a product decision

Cached value, default, "try again later" (queue it), or an honest error. A fallback that hides failure (fake data)
can be worse than the error. Write down what the user sees in each case.

## Observe it

Expose breaker state and metrics (`/actuator/health`, `/actuator/metrics/resilience4j.circuitbreaker.*` with
`register-health-indicator: true`), and log state transitions. A breaker you can't see is a mystery outage.

## Learn by doing

1. Call a stub that sleeps 2 s without a timeout; measure a request; add the timeout; measure again.
2. Add the breaker; make the stub fail; watch CLOSED → OPEN → (call) → HALF_OPEN → CLOSED in the logs.
3. Stop all traffic while it's OPEN and check the state; then flip the automatic transition and check again.
4. Put Retry inside the breaker instead of outside; write the test that shows what changes.
