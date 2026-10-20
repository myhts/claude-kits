package com.example.kitcheck.transactions;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface TxWalletRepository extends JpaRepository<TxWallet, Long> {

    /** Check and deduct in one statement: the database row lock serialises concurrent callers. Returns rows changed. */
    @Modifying
    @Query("update TxWallet w set w.balance = w.balance - :amount where w.id = :id and w.balance >= :amount")
    int withdrawIfEnough(@Param("id") Long id, @Param("amount") long amount);
}
