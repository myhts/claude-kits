package com.example.kitcheck.outbox;

import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

import java.util.concurrent.CompletableFuture;

@Component
public class KafkaOutboxPublisher implements OutboxPublisher {

    private final KafkaTemplate<String, String> kafka;

    public KafkaOutboxPublisher(KafkaTemplate<String, String> kafka) {
        this.kafka = kafka;
    }

    @Override
    public CompletableFuture<?> publish(String topic, String key, String payload) {
        return kafka.send(topic, key, payload);   // completes on the broker's ack (acks=all is the producer default)
    }
}
