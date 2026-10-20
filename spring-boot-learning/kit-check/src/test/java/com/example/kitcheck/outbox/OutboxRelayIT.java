package com.example.kitcheck.outbox;

import com.example.kitcheck.catalog.AuthorEvents;
import com.example.kitcheck.support.PostgresTestcontainer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.IllegalTransactionStateException;

import java.util.List;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** The outbox, proven: atomic with the business write, no double send across relays, nothing lost on a failed send. */
@SpringBootTest
@Import({PostgresTestcontainer.class, OutboxRelayIT.FakeBroker.class})
class OutboxRelayIT {

    @Autowired OutboxRelay relay;
    @Autowired AuthorEvents events;
    @Autowired JdbcClient jdbc;
    @Autowired FakeBroker broker;

    @BeforeEach
    void clean() {
        jdbc.sql("delete from outbox").update();
        jdbc.sql("delete from book").update();
        jdbc.sql("delete from author").update();
        broker.reset();
    }

    @Test
    void theEventIsWrittenInTheBusinessTransaction() {
        long id = events.register("Ada");
        assertThat(jdbc.sql("select message_key from outbox").query(String.class).list()).containsExactly(String.valueOf(id));
    }

    @Test
    void appendOutsideATransactionIsRefused() {
        assertThatThrownBy(() -> relay.append("authors", "1", "{}")).isInstanceOf(IllegalTransactionStateException.class);
    }

    @Test
    void twoRelaysAtOnceNeverSendTheSameRow() throws Exception {
        for (int i = 0; i < 10; i++) events.register("author " + i);
        broker.holdFirstSendOfEachThreadUntil(new CyclicBarrier(2));   // both relays hold their locks at the same time

        var pool = Executors.newFixedThreadPool(2);
        Future<Integer> a = pool.submit(() -> relay.publishBatch(5));
        Future<Integer> b = pool.submit(() -> relay.publishBatch(5));
        assertThat(a.get(10, TimeUnit.SECONDS) + b.get(10, TimeUnit.SECONDS)).isEqualTo(10);
        pool.shutdown();

        assertThat(broker.sentKeys()).hasSize(10).doesNotHaveDuplicates();   // without SKIP LOCKED: b blocks on a's rows, the barrier times out
        assertThat(jdbc.sql("select count(*) from outbox where published_at is null").query(Long.class).single()).isZero();
    }

    @Test
    void aFailedSendLeavesTheRowsForTheNextRun() {
        events.register("Ada");
        broker.failNextSends();
        assertThatThrownBy(() -> relay.publishBatch(10)).isInstanceOf(OutboxRelay.OutboxPublishFailed.class);
        assertThat(jdbc.sql("select count(*) from outbox where published_at is null").query(Long.class).single()).isEqualTo(1);

        broker.reset();
        assertThat(relay.publishBatch(10)).isEqualTo(1);   // retried: at-least-once
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class FakeBroker {

        private final List<String> sent = new CopyOnWriteArrayList<>();
        private final Set<Thread> waited = ConcurrentHashMap.newKeySet();
        private volatile CyclicBarrier barrier;
        private volatile boolean fail;

        @Bean
        @Primary
        OutboxPublisher fakePublisher() {
            return (topic, key, payload) -> {
                if (fail) return CompletableFuture.failedFuture(new IllegalStateException("broker down"));
                if (barrier != null && waited.add(Thread.currentThread())) {
                    try {
                        barrier.await(5, TimeUnit.SECONDS);
                    } catch (Exception e) {
                        return CompletableFuture.failedFuture(e);
                    }
                }
                sent.add(key);
                return CompletableFuture.completedFuture(null);
            };
        }

        @Bean
        FakeBroker broker() {
            return this;
        }

        void holdFirstSendOfEachThreadUntil(CyclicBarrier b) { barrier = b; }
        void failNextSends() { fail = true; }
        List<String> sentKeys() { return sent; }
        void reset() { sent.clear(); waited.clear(); barrier = null; fail = false; }
    }
}
