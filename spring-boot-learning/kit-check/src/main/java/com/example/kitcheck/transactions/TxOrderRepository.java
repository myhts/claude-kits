package com.example.kitcheck.transactions;

import org.springframework.data.jpa.repository.JpaRepository;

public interface TxOrderRepository extends JpaRepository<TxOrder, Long> {
}
