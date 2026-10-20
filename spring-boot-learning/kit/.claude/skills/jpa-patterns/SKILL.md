---
name: jpa-patterns
description: JPA/Hibernate 7 pitfalls made visible - N+1 (and how to count queries in a test), lazy loading, fetch joins and entity graphs, optimistic locking, self-invocation, open-in-view. Verified on Boot 4.1.1 with Postgres. Use when writing entities/repositories or debugging slow or surprising queries.
---

# JPA patterns, with proof

Each pitfall below has a test that shows it (verified on Spring Boot 4.1.1, Hibernate 7, Postgres 16, 2026-10-17).
The lesson is the measurement as much as the fix: **count the queries**.

## Count queries in a test

```java
@DataJpaTest(properties = "spring.jpa.properties.hibernate.generate_statistics=true")
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({PostgresTestcontainer.class, AuthorService.class})
@Transactional(propagation = Propagation.NOT_SUPPORTED)   // each call runs in its own transaction, like production
class JpaPitfallsTest {
    @Autowired EntityManagerFactory emf;
    Statistics stats;   // stats = emf.unwrap(SessionFactory.class).getStatistics(); stats.clear();

    @Test
    void lazyCollectionInALoopIsNPlusOne() {
        service.listNaive();                                          // 3 authors
        assertThat(stats.getPrepareStatementCount()).isEqualTo(1 + 3);
    }
}
```

In development, `spring.jpa.show-sql=true` (or `logging.level.org.hibernate.SQL=debug`) shows every statement.

## N+1

```java
// 1 query for authors, then 1 per author when its lazy books are touched
authors.findAll().stream().map(AuthorSummary::from).toList();
```

Fixes, each measured at **1 statement**:

```java
@EntityGraph(attributePaths = "books")
List<Author> findAllByOrderByIdAsc();

@Query("select distinct a from Author a left join fetch a.books order by a.id")
List<Author> findAllWithBooksJoinFetch();
```

Or a DTO projection when you need a few columns. Don't paginate a collection fetch join (Hibernate pages in memory);
page the parents, then fetch children with `where author_id in (:ids)` (or `@BatchSize`).

## Fetch types

`@OneToMany` / `@ManyToMany` are LAZY by default; **`@ManyToOne` and `@OneToOne` are EAGER by default**: always write
`@ManyToOne(fetch = FetchType.LAZY)`. Decide what to fetch per use case (graph, join fetch, projection), not per entity.

## Lazy loading outside a transaction

With `spring.jpa.open-in-view: false` (recommended), touching a lazy collection after the service returns throws
`LazyInitializationException`. That's the point: it forces the service to fetch what the response needs. Return DTOs.

## Optimistic locking

```java
@Version
private long version;   // UPDATE … where id=? and version=?
```

Two users load version 0; the first save makes it 1; the second save fails with
`ObjectOptimisticLockingFailureException` instead of silently overwriting (verified). Turn it into **409 Conflict**
for the client. Use pessimistic locks (`@Lock(PESSIMISTIC_WRITE)`, `for update`) only for short, contended critical
sections such as allocating a number.

## Self-invocation

(All the proxy and propagation traps, with tests, are in the `transactions` skill.)

```java
public boolean callsInnerViaThis() { return inner(); }   // no transaction (verified)

@Transactional
public boolean inner() { … }                              // called from another bean: transaction active
```

Spring's transactions are a proxy around the bean; `this.inner()` skips the proxy. Move the method to another bean
or put the transaction on the outer method. Same for `@Async`, `@Cacheable`, `@Retryable`.

## Schema

Let Flyway own the schema and set `ddl-auto: validate`. Postgres doesn't index foreign keys automatically: add an
index on every FK you join or filter on. Use `generated always as identity` (and `GenerationType.IDENTITY`) or
sequences with a pooled optimizer for batch inserts.

## Learn by doing

1. Reproduce N+1 with 3 parents, count the statements, then fix it two ways and count again.
2. Write the optimistic-locking test, then map the exception to a 409 problem detail.
3. Write the self-invocation test; then fix it by moving the method; explain why the test changes.
