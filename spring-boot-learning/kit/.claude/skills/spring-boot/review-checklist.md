# Review checklist: Spring pack

The `code-reviewer` agent applies this on its standards axis for a Spring Boot project, next to the repo's
`CODING_STANDARDS.md` (the project's own rules win where they disagree). Report only what you can point to at
`file:line`. Priority order:

## Correctness and data integrity

- Transaction boundaries: multi-step writes in one transaction; `@Transactional` reached through the proxy (not via
  `this`); no remote calls (HTTP, broker) inside a database transaction unless deliberate; read-only where only reading.
  See the `transactions` skill.
- Concurrency: lost updates (missing `@Version` or a conditional update), check-then-act races, unique constraints for
  things that must be unique, idempotency of anything a client or broker may retry.
- Exceptions: no empty or over-broad catches, cause kept, a clear error response (problem details) for clients.
- Null handling at boundaries; `Optional` as a return type only.

## Security

Validation on every external input (`@Valid`, bounded sizes); authorization checked per resource (not just "logged
in"); no secrets in code or config; no SQL/JPQL built by string concatenation; no entities or stack traces in responses;
no personal data in logs.

## Performance

N+1 queries (lazy collections in loops; see `jpa-patterns`), unbounded queries without paging, missing indexes on
filtered/joined columns and foreign keys, missing timeouts on outbound calls (see `resilience-patterns`), work done per
request that could be done once.

## Tests

The new behaviour has a test that would fail without it; negative cases (invalid input, not found, conflict); the right
test slice (unit, `@WebMvcTest`, `@DataJpaTest`, `@SpringBootTest` with Testcontainers; see `testing-patterns`);
`@MockitoBean`, not `@MockBean` (removed in Boot 4).

## Code that calls a model

When the diff uses `com.anthropic` or another LLM SDK, or builds prompts, also apply
`../../../../kit-ai/.claude/skills/llm-engineering/review-checklist.md` (installed projects: `.claude/skills/llm-engineering/review-checklist.md`).
The most common misses: reading the content before the stop reason, untrusted text in the system prompt, and model
output used without validation.

## Readability

Names that say what and why, small methods, no dead code, comments that explain *why*.

## Spring Boot 4 facts for checking imports

`@WebMvcTest` is in `org.springframework.boot.webmvc.test.autoconfigure`, `@DataJpaTest` in
`org.springframework.boot.data.jpa.test.autoconfigure`, `@AutoConfigureTestDatabase` in
`org.springframework.boot.jdbc.test.autoconfigure`, `@AutoConfigureRestTestClient` in
`org.springframework.boot.resttestclient.autoconfigure`; Testcontainers 2 uses
`org.testcontainers.postgresql.PostgreSQLContainer`. `@DynamicPropertySource` is right when `@ServiceConnection` can't
express the wiring (e.g. several datasources); don't flag it then.
