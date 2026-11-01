package com.example.claims;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/** Pays approved claims. In this demo it records the payment instruction. */
@Service
public class PaymentService {

    private static final Logger log = LoggerFactory.getLogger(PaymentService.class);

    public record Payment(String claimId, double amount, String currency) { }

    private final List<Payment> instructions = new CopyOnWriteArrayList<>();

    public void pay(String claimId, double amount, String currency) {
        instructions.add(new Payment(claimId, amount, currency));
        log.info("payment instructed claim={} amount={} {}", claimId, amount, currency);
    }

    public List<Payment> instructions() {
        return List.copyOf(instructions);
    }
}
