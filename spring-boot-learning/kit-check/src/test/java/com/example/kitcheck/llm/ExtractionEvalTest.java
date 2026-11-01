package com.example.kitcheck.llm;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The eval harness against canned responses: proves the scoring and the gate, not the model. The same harness runs
 * live (LiveExtractionEvalIT) when someone decides to spend money on it.
 */
class ExtractionEvalTest {

    static List<ExtractionEval.Case> cases() {
        try (var lines = Files.lines(Path.of("src/test/resources/llm/eval/cases.jsonl"))) {
            return lines.filter(l -> !l.isBlank()).map(l -> {
                try {
                    JsonNode n = FakeClaude.JSON.readTree(l);
                    return new ExtractionEval.Case(n.path("id").asText(), n.path("email").asText(),
                            FakeClaude.JSON.treeToValue(n.path("expected"), Fnol.class));
                } catch (IOException e) { throw new UncheckedIOException(e); }
            }).toList();
        } catch (IOException e) { throw new UncheckedIOException(e); }
    }

    @Test
    void scoresEachFieldAndCatchesTheWrongOne() throws Exception {
        List<ExtractionEval.Case> cases = cases();
        try (FakeClaude claude = new FakeClaude()) {
            // replay the canned response for whichever case's email this request carries
            claude.respondWith(request -> {
                String email = request.path("messages").get(0).path("content").get(0).path("source").path("data").asText();
                String id = cases.stream().filter(c -> c.email().equals(email)).findFirst().orElseThrow().id();
                return new FakeClaude.Reply(200, FakeClaude.resource("llm/eval/responses/" + id + ".json"), 0);
            });
            ClaimExtractor extractor = new ClaimExtractor(claude.client(Duration.ofSeconds(5), 0), "claude-haiku-5-5");

            ExtractionEval.Report report = ExtractionEval.run(extractor, cases, UsageCost.HAIKU_5_5);

            assertThat(report.cases()).isEqualTo(4);
            assertThat(report.extracted()).isEqualTo(4);
            assertThat(report.fieldAccuracy()).containsEntry("lossType", 1.0)
                    .containsEntry("amountClaimed", 1.0)              // the injected 60000.00 didn't stick (in this canned run)
                    .containsEntry("currency", 0.75);                 // c3 answered GBP for a EUR claim
            assertThat(report.worstField()).isEqualTo(0.75);
            // 2,560 in × 0.10 + 590 out × 0.50, per million
            assertThat(report.costUsd()).isEqualByComparingTo(new BigDecimal("0.000551"));
        }
    }

    @Test
    void theGateFailsBelowTheBar() {
        ExtractionEval.Report report = new ExtractionEval.Report(4, 4, 0, 0,
                java.util.Map.of("currency", 0.75, "lossType", 1.0), BigDecimal.ZERO);

        // in a project this is the CI gate: assertThat(report.worstField()).isGreaterThanOrEqualTo(BAR)
        assertThat(report.worstField() >= 0.9).isFalse();
    }
}
