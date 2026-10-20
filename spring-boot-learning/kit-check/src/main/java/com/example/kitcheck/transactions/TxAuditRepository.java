package com.example.kitcheck.transactions;

import org.springframework.data.jpa.repository.JpaRepository;

public interface TxAuditRepository extends JpaRepository<TxAudit, Long> {
}
