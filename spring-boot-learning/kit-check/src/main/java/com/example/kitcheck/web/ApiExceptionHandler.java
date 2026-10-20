package com.example.kitcheck.web;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import java.util.Map;
import java.util.stream.Collectors;

/**
 * RFC 9457 problem details, with the invalid fields listed. Extending ResponseEntityExceptionHandler keeps Spring's
 * standard handling of every MVC exception and makes Boot's own handler (spring.mvc.problemdetails) back off. A plain
 * @ExceptionHandler(MethodArgumentNotValidException.class) in another advice races with Boot's handler, and loses.
 */
@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException ex, HttpHeaders headers,
                                                                  HttpStatusCode status, WebRequest request) {
        ProblemDetail problem = ex.getBody();
        problem.setDetail("request is invalid");
        Map<String, String> fields = ex.getBindingResult().getFieldErrors().stream()
                .collect(Collectors.toMap(f -> f.getField(), f -> String.valueOf(f.getDefaultMessage()), (a, b) -> a));
        problem.setProperty("fields", fields);
        return handleExceptionInternal(ex, problem, headers, status, request);
    }
}
