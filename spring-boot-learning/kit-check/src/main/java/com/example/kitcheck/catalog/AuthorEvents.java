package com.example.kitcheck.catalog;

import com.example.kitcheck.outbox.OutboxRelay;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** A business write and its event in one transaction: the outbox's whole point. */
@Service
public class AuthorEvents {

    private final AuthorRepository authors;
    private final OutboxRelay outbox;

    public AuthorEvents(AuthorRepository authors, OutboxRelay outbox) {
        this.authors = authors;
        this.outbox = outbox;
    }

    @Transactional
    public long register(String name) {
        Author author = authors.saveAndFlush(new Author(name));
        outbox.append("authors", String.valueOf(author.getId()), "{\"type\":\"AuthorRegistered\",\"id\":" + author.getId() + "}");
        return author.getId();
    }
}
