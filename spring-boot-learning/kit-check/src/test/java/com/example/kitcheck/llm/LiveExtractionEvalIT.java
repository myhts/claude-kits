package com.example.kitcheck.llm;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The same eval against the real API. Spends money, so it runs only when asked twice: RUN_LIVE_EVALS=true and a key.
 *   RUN_LIVE_EVALS=true ANTHROPIC_API_KEY=... ./mvnw verify -Dit.test=LiveExtractionEvalIT
 * Four cases on Haiku 5.5 cost well under a cent. NOT RUN YET: the kit's fixtures are written in the documented
 * response shape; this run is what checks them against the live API.
 */
@EnabledIfEnvironmentVariable(named = "RUN_LIVE_EVALS", matches = "true")
@EnabledIfEnvironmentVariable(named = "ANTHROPIC_API_KEY", matches = ".+")
class LiveExtractionEvalIT {

    @Test
    void haikuExtractsTheInventedClaims() {
        var client = ClaudeConfig.client("", System.getenv("ANTHROPIC_API_KEY"), Duration.ofSeconds(60), 2);
        var report = ExtractionEval.run(new ClaimExtractor(client, "claude-haiku-5-5"), ExtractionEvalTest.cases(), UsageCost.HAIKU_5_5);

        System.out.println("live eval: " + report);
        assertThat(report.extracted()).isEqualTo(report.cases());
        assertThat(report.worstField()).isGreaterThanOrEqualTo(0.75);
    }
}
