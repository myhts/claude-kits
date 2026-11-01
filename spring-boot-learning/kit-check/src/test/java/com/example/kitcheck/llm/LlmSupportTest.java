package com.example.kitcheck.llm;

import com.anthropic.models.messages.Usage;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/** Cost, redaction and the audit record: the plain-Java parts around the model call. */
class LlmSupportTest {

    static Usage usage(long in, long out, long cacheWrite, long cacheRead) {
        return Usage.builder().inputTokens(in).outputTokens(out)
                .cacheCreationInputTokens(cacheWrite).cacheReadInputTokens(cacheRead)
                .cacheCreation(java.util.Optional.empty()).inferenceGeo(java.util.Optional.empty())
                .serverToolUse(java.util.Optional.empty()).serviceTier(java.util.Optional.empty()).outputTokensDetails(java.util.Optional.empty())
                .build();
    }

    @Test
    void costCountsEveryKindOfToken() {
        // 1,000 in × 0.10 + 500 out × 0.50 + 4,000 cache write × 0.125 + 0 read, per million
        assertThat(UsageCost.HAIKU_5_5.dollars(usage(1_000, 500, 4_000, 0))).isEqualByComparingTo(new BigDecimal("0.00085"));
    }

    @Test
    void personalDataIsMaskedBeforeLogging() {
        String raw = "Dana (dana.okafor@example.com, +44 7700 900123) policy POL-20481, card 4111 1111 1111 1111";

        assertThat(PiiRedactor.redact(raw))
                .isEqualTo("Dana ([email], [phone]) policy [policy], card [card]")
                .doesNotContain("@", "4111", "20481");   // the name stays: patterns don't catch names, so log less
    }

    @Test
    void aPromptVersionChangesWithTheText() {
        String v1 = AuditRecord.versionOf("Extract the claim.");

        assertThat(AuditRecord.versionOf("Extract the claim.")).isEqualTo(v1);
        assertThat(AuditRecord.versionOf("Extract the claim!")).isNotEqualTo(v1).hasSize(12);
    }

    @Test
    void theAuditKeepsAHashNotTheContent() {
        AuditRecord a = AuditRecord.of("claude-haiku-5-5", "abc123", "my email text", "Extracted", usage(1_000, 500, 0, 0), UsageCost.HAIKU_5_5);

        assertThat(a.inputSha256()).hasSize(64).doesNotContain("email");
        assertThat(a.costUsd()).isEqualByComparingTo(new BigDecimal("0.00035"));
    }
}
