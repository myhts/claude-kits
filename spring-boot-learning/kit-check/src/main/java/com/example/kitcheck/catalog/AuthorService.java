package com.example.kitcheck.catalog;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.List;

@Service
@Transactional(readOnly = true)
public class AuthorService {

    private final AuthorRepository authors;

    public AuthorService(AuthorRepository authors) {
        this.authors = authors;
    }

    /** N+1: one query for the authors, then one per author when its lazy books are touched. */
    public List<AuthorSummary> listNaive() {
        return authors.findAll().stream().map(AuthorSummary::from).toList();
    }

    /** One query: the books come back in the same SELECT. */
    public List<AuthorSummary> listFetched() {
        return authors.findAllByOrderByIdAsc().stream().map(AuthorSummary::from).toList();
    }

    @Transactional
    public AuthorSummary create(CreateAuthorRequest request) {
        Author author = new Author(request.name());
        if (request.titles() != null) request.titles().forEach(author::addBook);
        return AuthorSummary.from(authors.save(author));
    }

    // ---- self-invocation: @Transactional works through the Spring proxy, and `this` is not the proxy

    public boolean callsInnerViaThis() {
        return inner();   // bypasses the proxy: no transaction starts here
    }

    @Transactional(readOnly = false)
    public boolean inner() {
        return TransactionSynchronizationManager.isActualTransactionActive()
                && !TransactionSynchronizationManager.isCurrentTransactionReadOnly();
    }
}
