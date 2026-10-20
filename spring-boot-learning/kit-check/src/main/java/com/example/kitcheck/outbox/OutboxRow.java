package com.example.kitcheck.outbox;

public record OutboxRow(long id, String topic, String messageKey, String payload) {
}
