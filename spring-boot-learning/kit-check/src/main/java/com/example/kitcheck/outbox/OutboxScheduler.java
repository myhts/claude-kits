package com.example.kitcheck.outbox;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "kit.outbox.relay.enabled", havingValue = "true")
class OutboxScheduler {

    private final OutboxRelay relay;

    OutboxScheduler(OutboxRelay relay) {
        this.relay = relay;
    }

    @Scheduled(fixedDelayString = "${kit.outbox.relay.delay:500ms}")
    void drain() {
        while (relay.publishBatch(100) == 100) {
            // a full batch: there may be more, keep going
        }
    }
}
