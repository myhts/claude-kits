package com.example.kitcheck.llm;

import com.anthropic.models.messages.Usage;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * What one call cost, from the usage the API returns. Prices are per million tokens and change: keep them in
 * configuration, check the pricing page, and record which table a number was computed with.
 * input_tokens excludes the cached part: cache reads and cache writes are reported, and priced, separately.
 */
public record UsageCost(BigDecimal inputPerMTok, BigDecimal outputPerMTok, BigDecimal cacheWritePerMTok, BigDecimal cacheReadPerMTok) {

    /** Claude Haiku 5.5, prompts up to 100K tokens (2026-10): $0.10 in, $0.50 out; 5-minute cache write 1.25×, read 0.1×. */
    public static final UsageCost HAIKU_5_5 = of("0.10", "0.50", "0.125", "0.01");

    public static UsageCost of(String in, String out, String cacheWrite, String cacheRead) {
        return new UsageCost(new BigDecimal(in), new BigDecimal(out), new BigDecimal(cacheWrite), new BigDecimal(cacheRead));
    }

    public BigDecimal dollars(Usage u) {
        BigDecimal micro = inputPerMTok.multiply(BigDecimal.valueOf(u.inputTokens()))
                .add(outputPerMTok.multiply(BigDecimal.valueOf(u.outputTokens())))
                .add(cacheWritePerMTok.multiply(BigDecimal.valueOf(u.cacheCreationInputTokens().orElse(0L))))
                .add(cacheReadPerMTok.multiply(BigDecimal.valueOf(u.cacheReadInputTokens().orElse(0L))));
        return micro.divide(BigDecimal.valueOf(1_000_000), 8, RoundingMode.HALF_UP);
    }
}
