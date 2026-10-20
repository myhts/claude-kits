package com.example.kitcheck.transactions;

import com.example.kitcheck.support.PostgresTestcontainer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.transaction.UnexpectedRollbackException;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Every claim in the transactions skill, proved against a real Postgres. Each test is one interview question; its
 * name is the answer. Predict first, then read the assertion.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({PostgresTestcontainer.class, TransactionTrapsTest.Beans.class})
@Transactional(propagation = Propagation.NOT_SUPPORTED)   // no test-managed transaction: each call commits or rolls back for real
class TransactionTrapsTest {

    @TestConfiguration(proxyBeanMethods = false)
    @EnableAsync
    @Import({OrderService.class, AuditService.class, AsyncInserter.class, ConfirmationEmails.class, PaymentFlow.class,
            PaymentStep.class, CustomerService.class, IsolationService.class, IsolationCaller.class, WalletService.class})
    static class Beans {
    }

    @Autowired OrderService orders;
    @Autowired PaymentFlow paymentFlow;
    @Autowired CustomerService customerService;
    @Autowired IsolationService isolation;
    @Autowired IsolationCaller isolationCaller;
    @Autowired WalletService walletService;
    @Autowired ConfirmationEmails emails;
    @Autowired TxOrderRepository orderRows;
    @Autowired TxPaymentRepository paymentRows;
    @Autowired TxAuditRepository auditRows;
    @Autowired TxCustomerRepository customerRows;
    @Autowired TxWalletRepository walletRows;
    @Autowired TxVersionedWalletRepository versionedWalletRows;

    @BeforeEach
    void emptyTables() {
        orderRows.deleteAll();
        paymentRows.deleteAll();
        auditRows.deleteAll();
        customerRows.deleteAll();
        walletRows.deleteAll();
        versionedWalletRows.deleteAll();
        emails.sent.clear();
    }

    // ---- rollback rules

    @Test
    void aCheckedExceptionCommits() {
        assertThatThrownBy(() -> orders.placeThenThrowChecked("o1")).isInstanceOf(IOException.class);
        assertThat(orderRows.count()).isEqualTo(1);              // default: roll back on RuntimeException and Error only
    }

    @Test
    void rollbackForMakesACheckedExceptionRollBack() {
        assertThatThrownBy(() -> orders.placeThenThrowCheckedWithRollbackFor("o1")).isInstanceOf(IOException.class);
        assertThat(orderRows.count()).isZero();
    }

    // ---- proxies

    @Test
    void selfInvocationIgnoresRequiresNewSoOneTransactionRollsBackBoth() {
        assertThatThrownBy(() -> orders.placeWithSelfAudit("o1")).isInstanceOf(IllegalStateException.class);
        assertThat(orderRows.count()).isZero();
        assertThat(auditRows.count()).isZero();                  // the audit was part of the same, rolled-back transaction
    }

    @Test
    void requiresNewThroughAnotherBeanSurvivesTheOuterRollback() {
        assertThatThrownBy(() -> orders.placeWithAuditBean("o1")).isInstanceOf(IllegalStateException.class);
        assertThat(orderRows.count()).isZero();
        assertThat(auditRows.count()).isEqualTo(1);              // two transactions: the audit committed on its own
    }

    @Test
    void aPrivateTransactionalMethodHasNoTransaction() {
        assertThat(orders.callsPrivateTransactional()).isFalse();
    }

    @Test
    void aFinalTransactionalMethodHasNoTransaction() {
        assertThat(orders.finalTransactional()).isFalse();       // CGLIB can't override a final method
    }

    @Test
    void aFinalMethodRunsOnTheProxyWhoseFieldsAreNull() {
        assertThatThrownBy(() -> orders.finalUsingARepository()).isInstanceOf(NullPointerException.class);
    }

    // ---- what commits

    @Test
    void withoutTransactionalEachSaveCommitsOnItsOwn() {
        assertThatThrownBy(() -> orders.placeThenFailPayment("o1")).isInstanceOf(DataIntegrityViolationException.class);
        assertThat(orderRows.count()).isEqualTo(1);              // the order stays: no transaction tied the two saves
    }

    @Test
    void swallowingAnInnerFailureStillRollsBackEverything() {
        assertThatThrownBy(() -> paymentFlow.placeAndSwallowPaymentFailure("o1"))
                .isInstanceOf(UnexpectedRollbackException.class); // the shared transaction was marked rollback-only
        assertThat(orderRows.count()).isZero();
        assertThat(paymentRows.count()).isZero();
    }

    @Test
    void aChangedManagedEntityIsSavedWithoutCallingSave() {
        Long id = customerRows.save(new TxCustomer("old@example.com")).getId();
        customerService.changeEmail(id, "new@example.com");
        assertThat(customerRows.findById(id).orElseThrow().getEmail()).isEqualTo("new@example.com");
    }

    @Test
    void inAReadOnlyTransactionTheChangeIsNotSaved() {
        Long id = customerRows.save(new TxCustomer("old@example.com")).getId();
        customerService.changeEmailReadOnly(id, "new@example.com");
        assertThat(customerRows.findById(id).orElseThrow().getEmail()).isEqualTo("old@example.com");
    }

    // ---- threads and events

    @Test
    void anAsyncInsertIsNotRolledBackWithTheCaller() throws Exception {
        AtomicReference<CompletableFuture<Void>> async = new AtomicReference<>();
        assertThatThrownBy(() -> orders.placeThenFailAfterAsync("o1", async)).isInstanceOf(IllegalStateException.class);
        async.get().get(10, TimeUnit.SECONDS);
        assertThat(orderRows.findAll()).extracting(TxOrder::getItem).containsExactly("o1-async");
    }

    @Test
    void aPlainEventListenerActsEvenWhenTheTransactionRollsBack() {
        assertThatThrownBy(() -> orders.placeAndPublish("o1", true)).isInstanceOf(IllegalStateException.class);
        assertThat(orderRows.count()).isZero();
        assertThat(emails.sent).containsExactly("immediately: o1");    // the customer got an email for an order that doesn't exist
    }

    @Test
    void anAfterCommitListenerActsOnlyAfterACommit() {
        orders.placeAndPublish("o1", false);
        assertThat(emails.sent).containsExactly("immediately: o1", "after commit: o1");
    }

    // ---- isolation and locking

    @Test
    void anIsolationLevelIsIgnoredWhenTheMethodJoinsAnExistingTransaction() {
        assertThat(isolation.serializableAsked()).isEqualTo("serializable");                // starts its own transaction
        assertThat(isolationCaller.callSerializableFromInside()).isEqualTo("read committed");  // joins the caller's
    }

    @Test
    void checkThenActWithoutLockingLetsBothWithdrawalsSucceed() throws Exception {
        Long id = walletRows.save(new TxWallet(500L)).getId();
        CyclicBarrier bothChecked = new CyclicBarrier(2);
        List<Boolean> results = concurrently(() -> walletService.withdrawNaive(id, 400, () -> await(bothChecked)));
        assertThat(results).containsExactly(true, true);         // ₹800 handed out
        assertThat(walletRows.findById(id).orElseThrow().getBalance()).isEqualTo(100L);   // ₹400 recorded: a lost update
    }

    @Test
    void withVersionTheSecondWithdrawalFails() throws Exception {
        Long id = versionedWalletRows.save(new TxVersionedWallet(500L)).getId();
        CyclicBarrier bothChecked = new CyclicBarrier(2);
        List<Object> outcomes = concurrentlyCatching(() -> walletService.withdrawVersioned(id, 400, () -> await(bothChecked)));
        assertThat(outcomes).filteredOn(o -> o instanceof ObjectOptimisticLockingFailureException).hasSize(1);
        assertThat(outcomes).filteredOn(Boolean.TRUE::equals).hasSize(1);
        assertThat(versionedWalletRows.findById(id).orElseThrow().getBalance()).isEqualTo(100L);
    }

    @Test
    void aConditionalUpdateLetsOnlyOneWithdrawalThrough() throws Exception {
        Long id = walletRows.save(new TxWallet(500L)).getId();
        CyclicBarrier start = new CyclicBarrier(2);
        List<Boolean> results = concurrently(() -> {
            await(start);
            return walletService.withdrawConditional(id, 400);
        });
        assertThat(results).containsExactlyInAnyOrder(true, false);
        assertThat(walletRows.findById(id).orElseThrow().getBalance()).isEqualTo(100L);
    }

    // ---- helpers

    private static <T> List<T> concurrently(java.util.concurrent.Callable<T> call) throws Exception {
        try (ExecutorService pool = Executors.newFixedThreadPool(2)) {
            Future<T> a = pool.submit(call);
            Future<T> b = pool.submit(call);
            return List.of(a.get(20, TimeUnit.SECONDS), b.get(20, TimeUnit.SECONDS));
        }
    }

    private static List<Object> concurrentlyCatching(java.util.concurrent.Callable<?> call) throws Exception {
        try (ExecutorService pool = Executors.newFixedThreadPool(2)) {
            List<Future<?>> futures = List.of(pool.submit(call), pool.submit(call));
            return futures.stream().map(f -> {
                try {
                    return (Object) f.get(20, TimeUnit.SECONDS);
                } catch (ExecutionException e) {
                    return e.getCause();
                } catch (Exception e) {
                    throw new IllegalStateException(e);
                }
            }).toList();
        }
    }

    private static void await(CyclicBarrier barrier) {
        try {
            barrier.await(10, TimeUnit.SECONDS);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
