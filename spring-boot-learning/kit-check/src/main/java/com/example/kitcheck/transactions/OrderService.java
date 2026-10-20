package com.example.kitcheck.transactions;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.io.IOException;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.atomic.AtomicReference;

/**
 * The @Transactional traps, one method each. Proved in TransactionTrapsTest; explained in the transactions skill.
 * The bean has no interface, so Spring proxies it with a CGLIB subclass (Boot's default).
 */
@Service
public class OrderService {

    private final TxOrderRepository orders;
    private final TxPaymentRepository payments;
    private final TxAuditRepository audits;
    private final AuditService auditService;
    private final AsyncInserter asyncInserter;
    private final ApplicationEventPublisher events;

    public OrderService(TxOrderRepository orders, TxPaymentRepository payments, TxAuditRepository audits,
                        AuditService auditService, AsyncInserter asyncInserter, ApplicationEventPublisher events) {
        this.orders = orders;
        this.payments = payments;
        this.audits = audits;
        this.auditService = auditService;
        this.asyncInserter = asyncInserter;
        this.events = events;
    }

    // ---- rollback rules: only unchecked exceptions roll back by default
    @Transactional
    public void placeThenThrowChecked(String item) throws IOException {
        orders.save(new TxOrder(item));
        throw new IOException("disk full");
    }

    @Transactional(rollbackFor = Exception.class)
    public void placeThenThrowCheckedWithRollbackFor(String item) throws IOException {
        orders.save(new TxOrder(item));
        throw new IOException("disk full");
    }

    // ---- self-invocation: this.audit() never passes through the proxy, so REQUIRES_NEW is ignored
    @Transactional
    public void placeWithSelfAudit(String item) {
        orders.save(new TxOrder(item));
        audit("placed " + item);                 // same transaction as the order
        throw new IllegalStateException("payment declined");
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void audit(String message) {
        audits.save(new TxAudit(message));
    }

    @Transactional
    public void placeWithAuditBean(String item) {
        orders.save(new TxOrder(item));
        auditService.audit("placed " + item);    // through another bean's proxy: a real new transaction
        throw new IllegalStateException("payment declined");
    }

    // ---- private and final methods: the proxy can't intercept them
    public boolean callsPrivateTransactional() {
        return privateTransactional();
    }

    @Transactional
    private boolean privateTransactional() {
        return TransactionSynchronizationManager.isActualTransactionActive();
    }

    @Transactional
    public final boolean finalTransactional() {
        return TransactionSynchronizationManager.isActualTransactionActive();
    }

    @Transactional
    public final long finalUsingARepository() {
        return orders.count();                   // runs on the proxy instance, whose fields were never injected
    }

    // ---- no @Transactional: each repository call commits on its own
    public void placeThenFailPayment(String item) {
        orders.save(new TxOrder(item));
        payments.save(new TxPayment(null));      // amount is NOT NULL: this save throws
    }

    // ---- @Async: the other thread has its own transaction (or none)
    @Transactional
    public void placeThenFailAfterAsync(String item, AtomicReference<CompletableFuture<Void>> started) {
        orders.save(new TxOrder(item));
        started.set(asyncInserter.insert(item + "-async"));
        throw new IllegalStateException("payment declined");
    }

    // ---- events: a plain @EventListener runs now, inside the transaction; AFTER_COMMIT waits for the commit
    @Transactional
    public void placeAndPublish(String item, boolean failAfterPublishing) {
        orders.save(new TxOrder(item));
        events.publishEvent(new OrderPlaced(item));
        if (failAfterPublishing) {
            throw new IllegalStateException("payment declined");
        }
    }

    public record OrderPlaced(String item) {
    }
}
