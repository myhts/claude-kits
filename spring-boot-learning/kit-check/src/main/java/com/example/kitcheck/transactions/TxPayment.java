package com.example.kitcheck.transactions;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "tx_payment")
public class TxPayment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long amount;

    protected TxPayment() {
    }

    public TxPayment(Long amount) {
        this.amount = amount;
    }

    public Long getId() { return id; }
    public Long getAmount() { return amount; }
    public void setAmount(Long amount) { this.amount = amount; }
}
