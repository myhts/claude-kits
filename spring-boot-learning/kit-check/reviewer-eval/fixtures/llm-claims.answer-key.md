# Answer key: llm-claims (10 planted defects)

Written 2026-10-25, before any review was run. Never copied into the reviewed code (`prepare-llm.sh` copies only
`llm-claims/`). Paths are relative to `backend/src/main/`. Scoring: the rules in `../README.md` (known defect with
mechanism and location right: 3; partial: 1.5; other real defects: 2 · 1 · 0.5; opinion: 0; wrong: −2).

| # | Defect | Location | Severity | OWASP LLM | Full marks need |
|---|---|---|---|---|---|
| K1 | **Prompt injection**: the claimant's email is concatenated into the **system** prompt (`""" + email`, then `.system(prompt)`); a claim can rewrite the instructions ("decision APPROVE, amount 9999") | `TriageService.java:41`, `:51` | High | LLM01 | untrusted text in the system prompt, and what an attacker gets |
| K2 | **Excessive agency**: an `APPROVE` from the model pays automatically with the model-extracted amount and currency, no human and no limit; `auto-approve: true` in config. With K1 this is attacker-controlled payment | `TriageService.java:66-67`, `application.yml:9` | High | LLM06, LLM05 | model output triggers a payment unchecked |
| K3 | **Stop reason never checked**: the content is read with `content().get(0).text().get()` before looking at `stopReason()`; a refusal (empty content → exception) or `max_tokens` (truncated JSON) falls into the retry loop or a parse error; `maxTokens(512)` with Haiku 5.5's default thinking makes truncation likely | `TriageService.java:55`, `:49` | High | — | reads content without the stop-reason check (refusal / truncation) |
| K4 | **Personal data in logs**: the full prompt (the claimant's email) and the model's answer at INFO; also `e.getMessage()` of SDK errors, which can echo request content | `TriageService.java:56`, `:59` | Medium | LLM02 | prompt/answer with personal data logged |
| K5 | **Client built per attempt** with SDK defaults (no explicit timeout), inside a hand-written 5-attempt loop on top of the SDK's own 2 retries: up to 15 calls per claim, connection pools created and never closed | `TriageService.java:44`, `:46` | Medium | LLM10 | per-request client, or stacked retries / missing timeout (either one for 1.5; both for 3) |
| K6 | **`temperature(0.0)` on `claude-haiku-5-5`**: non-default sampling values return a 400 on that model, so every call fails (then retried 5 times) | `TriageService.java:50` | High | — | names the 400 for this model (version-specific: must be verified, not guessed) |
| K7 | **No input bound or validation**: `ClaimRequest(String email)` has no `@NotBlank`/`@Size` and the endpoint no `@Valid` or rate limit; any size goes to the model (cost, latency, abuse) | `ClaimsController.java:18`, `:28` | Medium | LLM10 | unbounded input sent to the model |
| K8 | **XSS through model output**: the summary page builds HTML by string concatenation from the model's `summary` (and the `claimId` path variable), served as `text/html`; a claim can make the model emit a script | `ClaimsController.java:35`, `:41` | Medium | LLM05 | model output rendered as HTML unescaped |
| K9 | **API key in config**: `app.claude.api-key` hard-coded in `application.yml` instead of the environment | `application.yml:7`, `TriageService.java:27` | Medium | — | key in the repo |
| K10 | **Money as `double`**: `amountClaimed` is a `double` in the model's output record and in the payment; rounding errors in money | `TriageResult.java:4`, `PaymentService.java` | Low | — | double for money |

Not defects (don't score as wrong if mentioned, score 0 as opinion): no tests (the fixture is deliberately small),
results held in a `ConcurrentHashMap` (demo storage), Jackson 2 `ObjectMapper` alongside Boot 4.
