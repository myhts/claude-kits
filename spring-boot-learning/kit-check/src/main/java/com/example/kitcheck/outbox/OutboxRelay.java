package com.example.kitcheck.outbox;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/**
 * Transactional outbox. The business write and {@link #append} share one transaction, so the event exists if and only
 * if the change does. {@link #publishBatch} sends a batch and marks it published only after the broker acknowledged
 * every message. Delivery is at-least-once (a crash between the ack and the commit re-sends), so consumers must be
 * idempotent.
 */
@Component
public class OutboxRelay {

    private static final Duration ACK_TIMEOUT = Duration.ofSeconds(10);

    private final JdbcClient jdbc;
    private final OutboxPublisher publisher;

    public OutboxRelay(JdbcClient jdbc, OutboxPublisher publisher) {
        this.jdbc = jdbc;
        this.publisher = publisher;
    }

    /** MANDATORY: fails fast if someone calls it outside the business transaction (which would break atomicity). */
    @Transactional(propagation = Propagation.MANDATORY)
    public void append(String topic, String key, String payload) {
        jdbc.sql("insert into outbox (topic, message_key, payload) values (:topic, :key, :payload)")
                .param("topic", topic).param("key", key).param("payload", payload)
                .update();
    }

    /**
     * Claims up to {@code max} unpublished rows. SKIP LOCKED lets several relay instances run at once without
     * blocking each other or sending the same row twice. LIMIT keeps the batch (and the lock time) bounded.
     */
    @Transactional
    public int publishBatch(int max) {
        List<OutboxRow> rows = jdbc.sql("""
                        select id, topic, message_key, payload from outbox
                        where published_at is null
                        order by id
                        limit :max
                        for update skip locked""")
                .param("max", max)
                .query(OutboxRow.class)
                .list();
        if (rows.isEmpty()) {
            return 0;
        }
        CompletableFuture<?>[] acks = rows.stream()
                .map(r -> publisher.publish(r.topic(), r.messageKey(), r.payload()))
                .toArray(CompletableFuture[]::new);
        try {
            CompletableFuture.allOf(acks).get(ACK_TIMEOUT.toMillis(), TimeUnit.MILLISECONDS);
        } catch (ExecutionException | TimeoutException e) {
            throw new OutboxPublishFailed(e);   // rollback: the rows stay unpublished and are retried next time
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new OutboxPublishFailed(e);
        }
        jdbc.sql("update outbox set published_at = now() where id in (:ids)")
                .param("ids", rows.stream().map(OutboxRow::id).toList())
                .update();
        return rows.size();
    }

    public static class OutboxPublishFailed extends RuntimeException {
        OutboxPublishFailed(Throwable cause) {
            super("outbox batch not acknowledged; it will be retried", cause);
        }
    }
}
