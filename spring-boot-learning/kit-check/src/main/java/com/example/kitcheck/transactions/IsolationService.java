package com.example.kitcheck.transactions;

import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

/** Asks Postgres which isolation level the current transaction really has. */
@Service
public class IsolationService {

    private final EntityManager em;

    public IsolationService(EntityManager em) {
        this.em = em;
    }

    @Transactional(isolation = Isolation.SERIALIZABLE)
    public String serializableAsked() {
        return (String) em.createNativeQuery("show transaction_isolation").getSingleResult();
    }
}
