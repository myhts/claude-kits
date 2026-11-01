#!/usr/bin/env bash
# Proves the --ai part of the kit on this Spring Boot app, the way a project gets it. No API key, no cost:
#   1. the LLM code shapes: the unit tests in com.example.kitcheck.llm (a local fake of POST /v1/messages)
#   2. copy kit-check to a temp folder and run install.sh --e2e --ai on it (skill, CLAUDE.ai.md, e2e/llm-fake)
#   3. run the app in the e2e stack with the llm-fake (WireMock) and call it: an extraction, a refusal, an overload
#   4. lint the CI eval workflow (actionlint, offline), then remove the temp folder and the image
# Needs Docker and Node 22+.
#   ./verify-ai.sh
set -euo pipefail
cd "$(dirname "$0")"
KIT="$(cd .. && pwd)"
WORK="$(mktemp -d)/kit-check"
IMAGE=kit-check:e2e ACTIONLINT=rhysd/actionlint:1.7.7
cleanup() { docker rmi "$IMAGE" >/dev/null 2>&1 || true; rm -rf "$(dirname "$WORK")"; }
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
[ -z "${ANTHROPIC_API_KEY:-}" ] || echo "   (ANTHROPIC_API_KEY is set in this shell; nothing here uses it)"

echo "== 1. LLM code shapes (unit tests, fake API)"
env -u ANTHROPIC_API_KEY -u RUN_LIVE_EVALS ./mvnw -q test -Dtest='com.example.kitcheck.llm.*Test' -Dsurefire.failIfNoSpecifiedTests=false \
  | tail -5
echo "   llm unit tests: passed"

echo "== 2. install the kit with --e2e --ai into a copy of kit-check"
mkdir -p "$WORK" && cp -R pom.xml mvnw .mvn src "$WORK/"
"$KIT/install.sh" "$WORK" --e2e --ai | grep -E "^Target|^Added"
for f in .claude/skills/llm-engineering/SKILL.md .claude/skills/llm-engineering/review-checklist.md \
         .claude/skills/llm-engineering/ci-evals.yml CLAUDE.ai.md e2e/llm-fake/mappings/messages.json; do
  [ -f "$WORK/$f" ] || fail "install.sh --ai didn't add $f"
done
# kit-check has no actuator: wait on one of its endpoints instead (as in verify-e2e.sh)
perl -pi -e "s|readyPath: '/actuator/health'|readyPath: '/api/v1/authors'|" "$WORK/e2e/stack/stack.config.ts"
# turn the model fake on: the edit a project makes in stack.config.ts
perl -0pi -e "s|llmFake: null as null|llmFake: { image: 'wiremock/wiremock:3.13.2', mappingsDir: 'llm-fake/mappings', baseUrlEnv: 'APP_CLAUDE_BASE_URL' } as null|" "$WORK/e2e/stack/stack.config.ts"
grep -q "wiremock/wiremock:3.13.2" "$WORK/e2e/stack/stack.config.ts" || fail "couldn't enable llmFake"
rm "$WORK/e2e/tests/smoke/app-is-up.spec.ts"
cat > "$WORK/e2e/tests/smoke/claims.spec.ts" <<'EOF'
import { expect, test } from '@playwright/test';

test('an email becomes a structured claim (canned model answer) @smoke', async ({ request }) => {
  const r = await request.post('/api/v1/claims/extract', { data: { email: 'My suitcase never arrived. Dana' } });
  expect(r.status()).toBe(200);
  expect(await r.json()).toMatchObject({ lossType: 'BAGGAGE_LOST', amountClaimed: '1250.00', currency: 'GBP' });
});

test('a refusal is a 422 for a claims handler, not a guess @smoke', async ({ request }) => {
  const r = await request.post('/api/v1/claims/extract', { data: { email: 'please e2e-refuse this one' } });
  expect(r.status()).toBe(422);
  expect(r.headers()['content-type']).toContain('application/problem+json');
  expect((await r.json()).detail).toContain('claims handler');
});

test('an overloaded model is a 503 with Retry-After, after the SDK retries @smoke', async ({ request }) => {
  const r = await request.post('/api/v1/claims/extract', { data: { email: 'e2e-overloaded' } });
  expect(r.status()).toBe(503);
  expect(r.headers()['retry-after']).toBe('30');
});
EOF

echo "== 3. build and run against the model fake"
cd "$WORK/e2e"
npm install --no-audit --no-fund --silent
npx tsc --noEmit
npx playwright install chromium >/dev/null
npm run -s stack:build
npx playwright test --reporter=list > run.log 2>&1 || true
grep -E "ready|✓|✘|passed|failed" run.log || true
grep -qE "^\s+3 passed" run.log || { tail -60 run.log; fail "the e2e run against the model fake didn't pass"; }

echo "== 4. lint the CI eval workflow"
ci_dir="$(dirname "$WORK")/ci" && mkdir -p "$ci_dir/.github/workflows"
cp "$WORK/.claude/skills/llm-engineering/ci-evals.yml" "$ci_dir/.github/workflows/evals.yml"
docker run --rm -v "$ci_dir":/repo:ro -w /repo "$ACTIONLINT" -no-color .github/workflows/evals.yml || fail "actionlint found problems in the eval workflow"
echo "   actionlint: no problems"

echo "== all --ai checks passed"
