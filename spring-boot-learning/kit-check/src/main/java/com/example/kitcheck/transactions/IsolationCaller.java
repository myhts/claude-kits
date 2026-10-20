package com.example.kitcheck.transactions;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Starts a default (READ COMMITTED) transaction, then calls the SERIALIZABLE method, which joins it. */
@Service
public class IsolationCaller {

    private final IsolationService isolation;

    public IsolationCaller(IsolationService isolation) {
        this.isolation = isolation;
    }

    @Transactional
    public String callSerializableFromInside() {
        return isolation.serializableAsked();
    }
}
