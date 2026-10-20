---
name: testing-patterns
description: Testing a Spring Boot 4 app - which test type for what, @WebMvcTest with @MockitoBean, @DataJpaTest and @SpringBootTest against real Postgres via Testcontainers 2 and @ServiceConnection, RestTestClient, capturing log output. Verified on Boot 4.1.1. Use when writing or reviewing tests.
---

# Testing patterns (Spring Boot 4)

Verified on Spring Boot 4.1.1 + Testcontainers 2 (2026-10-17): every snippet below ran green.

## Which test for what

| Question the test answers | Test type | Starts | Speed |
|---|---|---|---|
| Is the rule right? (pure logic) | plain JUnit, no Spring | nothing | ms |
| Does HTTP map, validate and serialise right? | `@WebMvcTest(Controller.class)` + `@MockitoBean` service | MVC only | ~1 s |
| Do my queries/mappings work on the real database? | `@DataJpaTest` (or `@JdbcTest`) + Testcontainers | JPA + DB | seconds |
| Does the whole thing work together? | `@SpringBootTest(webEnvironment = RANDOM_PORT)` + Testcontainers | everything | seconds |

Many fast tests at the bottom, a few full ones at the top. Test **behaviour** (status codes, rows, messages), not
which private methods were called. Every feature needs at least one negative test (invalid, not found, conflict).

## A real database, one line of wiring

```java
@TestConfiguration(proxyBeanMethods = false)
public class PostgresTestcontainer {
    @Bean
    @ServiceConnection   // sets the datasource URL, user, password: no properties needed
    PostgreSQLContainer postgres() {
        return new PostgreSQLContainer("postgres:16-alpine");   // org.testcontainers.postgresql (Testcontainers 2)
    }
}
```

Use the same database engine as production: H2 hides real behaviour (locking, `SKIP LOCKED`, JSON types, SQL dialect).
`@DynamicPropertySource` is still right when `@ServiceConnection` can't express it (e.g. two datasources).

## Web slice

```java
@WebMvcTest(AuthorController.class)                        // org.springframework.boot.webmvc.test.autoconfigure
@Import({ApiExceptionHandler.class, RequestIdFilter.class})
class AuthorControllerTest {
    @Autowired MockMvc mvc;
    @MockitoBean AuthorService service;                    // @MockBean no longer exists in Boot 4

    @Test
    void blankNameIs400WithTheFieldNamed() throws Exception {
        mvc.perform(post("/api/v1/authors").contentType(MediaType.APPLICATION_JSON).content("""
                        {"name":" "}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fields.name").exists());
        verifyNoInteractions(service);                     // rejected before reaching the service
    }
}
```

## Repository slice on real Postgres

```java
@DataJpaTest                                               // org.springframework.boot.data.jpa.test.autoconfigure
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)   // keep the Testcontainers DB
@Import(PostgresTestcontainer.class)
class AuthorRepositoryTest { … }
```

`@DataJpaTest` wraps each test in a transaction that rolls back. That hides behaviour that only appears across
transactions (optimistic locking, lazy loading after the transaction, `SKIP LOCKED`). For those, annotate the class
with `@Transactional(propagation = Propagation.NOT_SUPPORTED)` and clean up yourself.

## Full app over HTTP, plus the logs

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient                               // org.springframework.boot.resttestclient.autoconfigure
@Import(PostgresTestcontainer.class)
@ExtendWith(OutputCaptureExtension.class)
class AuthorApiIT {
    @Autowired RestTestClient client;                      // org.springframework.test.web.servlet.client

    @Test
    void createThenList(CapturedOutput output) {
        client.post().uri("/api/v1/authors").contentType(MediaType.APPLICATION_JSON)
                .header("X-Request-Id", "it-req-1").body("{\"name\":\"Ada\"}")
                .exchange().expectStatus().isCreated();
        assertThat(output.getOut()).contains("\"requestId\":\"it-req-1\"");   // the request id is on the log line
    }
}
```

Name full-app tests `*IT` and run them with the failsafe plugin (`./mvnw verify`), unit tests with surefire.

## Tests that prove concurrency

Two threads, a `CyclicBarrier` to make them overlap, and assertions on the outcome (no duplicates, nothing lost).
Then **remove the protection and watch the test fail**: a test that passes either way proves nothing. (The kit's
outbox test fails without `SKIP LOCKED` and passes with it.)

## Learn by doing

1. For one endpoint: write the 201, 400 and 404 tests first, then make them pass.
2. Write a `@DataJpaTest` that fails on H2 but passes on Postgres (hint: `for update skip locked`, or a JSON column).
3. Run the mutation tester (`pitest-maven`) once on a service; read which mutants survived and why.
