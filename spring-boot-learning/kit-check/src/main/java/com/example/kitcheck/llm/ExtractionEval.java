package com.example.kitcheck.llm;

import com.example.kitcheck.llm.ClaimExtractor.Extraction;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;

/**
 * Runs the extractor over labelled cases and scores it field by field. An eval is a test whose answer is a number:
 * it says how good the prompt + model is now, so a change can be judged by the number moving, not by a few
 * good-looking outputs. List fields (missingInformation) need a softer grader and aren't scored here.
 */
public final class ExtractionEval {

    public record Case(String id, String email, Fnol expected) { }

    public record Report(int cases, int extracted, int refused, int unusable, Map<String, Double> fieldAccuracy, BigDecimal costUsd) {
        public double worstField() {
            return fieldAccuracy.values().stream().mapToDouble(Double::doubleValue).min().orElse(0);
        }
    }

    private static final Map<String, Function<Fnol, Object>> FIELDS = new LinkedHashMap<>();
    static {
        FIELDS.put("claimantName", Fnol::claimantName);
        FIELDS.put("policyNumber", Fnol::policyNumber);
        FIELDS.put("incidentDate", Fnol::incidentDate);
        FIELDS.put("lossType", Fnol::lossType);
        FIELDS.put("amountClaimed", Fnol::amountClaimed);
        FIELDS.put("currency", Fnol::currency);
    }

    private ExtractionEval() { }

    public static Report run(ClaimExtractor extractor, List<Case> cases, UsageCost prices) {
        Map<String, Integer> right = new LinkedHashMap<>();
        FIELDS.keySet().forEach(f -> right.put(f, 0));
        int extracted = 0, refused = 0, unusable = 0;
        BigDecimal cost = BigDecimal.ZERO;
        for (Case c : cases) {
            Extraction result = extractor.extract(c.email());
            cost = cost.add(prices.dollars(result.usage()));
            switch (result) {
                case Extraction.Extracted e -> {
                    extracted++;
                    FIELDS.forEach((name, get) -> {
                        if (Objects.equals(get.apply(e.fnol()), get.apply(c.expected()))) right.merge(name, 1, Integer::sum);
                    });
                }
                case Extraction.Refused r -> refused++;
                case Extraction.Unusable u -> unusable++;
            }
        }
        Map<String, Double> accuracy = new LinkedHashMap<>();
        right.forEach((f, n) -> accuracy.put(f, cases.isEmpty() ? 0 : (double) n / cases.size()));  // a miss on every unusable case
        return new Report(cases.size(), extracted, refused, unusable, accuracy, cost);
    }
}
