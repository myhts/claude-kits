---
name: spring-boot
description: Spring Boot 4.x essentials verified on 4.1.1 (modular starters, REST with validation and problem details, configuration, transactions, the new test packages). Use when building or explaining Spring Boot application code.
---

# Spring Boot 4 essentials

Every code shape here was compiled and tested on **Spring Boot 4.1.1, Java 21, Hibernate 7, Testcontainers 2**
(2026-10-17). If the project uses another version, check before copying.

## What changed in Boot 4 that trips people up

| Topic | Boot 4 | Common outdated version |
|---|---|---|
| Starters are modular | `spring-boot-starter-webmvc`, `-data-jpa`, `-jdbc`, `-flyway`, `-kafka`, `-validation`; each has a `-test` partner (`spring-boot-starter-webmvc-test`, `-data-jpa-test`, …) | one `spring-boot-starter-test` for everything |
| Mocks in a Spring test | `@MockitoBean` (`org.springframework.test.context.bean.override.mockito`) | `@MockBean` (removed) |
| Test slice packages | `org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest`, `org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest`, `org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase` | `org.springframework.boot.test.autoconfigure.*` |
| HTTP test client | `RestTestClient` + `@AutoConfigureRestTestClient` (`org.springframework.boot.resttestclient.autoconfigure`) | `TestRestTemplate` |
| Testcontainers 2 | `org.testcontainers.postgresql.PostgreSQLContainer` (not generic), artifacts `testcontainers-postgresql`, `testcontainers-junit-jupiter` | `org.testcontainers.containers.PostgreSQLContainer<?>` |
| Jackson 3 | `tools.jackson.databind.*` | `com.fasterxml.jackson.databind.*` (annotations keep `com.fasterxml.jackson.annotation`) |
| Resilience4j | `io.github.resilience4j:resilience4j-spring-boot4` | `-spring-boot3` |

## A REST resource, done properly

```java
@RestController
@RequestMapping("/api/v1/authors")
public class AuthorController {
    private static final Logger log = LoggerFactory.getLogger(AuthorController.class);
    private final AuthorService service;

    public AuthorController(AuthorService service) { this.service = service; }   // constructor injection

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AuthorSummary create(@Valid @RequestBody CreateAuthorRequest request) {
        log.info("creating author with {} titles", request.titles() == null ? 0 : request.titles().size());
        return service.create(request);
    }
}

public record CreateAuthorRequest(@NotBlank @Size(max = 100) String name, List<@NotBlank String> titles) {}
```

- Request and response bodies are **records**, never JPA entities (entities leak fields, trigger lazy loading
  during serialisation, and couple your API to your tables).
- Every external input has bounds (`@Size`, `@Max`, page-size limits).

## Errors: problem details (RFC 9457)

Either turn on Boot's handler (`spring.mvc.problemdetails.enabled: true`) **or** extend
`ResponseEntityExceptionHandler` to customise it; Boot's backs off when yours exists. Don't add a separate
`@ExceptionHandler(MethodArgumentNotValidException.class)` next to Boot's: the two race, and Boot's wins (we hit
exactly this while verifying the kit).

```java
@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {
    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException ex, HttpHeaders headers,
                                                                  HttpStatusCode status, WebRequest request) {
        ProblemDetail problem = ex.getBody();
        problem.setDetail("request is invalid");
        problem.setProperty("fields", ex.getBindingResult().getFieldErrors().stream()
                .collect(Collectors.toMap(FieldError::getField, f -> String.valueOf(f.getDefaultMessage()), (a, b) -> a)));
        return handleExceptionInternal(ex, problem, headers, status, request);
    }
}
```

## Transactions

- Put `@Transactional` on the service method that is the unit of work; `@Transactional(readOnly = true)` on the
  class for read-mostly services, `@Transactional` on the writing methods.
- It works **through the proxy**: calling a `@Transactional` method via `this` starts no transaction (verified:
  see the jpa-patterns skill).
- Don't hold a transaction open across slow remote calls; do the remote call before or after, or use an outbox.
- `spring.jpa.open-in-view: false`: no lazy loading from the web layer; the service returns what the response needs.
- The traps (checked exceptions commit, private/final methods, rollback-only, `@Async`, event listeners, isolation on
  joined transactions, the check-then-act race), each proved by a test: the `transactions` skill.

## Configuration

- Group related settings in a `@ConfigurationProperties` record with validation; `@Value` only for one-offs.
- Defaults in `application.yml`, overrides from environment variables (`SPRING_DATASOURCE_URL`), secrets never in
  the repo.
- A good baseline:

```yaml
spring:
  threads.virtual.enabled: true       # see java-modern before turning this on for consumers and pools
  jpa:
    open-in-view: false
    hibernate.ddl-auto: validate      # Flyway owns the schema
server.shutdown: graceful
logging.structured.format.console: ecs
```

## Architecture

Pick one and keep to it (write it in `CLAUDE.md`):
- **Layered** (controller → service → repository): simplest; fine for CRUD-shaped apps.
- **Hexagonal / modules** (domain + application + adapters in/out, per business module; Spring Modulith can verify
  module boundaries): more ceremony, pays off when business rules are rich or modules must stay independent.

## Learn by doing

1. Build `POST` + `GET` for one resource; write the `@WebMvcTest` for 201 and 400 before the controller.
2. Add the problem-details handler; make a request with two invalid fields and read the response.
3. Turn `open-in-view` on and off; return an entity with a lazy collection; explain what you see.
