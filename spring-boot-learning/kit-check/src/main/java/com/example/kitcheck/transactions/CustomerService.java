package com.example.kitcheck.transactions;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Dirty checking: a managed entity's changes are flushed at commit, with or without save(). */
@Service
public class CustomerService {

    private final TxCustomerRepository customers;

    public CustomerService(TxCustomerRepository customers) {
        this.customers = customers;
    }

    @Transactional
    public void changeEmail(Long id, String email) {
        customers.findById(id).orElseThrow().setEmail(email);      // no save(): the change is still persisted
    }

    @Transactional(readOnly = true)
    public void changeEmailReadOnly(Long id, String email) {
        customers.findById(id).orElseThrow().setEmail(email);      // read-only: Hibernate never flushes it
    }
}
