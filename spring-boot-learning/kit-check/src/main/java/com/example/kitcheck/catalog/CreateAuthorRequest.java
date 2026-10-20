package com.example.kitcheck.catalog;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

public record CreateAuthorRequest(@NotBlank @Size(max = 100) String name, List<@NotBlank String> titles) {
}
