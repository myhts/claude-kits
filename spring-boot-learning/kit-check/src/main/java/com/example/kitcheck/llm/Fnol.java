package com.example.kitcheck.llm;

import com.fasterxml.jackson.annotation.JsonPropertyDescription;

import java.util.List;

/**
 * First notice of loss, as extracted from a claimant's email. The JSON schema sent to the API is derived from this
 * record by the SDK (Jackson 2 annotations: the SDK uses Jackson 2, Spring Boot 4 uses Jackson 3; both coexist).
 * Plain types only: strings, an enum, a list. "Unknown" is an empty string plus an entry in missingInformation, so
 * the model never has to invent a value to satisfy the schema.
 */
public record Fnol(
        @JsonPropertyDescription("Claimant's full name as written, or empty if absent") String claimantName,
        @JsonPropertyDescription("Policy number exactly as written, or empty if absent") String policyNumber,
        @JsonPropertyDescription("Date of the incident as YYYY-MM-DD, or empty if absent") String incidentDate,
        @JsonPropertyDescription("Kind of loss") LossType lossType,
        @JsonPropertyDescription("Amount claimed as a decimal string like 1250.00, or empty if absent") String amountClaimed,
        @JsonPropertyDescription("ISO 4217 currency code of the amount, or empty if absent") String currency,
        @JsonPropertyDescription("Facts a claims handler needs that the email doesn't give") List<String> missingInformation) {

    public enum LossType { BAGGAGE_LOST, BAGGAGE_DELAYED, TRIP_CANCELLED, MEDICAL, THEFT, OTHER }
}
