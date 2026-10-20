package com.example.kitcheck.catalog;

import java.util.List;

public record AuthorSummary(Long id, String name, List<String> titles) {

    static AuthorSummary from(Author author) {
        return new AuthorSummary(author.getId(), author.getName(), author.getBooks().stream().map(Book::getTitle).toList());
    }
}
