package com.example.kitcheck.outbox;

import java.util.concurrent.CompletableFuture;

/** Sends one message; the future completes when the broker has acknowledged it. */
public interface OutboxPublisher {

    CompletableFuture<?> publish(String topic, String key, String payload);
}
