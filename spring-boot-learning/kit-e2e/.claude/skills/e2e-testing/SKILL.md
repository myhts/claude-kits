---
name: e2e-testing
description: End-to-end tests for this project - Playwright Test against the app and its infrastructure in Testcontainers (fresh databases, random port), waiting on asynchronous work without sleeps, scenario tables checked by an independent oracle, pinned known bugs, a localhost-only guard, and the Playwright MCP for exploring a running stack. Use when writing, running, debugging or reviewing anything in e2e/.
---

# End-to-end tests (e2e/)

The application runs in containers on a private network; Playwright drives it through the API and, once there is
a front end, the browser. Fresh, empty databases every run. Only one container is published, on a random
localhost port, so nothing clashes with anything else on the machine.

Proven first on a real Spring Boot + Kafka + React project (17 tests, 340/340 on a 20× repeat run), then
generalised; the template's own checks run on a plain Spring Boot app in the kit's `kit-check`.

## First run

```bash
cd e2e
npm install && npx playwright install chromium     # once; commit package-lock.json, then use npm ci
npm run stack:build                                # docker build -t <app>:e2e . from the project's Dockerfile
npx playwright test                                # starts the stack, runs the tests, removes the stack
npm run report                                     # HTML report; failed tests keep a trace
```

No Dockerfile yet? Ask "use the implementer to add the Dockerfile from build-templates".

Faster loop: `npm run stack:up` (one terminal; prints `READY http://localhost:<port>` and writes `e2e/.stack-url`;
Ctrl+C removes it), then `E2E_BASE_URL=$(cat .stack-url) npx playwright test` as often as you like.

## Shape the stack: `stack/stack.config.ts`

| Setting | Use |
|---|---|
| `app.image`, `app.port`, `app.readyPath` | The app's image, port, and a URL that answers 200 when it can serve (actuator health) |
| `app.memoryGb`, `app.env` | Container memory (the JVM takes 75% as heap) and extra settings |
| `postgres` | On by default; the app gets `SPRING_DATASOURCE_URL/USERNAME/PASSWORD` |
| `kafka`, `redis` | Off by default; set `{ image: … }` and the app gets the bootstrap servers / host |
| `web` | A front end image (e.g. nginx proxying `/api` to `http://app:<port>`); then it's what's published |

One-off settings for a run (e.g. a fault-injection switch for a lab): `E2E_APP_ENV='KEY=value KEY2=value'`.
Docker memory is finite: Postgres 0.25 GB, Kafka 0.5 GB, app 0.64 GB. Check `docker stats` before adding more.

## Rules for writing tests

1. **Never sleep.** For anything asynchronous (a 202 + Location, a queue, a projection) wait for a condition:
   `eventually(...)` in `support/api.ts`, `expect.poll`, auto-retrying `await expect(locator)...`, `page.waitForResponse`.
2. **Assert on the system's answers**: status codes, headers, JSON, and the state you can read back, not only text.
3. **Expected values come from an oracle**, never from copying what the system returned. Restate the rules and
   reference data independently in `e2e/oracle/` (cite the source: a spec, a migration, a class), in exact
   arithmetic for money (BigInt cents with the system's rounding), and print the rule behind each number on failure.
4. **Scenario tables for rules**: one row per case with `covers` (why the row exists); edges first (minimums,
   rounding boundaries, limits ± one cent, zero, empty). Add "universal checks" that hold for every row.
5. **Pin known bugs, don't skip them.** A row with `knownBug: '<where it's documented>'` asserts the current wrong
   behaviour exactly; when the bug is fixed it fails with "known bug looks FIXED", and you remove the marker.
   (Don't use `test.fail()`: it would also accept unrelated failures.)
6. **User-facing selectors** in UI tests: `getByRole`, `getByLabel`, `getByText`. No CSS classes or XPath.
7. **Independent tests**: tag created data with `newKey(testInfo.workerIndex)`; never rely on order or shared data.
8. **Tags in titles**: `@smoke` (main path), `@writes` (creates data), `@local` (needs a lab switch), plus a feature tag.
9. **Prove it isn't flaky** before trusting or adding to CI: `--repeat-each=20` against a running stack, then `--workers=6`.

## A scenario table with an oracle (the pattern)

```ts
// tests/pricing/scenarios.ts
export const SCENARIOS = [
  { name: 'below minimum', input: '120', covers: '120 × 0.10% = 0.12 < minimum 0.50' },
  { name: 'over the limit', input: '100000.01', covers: 'decline rule, one cent over', knownBug: 'BUGS.md#12' },
];

// tests/pricing/pricing.spec.ts
for (const s of SCENARIOS) {
  test(`${s.name} @pricing @writes`, async ({ request }, testInfo) => {
    const expected = oracle(s.input);                        // independent: never the system's own output
    const created = await request.post('/api/v1/things', { data: { value: s.input }, headers: { 'Idempotency-Key': newKey(testInfo.workerIndex) } });
    const thing = await eventually(request, created.headers()['location'], (b: any) => b.status !== 'PENDING');
    expect(thing.price, expected.why.join('\n')).toBe(expected.price);
  });
}
```

## Safety

- `support/guard.ts` refuses any host but this machine: e2e tests write data. `E2E_ALLOWED_HOSTS` only for an
  environment you own and may write to. Never production, never a shared machine, by default.
- Images are tagged `:e2e`; the stack labels its containers `purpose=e2e`; Testcontainers removes everything
  even if the run crashes.

## The Playwright MCP (Claude's browser)

`.mcp.json` registers it, limited to `http://localhost:*` and `http://127.0.0.1:*`. That prevents accidents; it
is **not** a security boundary (the MCP's own docs say so). Rule: only ever open the URL in `e2e/.stack-url`.
Use it to explore a screen, find accessible names for selectors, or replay a failing step; then write the test in
code. The suite, not the MCP, is what runs in CI. Claude Code asks you to approve the server the first time.

## Debugging a failure

1. `npm run report` → the test → Trace: actions, network calls, DOM snapshots, console.
2. Read the oracle's `why` lines: which rule and number disagreed.
3. Re-run one test against a running stack: `E2E_BASE_URL=$(cat .stack-url) npx playwright test -g "<title>"`.
4. App logs: `docker ps --filter label=purpose=e2e`, then `docker logs <container>`.

## CI (when the suite is stable)

A job that runs `npm ci`, `npx playwright install --with-deps chromium`, `npm run stack:build`, then
`E2E_STRICT_IMAGES=1 npx playwright test`, and uploads `playwright-report/` on failure. GitHub's Ubuntu runners
have Docker, so Testcontainers works there unchanged.
