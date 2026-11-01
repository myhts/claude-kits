package com.example.kitcheck.llm;

import com.anthropic.client.AnthropicClient;
import com.anthropic.models.messages.CacheControlEphemeral;
import com.anthropic.models.messages.CitationsConfigParam;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.DocumentBlockParam;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.PlainTextSource;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.TextBlockParam;
import com.anthropic.models.messages.Usage;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

/**
 * Claim vs policy wording, answered with citations. The policy is the large, stable part of every request, so it
 * goes first with a cache marker; the claim, which changes every time, comes after it.
 * Citations can't be combined with structured outputs in one request (a 400), so this returns cited prose; turning
 * it into a decision enum is a second, structured call (or a strict tool): the trade-off to record in an ADR.
 */
@Service
public class CoverageChecker {

    static final String SYSTEM_PROMPT = """
            You assess whether a travel insurance claim is covered by the policy wording in the document titled
            "policy". Quote the clauses you rely on. Say "unclear" when the wording doesn't settle it. You recommend;
            a claims handler decides.""";

    private final AnthropicClient client;
    private final String model;

    public CoverageChecker(AnthropicClient client, @Value("${app.claude.model:claude-haiku-5-5}") String model) {
        this.client = client;
        this.model = model;
    }

    /** A citation the model gave, checked against the policy text it claims to quote. */
    public record ClauseCitation(String citedText, long start, long end, boolean verified) { }

    public record Opinion(String text, List<ClauseCitation> citations, StopReason stopReason, Usage usage) {
        public boolean allCitationsVerified() {
            return !citations.isEmpty() && citations.stream().allMatch(ClauseCitation::verified);
        }
    }

    public Opinion assess(String policyWording, String claimSummary) {
        MessageCreateParams params = MessageCreateParams.builder()
                .model(model)
                .maxTokens(8_000L)
                .systemOfTextBlockParams(List.of(TextBlockParam.builder().text(SYSTEM_PROMPT).build()))
                .addUserMessageOfBlockParams(List.of(
                        ContentBlockParam.ofDocument(DocumentBlockParam.builder()
                                .source(PlainTextSource.builder().data(policyWording).build())
                                .title("policy")
                                .citations(CitationsConfigParam.builder().enabled(true).build())
                                .cacheControl(CacheControlEphemeral.builder().build())   // cache everything up to here
                                .build()),
                        ContentBlockParam.ofText(TextBlockParam.builder().text("Claim:\n" + claimSummary).build())))
                .build();

        Message response = client.messages().create(params);
        StringBuilder text = new StringBuilder();
        List<ClauseCitation> citations = new ArrayList<>();
        response.content().forEach(block -> block.text().ifPresent(t -> {
            text.append(t.text());
            t.citations().orElse(List.of()).forEach(c -> c.charLocation().ifPresent(loc ->
                    citations.add(new ClauseCitation(loc.citedText(), loc.startCharIndex(), loc.endCharIndex(),
                            quotes(policyWording, loc.citedText(), loc.startCharIndex(), loc.endCharIndex())))));
        }));
        return new Opinion(text.toString(), citations, response.stopReason().orElse(null), response.usage());
    }

    /** Trust, but verify: the cited text must be exactly what the policy says at those offsets. */
    static boolean quotes(String source, String cited, long start, long end) {
        return start >= 0 && end <= source.length() && start < end && source.substring((int) start, (int) end).equals(cited);
    }
}
