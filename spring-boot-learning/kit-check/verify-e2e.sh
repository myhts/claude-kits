#!/usr/bin/env bash
# Proves the --e2e part of the kit on this Spring Boot app, the way a project gets it:
#   1. copy kit-check to a temp folder and run install.sh --e2e on it (Dockerfile, e2e/, skill, agent, .mcp.json)
#   2. npm install, build the app image, run the template's tests + an API flow test against the Testcontainers stack
#   3. check the stale-image warning, then remove the temp folder and the image
# Needs Docker and Node 22+. npm install fetches packages (or uses the npm cache).
#   ./verify-e2e.sh
set -euo pipefail
cd "$(dirname "$0")"
KIT="$(cd .. && pwd)"
WORK="$(mktemp -d)/kit-check"
IMAGE=kit-check:e2e
cleanup() { docker rmi "$IMAGE" >/dev/null 2>&1 || true; rm -rf "$(dirname "$WORK")"; }
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

echo "== 1. install the kit with --e2e into a copy of kit-check"
mkdir -p "$WORK" && cp -R pom.xml mvnw .mvn src "$WORK/"
"$KIT/install.sh" "$WORK" --e2e | grep -E "^Target|^Added"
for f in Dockerfile e2e/stack/stack.config.ts .claude/skills/e2e-testing/SKILL.md .claude/agents/e2e-tester.md .mcp.json; do
  [ -f "$WORK/$f" ] || fail "install.sh --e2e didn't add $f"
done
! grep -rq '__APP__\|<APP>' "$WORK/e2e" "$WORK/Dockerfile" || fail "placeholders left after install"
# kit-check has no actuator: wait on one of its endpoints instead (this is the kind of edit stack.config.ts is for)
perl -pi -e "s|readyPath: '/actuator/health'|readyPath: '/api/v1/authors'|" "$WORK/e2e/stack/stack.config.ts"
# the template's health test needs actuator too: replace it with this app's own API flow
rm "$WORK/e2e/tests/smoke/app-is-up.spec.ts"
cat > "$WORK/e2e/tests/smoke/authors.spec.ts" <<'EOF'
import { expect, test } from '@playwright/test';
import { eventually, newKey } from '../../support/api.ts';

test('create an author, then find it in the list @smoke @writes', async ({ request }, testInfo) => {
  const name = newKey(testInfo.workerIndex);
  const created = await request.post('/api/v1/authors', { data: { name, titles: ['Notes'] } });
  expect(created.status()).toBe(201);
  const list = await eventually<{ name: string }[]>(request, '/api/v1/authors', (b) => b.some((a) => a.name === name));
  expect(list.find((a) => a.name === name)).toMatchObject({ name, titles: ['Notes'] });
});

test('invalid input is a 400 problem detail @smoke', async ({ request }) => {
  const r = await request.post('/api/v1/authors', { data: { name: ' ' } });
  expect(r.status()).toBe(400);
  expect(r.headers()['content-type']).toContain('application/problem+json');
});
EOF

echo "== 2. build and run"
cd "$WORK/e2e"
npm install --no-audit --no-fund --silent
npx tsc --noEmit
npx playwright install chromium >/dev/null
npm run -s stack:build
npx playwright test --reporter=list 2>&1 | tee run.log | grep -E "ready|✓|✘|passed|failed"
grep -qE "^\s+2 passed" run.log || fail "the e2e run didn't pass"

echo "== 3. stale-image warning"
sleep 1; touch "$WORK/pom.xml"
E2E_STRICT_IMAGES=1 npx playwright test >strict.log 2>&1 && fail "a stale image wasn't caught"
grep -q "older than the code" strict.log || fail "unexpected failure: $(tail -5 strict.log)"
echo "   stale image refused under E2E_STRICT_IMAGES=1"
[ -z "$(docker ps -q --filter label=purpose=e2e)" ] || fail "e2e containers left running"

echo "ALL E2E CHECKS PASSED"
