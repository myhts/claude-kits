package com.example.kitcheck.transactions;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Inner bean B: joins A's transaction (REQUIRED), then fails. */
@Service
public class PaymentStep {

    private final TxPaymentRepository payments;

    public PaymentStep(TxPaymentRepository payments) {
        this.payments = payments;
    }

    @Transactional
    public void charge(String item) {
        payments.save(new TxPayment(100L));
        throw new IllegalStateException("card declined for " + item);
    }
}
