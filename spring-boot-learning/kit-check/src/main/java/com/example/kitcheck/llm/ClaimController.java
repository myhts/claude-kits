package com.example.kitcheck.llm;

import com.anthropic.errors.AnthropicIoException;
import com.anthropic.errors.AnthropicServiceException;
import com.example.kitcheck.llm.ClaimExtractor.Extraction;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/claims")
class ClaimController {

    private static final Logger log = LoggerFactory.getLogger(ClaimController.class);

    record ExtractRequest(@NotBlank @Size(max = 20_000) String email) { }   // bounded: input size is cost

    private final ClaimExtractor extractor;
    private final String model;

    ClaimController(ClaimExtractor extractor, @Value("${app.claude.model:claude-haiku-5-5}") String model) {
        this.extractor = extractor;
        this.model = model;
    }

    @PostMapping("/extract")
    ResponseEntity<?> extract(@Valid @RequestBody ExtractRequest request) {
        Extraction result = extractor.extract(request.email());
        AuditRecord audit = AuditRecord.of(model, ClaimExtractor.PROMPT_VERSION, request.email(),
                result.getClass().getSimpleName(), result.usage(), UsageCost.HAIKU_5_5);
        log.info("claim extraction outcome={} promptVersion={} inputSha={} cost={}",
                audit.outcome(), audit.promptVersion(), audit.inputSha256().substring(0, 12), audit.costUsd());   // no content
        return switch (result) {
            case Extraction.Extracted e -> ResponseEntity.ok(e.fnol());
            case Extraction.Refused r -> problem("Declined by the model: route to a claims handler (" + r.category() + ")");
            case Extraction.Unusable u -> problem("No usable extraction: route to a claims handler (" + u.reason() + ")");
        };
    }

    /** The model is overloaded or unreachable after the SDK's retries: temporary, so 503, and never a guessed answer. */
    @ExceptionHandler({AnthropicServiceException.class, AnthropicIoException.class})
    ResponseEntity<ProblemDetail> modelUnavailable(RuntimeException e) {
        log.warn("claim extraction failed: {}", e.getClass().getSimpleName());   // the message may echo input: not logged
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).header("Retry-After", "30")
                .body(ProblemDetail.forStatusAndDetail(HttpStatus.SERVICE_UNAVAILABLE, "The model is unavailable: try again shortly"));
    }

    private static ResponseEntity<ProblemDetail> problem(String detail) {
        return ResponseEntity.unprocessableContent().body(ProblemDetail.forStatusAndDetail(HttpStatus.UNPROCESSABLE_CONTENT, detail));
    }
}
