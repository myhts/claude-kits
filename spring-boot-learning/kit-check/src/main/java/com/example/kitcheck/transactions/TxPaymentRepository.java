package com.example.kitcheck.transactions;

import org.springframework.data.jpa.repository.JpaRepository;

public interface TxPaymentRepository extends JpaRepository<TxPayment, Long> {
}
