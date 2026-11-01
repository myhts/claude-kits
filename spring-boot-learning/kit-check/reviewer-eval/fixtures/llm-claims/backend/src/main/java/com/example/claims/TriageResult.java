package com.example.claims;

/** What the model recommends for a claim. */
public record TriageResult(Decision decision, String claimantName, double amountClaimed, String currency, String summary) {

    public enum Decision { APPROVE, NEED_INFO, REFER }
}
