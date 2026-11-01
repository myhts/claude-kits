# Review checklist for code that calls a model

Used by the `code-reviewer` and `security-reviewer` agents when a change touches an LLM call (the code uses
`com.anthropic`, another model SDK, or builds prompts). Each item: what to look for, how to find it, and why it
matters. The OWASP Top 10 for LLM Applications (2025, genai.owasp.org) ids are given where they apply.
Report only what you can point to at `file:line`.

## Security

| Check | How to find it | Why (OWASP) |
|---|---|---|
| Untrusted text (user, claimant, web page, file) concatenated into the **system prompt** or into instructions | `grep -n "systemOf\|\.system(\|SYSTEM_PROMPT\|formatted(\|+ email\|+ body"` near the call | Prompt injection (LLM01) |
| Model output **executed or acted on** without validation: used in SQL, a shell, a URL fetch, a file path, an email send, a payment or a status change | Follow the parsed result to its uses | Improper output handling (LLM05), excessive agency (LLM06) |
| Model output rendered as **HTML** in a UI (`dangerouslySetInnerHTML`, `th:utext`, string-built HTML) | grep the front end | XSS through the model (LLM05) |
| Personal data in **logs**: prompts, answers, emails, `e.getMessage()` of SDK exceptions on the request path | `grep -n "log\.\(info\|debug\|warn\|error\)"` around the call | Sensitive information disclosure (LLM02) |
| **API key** in code, config, tests, Dockerfile, CI files, or logged | `grep -rn "sk-ant\|ANTHROPIC_API_KEY\|apiKey("` | Secrets |
| Secrets, internal rules or other customers' data **in the prompt**, where an answer could repeat them | Read what's assembled into the request | System prompt leakage (LLM07), LLM02 |
| **No input bound**: unbounded text, file or page sizes sent to the model | Missing `@Size`, no length check before the call | Unbounded consumption (LLM10): cost and denial of service |
| **No rate limit or budget** on an endpoint that calls the model | The controller and its callers | LLM10 |
| A model **decides** something that should be a human's or code's call (approve, pay, delete) | The flow after the call | Excessive agency (LLM06) |
| Answers presented as fact without grounding (no citations, no "unclear" path) | The prompt and the UI copy | Misinformation (LLM09) |
| SDK or model versions unpinned (`LATEST`, ranges, `latest` image tags) | `pom.xml`, Dockerfiles | Supply chain (LLM03) |

## Correctness

| Check | How to find it | Why |
|---|---|---|
| Content read **before checking `stopReason()`** | The code right after `create(...)` | A refusal or a cut-off answer gets treated as an answer |
| Structured output parsed without a catch at `typed.text()` | Lazy parsing site | A bad enum or truncated JSON throws in an unexpected place |
| Schema-valid output used without **business validation** (dates, amounts, ids that must exist) | After parsing | Schema-valid isn't correct |
| `double`/`float` for money in the output record | The record | Rounding errors; use a decimal string → `BigDecimal` |
| `max_tokens` too low for thinking + output | The builder | Answers cut off (`max_tokens` stop reason) |
| `temperature`, `top_p`, `top_k` sent | The builder | A 400 on Haiku 5.5 (non-default values), and on every model from API version 2026-10-21 |
| Citations and `outputConfig` in the **same** request | The builder | A 400 |
| Citations used without **checking the cited text against the source** | Where citations are read | Invented quotes pass as evidence |
| A refusal **retried** in a loop | Error handling | Haiku 5.5 has no server-side fallback; a refusal needs a human |

## Reliability and cost

| Check | How to find it | Why |
|---|---|---|
| A client **built per request** | `AnthropicOkHttpClient.builder()` outside a `@Bean` | Connection pool churn, slow, leaks |
| **No timeout**, or retries wrapped around the SDK's own retries | Client config; `Retry`/loops around the call | Hung threads; retry storms (3 × 3 = 9 calls) |
| Overload or I/O failure surfaced as a 500 | Exception handling at the controller | Should be 503 + `Retry-After`, without a guessed answer |
| Large stable content (policy, instructions) **after** changing content, or with a timestamp in front | Request assembly order | Prompt cache never hits; you pay full price every call |
| **Cost not recorded** per call, or computed from `inputTokens` alone | Usage handling | Cache reads and writes are billed separately |
| Prompt text changed with **no version and no eval run** | The diff touches a prompt | Quality changes nobody measured |

## Tests

| Check | Why |
|---|---|
| A normal build (`mvn verify`, CI on every push) that **calls the real API** | Cost, flakiness, a key in CI for no reason |
| No test for the refusal, cut-off and unparseable cases | They are the ones that happen in production first |
| Tests that assert only on the model's (canned) answer, never on **the request sent** (placement, schema, cache marker) | The request is the part you control |
| e2e tests without the model fake | They'd cost money and give a different answer each run |
| Eval cases labelled by the model that's being evaluated | The score flatters it |
