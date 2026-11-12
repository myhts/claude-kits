# Checklists

## Review: Correct, Safe, Reliable, Fast, Clear

Most serious first. Each finding names its `file:line`, an input that breaks it, how bad it is, and the fix. A finding
without a `file:line` doesn't count.

1. **Correct:** a wrong result; boundaries and off-by-one; null and empty; duplicates and "called twice"; check-then-act
   races; money and rounding; dates and time zones; an error swallowed.
2. **Safe:** untrusted input reaching a query, a shell, HTML or a prompt; a missing permission check; secrets in code or
   logs.
3. **Reliable:** a remote call with no timeout; retries with no backoff or idempotency; a resource never closed; a
   failure that leaves half-written state.
4. **Fast:** a query in a loop (N+1); loading everything to use a little; blocking work on a hot path. Measure before
   you claim it.
5. **Clear:** misleading names, duplicated logic, missing tests, one function doing three jobs. Mention it; don't lead
   with it.

**Guard the bar:** also look in the diff for a test made easier, a threshold moved, a check silenced, a skipped test
or a stub.

## When it's an AI feature

- The model sits behind an interface; tests use a fake and never call the real API.
- Structured output is checked against a schema, and every stop reason is handled: out of tokens, refusal.
- User text is data and never changes the instructions. Tools get the least power they need.
- A timeout, one retry with backoff, and a fallback answer.
- A five-case eval as a test, run against the real model only behind a flag, reporting the pass rate.
- The smallest model that passes the eval; tokens and cost per request logged.
- A human approves anything risky an agent would do. Logs carry no secrets or personal data.

## Architecture and scale in a Build round

- The logic in plain functions with no I/O, tested directly. The edges (HTTP, storage, the model) behind small
  interfaces, with fakes for the tests.
- Build for one machine and explain the rest: at 1×, 10× and 100×, what breaks first and what you'd change. Use the
  brief's numbers. Where there are none, say "unknown" and give the shape of the bottleneck; never invent a number.

## Traps

- Rewriting instead of fixing.
- Code before a failing test.
- Trusting the AI's diagnosis without a check.
- Fixing one copy of a bug and missing the second.
- Skipping the full test run.
- Leading with style.
- Going silent while you read.
- Pasting big blocks you can't explain.
