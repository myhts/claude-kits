package com.example.kitcheck.transactions;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** REQUIRES_NEW that works: called from another bean, so the call goes through this bean's proxy. */
@Service
public class AuditService {

    private final TxAuditRepository audits;

    public AuditService(TxAuditRepository audits) {
        this.audits = audits;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void audit(String message) {
        audits.save(new TxAudit(message));
    }
}
