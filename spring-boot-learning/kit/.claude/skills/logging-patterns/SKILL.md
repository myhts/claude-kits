---
name: logging-patterns
description: Logs you can follow - structured JSON logging (Boot's logging.structured), a request id in MDC on every line, keeping it across threads, async work and messages, what to log and what never to log. Verified on Boot 4.1.1. Use when adding logging, debugging a flow across components, or reading logs.
---

# Logging patterns

Verified on Spring Boot 4.1.1 (2026-10-17): with `ecs` structured logging, an MDC value set in a filter appears as a
JSON field on the log lines of that request.

## Structured logs (one JSON object per line)

```yaml
logging:
  structured:
    format:
      console: ecs      # also: logstash, gelf. JSON lines; MDC entries become fields
```

Machines (and Claude) can filter JSON: `jq 'select(.requestId=="abc-123")'`. For reading by eye locally, use a
profile without the property, or pipe through `jq -r '.message'`.

## A request id on every line

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {
    private static final Pattern SAFE = Pattern.compile("[A-Za-z0-9._-]{1,64}");   // never trust a header blindly

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String incoming = req.getHeader("X-Request-Id");
        String id = incoming != null && SAFE.matcher(incoming).matches() ? incoming : UUID.randomUUID().toString();
        MDC.put("requestId", id);
        res.setHeader("X-Request-Id", id);       // the caller can quote it in a bug report
        try {
            chain.doFilter(req, res);
        } finally {
            MDC.remove("requestId");             // threads are reused: always clean up
        }
    }
}
```

Verified: a safe incoming id is kept, `<script>` is replaced, and the id shows up as `"requestId":"…"` in the JSON.

## Keeping it across boundaries

MDC is **per thread**. It's lost when work moves:
- **Executors / `@Async` / `CompletableFuture`**: copy it. Spring's `ContextPropagatingTaskDecorator` (with the
  Micrometer context-propagation library) or a small `TaskDecorator` that captures `MDC.getCopyOfContextMap()` and
  restores it in the task.
- **Virtual threads**: each virtual thread is a new thread: same rule; nothing is inherited automatically.
- **Messages (Kafka, queues)**: put the id in a message header when producing; in the consumer, read it into MDC at
  the start of handling and clear it at the end.
- **Calls to other services**: send it as a header (`X-Request-Id`, or W3C `traceparent` with tracing).

When you add Micrometer Tracing (OpenTelemetry), `traceId`/`spanId` go into MDC and propagate over HTTP and, with
observation enabled on the Kafka template and listeners, over Kafka too. A request id is the simple version of the same idea.

## What to log

- **Level by audience**: ERROR = someone must act; WARN = unexpected but handled (a retry, a fallback, a breaker
  opening); INFO = business events and lifecycle (started, order placed); DEBUG = detail for developers.
- Parameterised messages: `log.info("order {} placed", id)`, not string concatenation. Pass the exception last
  to keep the stack trace: `log.error("charge failed for order {}", id, e)`.
- One line per event, with ids (order, user, request), not a narrative across five lines.
- Log a failure once, where it's handled, not at every layer it passes through.

## What never to log

Passwords, tokens, API keys, session ids, full card numbers, personal data (names, emails, addresses) unless your
policy allows and masks it. Log ids, not people. Request bodies only when scrubbed.

## Learn by doing

1. Add the filter; make two concurrent requests; filter the JSON logs to one of them with `jq`.
2. Move part of the work to an executor; see the id disappear; add a `TaskDecorator`; see it come back.
3. Find one place that logs and rethrows; make it log once.
