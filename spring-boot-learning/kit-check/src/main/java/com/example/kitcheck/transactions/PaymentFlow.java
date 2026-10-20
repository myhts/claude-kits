package com.example.kitcheck.transactions;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Outer bean A for the rollback-only trap: it swallows inner bean B's exception and returns normally. */
@Service
public class PaymentFlow {

    private final TxOrderRepository orders;
    private final PaymentStep payment;

    public PaymentFlow(TxOrderRepository orders, PaymentStep payment) {
        this.orders = orders;
        this.payment = payment;
    }

    @Transactional
    public void placeAndSwallowPaymentFailure(String item) {
        orders.save(new TxOrder(item));
        try {
            payment.charge(item);
        } catch (IllegalStateException swallowed) {
            // B's proxy already marked the shared transaction rollback-only
        }
    }
}
