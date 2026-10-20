package com.example.kitcheck.catalog;

import com.example.kitcheck.support.PostgresTestcontainer;
import jakarta.persistence.EntityManagerFactory;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.context.annotation.Import;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Each JPA pitfall from the jpa-patterns skill, made visible with Hibernate's statement counter. */
@DataJpaTest(properties = "spring.jpa.properties.hibernate.generate_statistics=true")
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({PostgresTestcontainer.class, AuthorService.class})
@Transactional(propagation = Propagation.NOT_SUPPORTED)   // each call below runs in its own transaction, like production
class JpaPitfallsTest {

    @Autowired AuthorService service;
    @Autowired AuthorRepository authors;
    @Autowired BookRepository books;
    @Autowired EntityManagerFactory emf;
    @Autowired PlatformTransactionManager txManager;
    Statistics stats;

    @BeforeEach
    void threeAuthorsWithTwoBooksEach() {
        books.deleteAll();
        authors.deleteAll();
        for (String name : new String[] {"Ada", "Grace", "Barbara"}) {
            Author a = new Author(name);
            a.addBook(name + " vol 1");
            a.addBook(name + " vol 2");
            authors.save(a);
        }
        stats = emf.unwrap(SessionFactory.class).getStatistics();
        stats.clear();
    }

    @Test
    void lazyCollectionInALoopIsNPlusOne() {
        assertThat(service.listNaive()).hasSize(3);
        assertThat(stats.getPrepareStatementCount()).isEqualTo(1 + 3);   // 1 for authors + 1 per author's books
    }

    @Test
    void entityGraphFetchesEverythingInOneQuery() {
        assertThat(service.listFetched()).allSatisfy(a -> assertThat(a.titles()).hasSize(2));
        assertThat(stats.getPrepareStatementCount()).isEqualTo(1);
    }

    @Test
    void joinFetchDoesTheSame() {
        new TransactionTemplate(txManager).executeWithoutResult(s ->
                assertThat(authors.findAllWithBooksJoinFetch()).allSatisfy(a -> assertThat(a.getBooks()).hasSize(2)));
        assertThat(stats.getPrepareStatementCount()).isEqualTo(1);
    }

    @Test
    void aStaleUpdateFailsInsteadOfOverwriting() {
        Long id = books.findAll().getFirst().getId();
        Book first = books.findById(id).orElseThrow();    // two users load version 0
        Book second = books.findById(id).orElseThrow();
        first.setTitle("edited by user 1");
        books.save(first);                                 // version 0 → 1
        second.setTitle("edited by user 2");
        assertThatThrownBy(() -> books.save(second))       // still version 0: rejected
                .isInstanceOf(ObjectOptimisticLockingFailureException.class);
    }

    @Test
    void selfInvocationSkipsTheTransaction() {
        assertThat(service.inner()).isTrue();               // through the proxy: a read-write transaction
        assertThat(service.callsInnerViaThis()).isFalse();  // via `this`: @Transactional on inner() is ignored
    }
}
