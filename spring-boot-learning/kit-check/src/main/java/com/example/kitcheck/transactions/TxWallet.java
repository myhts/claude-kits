package com.example.kitcheck.transactions;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "tx_wallet")
public class TxWallet {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long balance;

    protected TxWallet() {
    }

    public TxWallet(Long balance) {
        this.balance = balance;
    }

    public Long getId() { return id; }
    public Long getBalance() { return balance; }
    public void setBalance(Long balance) { this.balance = balance; }
}
