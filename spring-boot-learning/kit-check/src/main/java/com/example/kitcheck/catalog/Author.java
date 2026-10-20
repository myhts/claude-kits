package com.example.kitcheck.catalog;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "author")
public class Author {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @OneToMany(mappedBy = "author", cascade = CascadeType.ALL, orphanRemoval = true)   // LAZY by default for collections
    private List<Book> books = new ArrayList<>();

    protected Author() {
    }

    public Author(String name) {
        this.name = name;
    }

    public void addBook(String title) {
        books.add(new Book(this, title));
    }

    public Long getId() { return id; }
    public String getName() { return name; }
    public List<Book> getBooks() { return books; }
}
