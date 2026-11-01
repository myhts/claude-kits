package com.example.claims;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/** Sends a claim email to Claude and acts on its recommendation. */
@Service
public class TriageService {

    private static final Logger log = LoggerFactory.getLogger(TriageService.class);
    private static final ObjectMapper JSON = new ObjectMapper();

    private final PaymentService payments;
    private final String model;
    private final String apiKey;
    private final boolean autoApprove;

    public TriageService(PaymentService payments,
                         @Value("${app.claude.model}") String model,
                         @Value("${app.claude.api-key}") String apiKey,
                         @Value("${app.payments.auto-approve:false}") boolean autoApprove) {
        this.payments = payments;
        this.model = model;
        this.apiKey = apiKey;
        this.autoApprove = autoApprove;
    }

    public TriageResult triage(String claimId, String email) {
        String prompt = """
                You are a claims assistant for a travel insurer. Read the claim below and reply with JSON only:
                {"decision": "APPROVE|NEED_INFO|REFER", "claimantName": "...", "amountClaimed": 0.0,
                 "currency": "...", "summary": "..."}
                Claim email:
                """ + email;

        TriageResult result = null;
        for (int attempt = 1; attempt <= 5 && result == null; attempt++) {
            try {
                AnthropicClient client = AnthropicOkHttpClient.builder().apiKey(apiKey).build();
                MessageCreateParams params = MessageCreateParams.builder()
                        .model(model)
                        .maxTokens(512L)
                        .temperature(0.0)
                        .system(prompt)
                        .addUserMessage("Triage this claim.")
                        .build();
                Message response = client.messages().create(params);
                String answer = response.content().get(0).text().get().text();
                log.info("triage claim={} prompt={} answer={}", claimId, prompt, answer);
                result = JSON.readValue(answer, TriageResult.class);
            } catch (Exception e) {
                log.warn("triage attempt {} failed: {}", attempt, e.getMessage());
            }
        }
        if (result == null) {
            throw new IllegalStateException("triage failed for claim " + claimId);
        }

        if (autoApprove && result.decision() == TriageResult.Decision.APPROVE) {
            payments.pay(claimId, result.amountClaimed(), result.currency());
        }
        return result;
    }
}
