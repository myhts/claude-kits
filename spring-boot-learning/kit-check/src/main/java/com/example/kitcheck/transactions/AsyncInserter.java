package com.example.kitcheck.transactions;

import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

/** Runs on another thread (needs @EnableAsync). Transactions are bound to a thread, so it can't join the caller's. */
@Service
public class AsyncInserter {

    private final TxOrderRepository orders;

    public AsyncInserter(TxOrderRepository orders) {
        this.orders = orders;
    }

    @Async
    public CompletableFuture<Void> insert(String item) {
        orders.save(new TxOrder(item));
        return CompletableFuture.completedFuture(null);
    }
}
