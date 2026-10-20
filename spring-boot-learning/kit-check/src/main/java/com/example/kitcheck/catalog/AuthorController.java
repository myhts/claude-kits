package com.example.kitcheck.catalog;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/authors")
public class AuthorController {

    private static final Logger log = LoggerFactory.getLogger(AuthorController.class);

    private final AuthorService service;

    public AuthorController(AuthorService service) {
        this.service = service;
    }

    @GetMapping
    public List<AuthorSummary> list() {
        return service.listFetched();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AuthorSummary create(@Valid @RequestBody CreateAuthorRequest request) {
        log.info("creating author with {} titles", request.titles() == null ? 0 : request.titles().size());   // no names: no personal data in logs
        return service.create(request);
    }
}
