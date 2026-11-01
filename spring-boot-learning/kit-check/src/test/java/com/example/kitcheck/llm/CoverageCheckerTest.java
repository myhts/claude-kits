package com.example.kitcheck.llm;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;

/** Citations: parsed, and checked against the policy they claim to quote; the policy prefix marked for caching. */
class CoverageCheckerTest {

    static final String POLICY = """
            Section 4 Baggage
            4.1 We will pay up to 1500.00 GBP per trip for baggage that is lost, stolen or damaged.
            4.2 We will not pay for valuables left unattended in a public place.
            Section 7 Exclusions
            7.1 We will not pay for losses you do not report to the carrier within 24 hours.""";

    FakeClaude claude;

    @BeforeEach
    void start() throws Exception { claude = new FakeClaude(); }

    @AfterEach
    void stop() { claude.close(); }

    static String citation(String cited, long start, long end) {
        return """
                {"type":"char_location","cited_text":%s,"document_index":0,"document_title":"policy",
                 "start_char_index":%d,"end_char_index":%d}""".formatted(quote(cited), start, end);
    }

    static String quote(String s) {
        try { return FakeClaude.JSON.writeValueAsString(s); } catch (Exception e) { throw new IllegalStateException(e); }
    }

    String citedResponse(String citationsJson, long cacheWrite, long cacheRead) {
        return """
                {"id":"msg_fake","type":"message","role":"assistant","model":"claude-haiku-5-5",
                 "content":[
                   {"type":"text","text":"Likely covered. ","citations":null},
                   {"type":"text","text":"Lost baggage is covered up to the limit.","citations":[%s]}],
                 "stop_reason":"end_turn","stop_sequence":null,
                 "usage":{"input_tokens":120,"output_tokens":90,"cache_creation_input_tokens":%d,"cache_read_input_tokens":%d}}"""
                .formatted(citationsJson, cacheWrite, cacheRead);
    }

    CoverageChecker checker() {
        return new CoverageChecker(claude.client(Duration.ofSeconds(5), 0), "claude-haiku-5-5");
    }

    @Test
    void citationsAreParsedAndVerifiedAgainstThePolicy() {
        String clause = "We will pay up to 1500.00 GBP per trip for baggage that is lost, stolen or damaged.";
        int start = POLICY.indexOf(clause);
        claude.reply(200, citedResponse(citation(clause, start, start + clause.length()), 0, 0));

        CoverageChecker.Opinion opinion = checker().assess(POLICY, "Suitcase lost, 1250.00 GBP");

        assertThat(opinion.text()).isEqualTo("Likely covered. Lost baggage is covered up to the limit.");
        assertThat(opinion.citations()).singleElement().satisfies(c -> {
            assertThat(c.citedText()).isEqualTo(clause);
            assertThat(c.verified()).isTrue();
        });
        assertThat(opinion.allCitationsVerified()).isTrue();
    }

    @Test
    void aCitationThatDoesNotMatchThePolicyIsFlagged() {
        String invented = "We will pay any amount for lost baggage.";
        claude.reply(200, citedResponse(citation(invented, 18, 18 + invented.length()), 0, 0));

        CoverageChecker.Opinion opinion = checker().assess(POLICY, "Suitcase lost, 9000.00 GBP");

        assertThat(opinion.citations()).singleElement().satisfies(c -> assertThat(c.verified()).isFalse());
        assertThat(opinion.allCitationsVerified()).isFalse();   // → a human looks at it
    }

    @Test
    void thePolicyGoesFirstWithCitationsOnAndACacheMarker() {
        claude.reply(200, citedResponse(citation("x", 0, 1), 0, 0));

        checker().assess(POLICY, "Suitcase lost");

        JsonNode content = claude.request(0).path("messages").get(0).path("content");
        JsonNode doc = content.get(0);
        assertThat(doc.path("type").asText()).isEqualTo("document");
        assertThat(doc.path("citations").path("enabled").asBoolean()).isTrue();
        assertThat(doc.path("cache_control").path("type").asText()).isEqualTo("ephemeral");
        assertThat(content.get(1).path("text").asText()).startsWith("Claim:");      // the changing part comes after
        assertThat(claude.request(0).has("output_config")).isFalse();               // citations + structured outputs = 400
    }

    @Test
    void cacheReadsAreBilledAtTheCacheRate() {
        claude.reply(200, citedResponse(citation("x", 0, 1), 0, 20_000));

        CoverageChecker.Opinion opinion = checker().assess(POLICY, "Suitcase lost");

        // 120 in × 0.10 + 90 out × 0.50 + 20,000 cache read × 0.01, per million = 0.000257
        assertThat(UsageCost.HAIKU_5_5.dollars(opinion.usage())).isEqualByComparingTo(new BigDecimal("0.000257"));
        // the same 20,000 tokens uncached would have cost 0.002 on their own
    }
}
