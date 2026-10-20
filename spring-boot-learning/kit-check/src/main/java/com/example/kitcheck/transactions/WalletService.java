package com.example.kitcheck.transactions;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Check-then-act on a balance. afterCheck lets a test hold both callers between the check and the write, which is
 * exactly the window two concurrent requests hit in production.
 */
@Service
public class WalletService {

    private final TxWalletRepository wallets;
    private final TxVersionedWalletRepository versioned;

    public WalletService(TxWalletRepository wallets, TxVersionedWalletRepository versioned) {
        this.wallets = wallets;
        this.versioned = versioned;
    }

    @Transactional
    public boolean withdrawNaive(Long id, long amount, Runnable afterCheck) {
        TxWallet w = wallets.findById(id).orElseThrow();
        if (w.getBalance() < amount) {
            return false;
        }
        afterCheck.run();
        w.setBalance(w.getBalance() - amount);                     // both callers write 500 - 400
        return true;
    }

    @Transactional
    public boolean withdrawVersioned(Long id, long amount, Runnable afterCheck) {
        TxVersionedWallet w = versioned.findById(id).orElseThrow();
        if (w.getBalance() < amount) {
            return false;
        }
        afterCheck.run();
        w.setBalance(w.getBalance() - amount);                     // UPDATE … WHERE version = ?: the second one fails
        return true;
    }

    @Transactional
    public boolean withdrawConditional(Long id, long amount) {
        return wallets.withdrawIfEnough(id, amount) == 1;          // check and write are one statement
    }
}
