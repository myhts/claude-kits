package com.example.kitcheck.transactions;

import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/** Stands in for an email sender: records what it "sent" and when. */
@Component
public class ConfirmationEmails {

    final List<String> sent = new CopyOnWriteArrayList<>();

    @EventListener
    void sendImmediately(OrderService.OrderPlaced event) {
        sent.add("immediately: " + event.item());              // runs inside the publisher's transaction
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void sendAfterCommit(OrderService.OrderPlaced event) {
        sent.add("after commit: " + event.item());             // runs only if the transaction commits
    }
}
