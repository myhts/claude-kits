package com.example.kitcheck.transactions;

import org.springframework.data.jpa.repository.JpaRepository;

public interface TxVersionedWalletRepository extends JpaRepository<TxVersionedWallet, Long> {
}
