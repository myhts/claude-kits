package com.example.kitcheck.transactions;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "tx_order")
public class TxOrder {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String item;

    protected TxOrder() {
    }

    public TxOrder(String item) {
        this.item = item;
    }

    public Long getId() { return id; }
    public String getItem() { return item; }
    public void setItem(String item) { this.item = item; }
}
