package com.example.kitcheck.llm;

import java.util.regex.Pattern;

/**
 * Masks personal data before anything is logged or stored outside the claim itself. Prompts and model output contain
 * the claimant's details, so "log the request for debugging" leaks them unless it goes through here.
 * Patterns are a floor, not a guarantee: names in free text aren't caught. Log ids and sizes, not content, by default.
 */
public final class PiiRedactor {

    private static final Pattern EMAIL = Pattern.compile("[\\w.+-]+@[\\w-]+(\\.[\\w-]+)+");
    private static final Pattern CARD = Pattern.compile("\\b(?:\\d[ -]?){13,19}\\b");
    private static final Pattern PHONE = Pattern.compile("(?<!\\w)\\+?\\d[\\d ()-]{7,}\\d");
    private static final Pattern POLICY = Pattern.compile("\\bPOL-\\d{4,}\\b");

    private PiiRedactor() { }

    public static String redact(String text) {
        if (text == null) return null;
        String s = EMAIL.matcher(text).replaceAll("[email]");
        s = CARD.matcher(s).replaceAll("[card]");        // before phone: a card number also looks like a phone number
        s = PHONE.matcher(s).replaceAll("[phone]");
        return POLICY.matcher(s).replaceAll("[policy]");
    }
}
