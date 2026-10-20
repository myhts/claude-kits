package com.example.kitcheck.transactions;

import org.springframework.data.jpa.repository.JpaRepository;

public interface TxCustomerRepository extends JpaRepository<TxCustomer, Long> {
}
