package com.example.kitcheck.catalog;

import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

@Entity
@Table(name = "book")
public class Book {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)   // @ManyToOne is EAGER by default: always say LAZY
    @JoinColumn(name = "author_id")
    private Author author;

    private String title;

    @Version
    private long version;   // optimistic locking: a stale update fails instead of overwriting

    protected Book() {
    }

    Book(Author author, String title) {
        this.author = author;
        this.title = title;
    }

    public Long getId() { return id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public long getVersion() { return version; }
}
