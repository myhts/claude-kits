package com.example.claims;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/api/v1/claims")
public class ClaimsController {

    public record ClaimRequest(String email) { }

    private final TriageService triage;
    private final Map<String, TriageResult> results = new ConcurrentHashMap<>();

    public ClaimsController(TriageService triage) {
        this.triage = triage;
    }

    @PostMapping("/{claimId}/triage")
    public TriageResult triage(@PathVariable String claimId, @RequestBody ClaimRequest request) {
        TriageResult result = triage.triage(claimId, request.email());
        results.put(claimId, result);
        return result;
    }

    /** A small page for adjusters: the model's summary of the claim. */
    @GetMapping(value = "/{claimId}/summary", produces = MediaType.TEXT_HTML_VALUE)
    public String summary(@PathVariable String claimId) {
        TriageResult r = results.get(claimId);
        if (r == null) {
            return "<p>No triage yet for " + claimId + "</p>";
        }
        return "<h1>Claim " + claimId + "</h1><p>Recommendation: " + r.decision() + "</p><div>" + r.summary() + "</div>";
    }
}
