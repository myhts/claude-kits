package com.example.kitcheck.transactions;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/** The same wallet with @Version: a stale write fails instead of silently overwriting. */
@Entity
@Table(name = "tx_versioned_wallet")
public class TxVersionedWallet {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long balance;

    @Version
    private Long version;

    protected TxVersionedWallet() {
    }

    public TxVersionedWallet(Long balance) {
        this.balance = balance;
    }

    public Long getId() { return id; }
    public Long getBalance() { return balance; }
    public void setBalance(Long balance) { this.balance = balance; }
}
