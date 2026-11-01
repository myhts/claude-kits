package com.example.kitcheck.llm;

import com.anthropic.models.messages.Usage;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;

/**
 * What was asked, of which model, with which prompt version, what came back and what it cost: enough to explain
 * any recommendation later, and to reproduce it. Stores a hash of the input, not the input (that stays with the claim).
 */
public record AuditRecord(Instant at, String model, String promptVersion, String inputSha256, String outcome,
                          long inputTokens, long outputTokens, long cacheReadTokens, long cacheWriteTokens, BigDecimal costUsd) {

    public static AuditRecord of(String model, String promptVersion, String input, String outcome, Usage u, UsageCost prices) {
        return new AuditRecord(Instant.now(), model, promptVersion, sha256(input), outcome,
                u.inputTokens(), u.outputTokens(), u.cacheReadInputTokens().orElse(0L), u.cacheCreationInputTokens().orElse(0L),
                prices.dollars(u));
    }

    /** A prompt's version is its content: change one character and the version changes, so no manual numbering. */
    public static String versionOf(String prompt) {
        return sha256(prompt).substring(0, 12);
    }

    static String sha256(String s) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
