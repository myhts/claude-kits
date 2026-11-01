#!/usr/bin/env bash
# Proves the --web part of the kit on this Spring Boot app, the way a project gets it:
#   1. copy kit-check to a temp folder and run install.sh --e2e --web on it (web/ template, react-frontend skill)
#   2. point the sample feature at this app's /api/v1/authors; npm ci, typecheck and build the front end
#   3. build both images (app + web/nginx), turn on the stack's `web` service, and drive the UI with Playwright:
#      add an author through the form and see it in the list; a blank name shows the server's problem detail;
#      nginx proxies /api and sends the security headers; no console errors (the CSP blocks nothing the app needs)
#   4. remove the temp folder, the images and the containers
# Needs Docker and Node 22+. npm fetches packages (or uses the npm cache). Nothing here calls a model or needs a key.
#   ./verify-web.sh
set -euo pipefail
cd "$(dirname "$0")"
KIT="$(cd .. && pwd)"
WORK="$(mktemp -d)/kit-check"
IMAGES=(kit-check:e2e kit-check-web:e2e)
cleanup() { docker rmi "${IMAGES[@]}" >/dev/null 2>&1 || true; rm -rf "$(dirname "$WORK")"; }
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

echo "== 1. install the kit with --e2e --web into a copy of kit-check"
mkdir -p "$WORK" && cp -R pom.xml mvnw .mvn src "$WORK/"
"$KIT/install.sh" "$WORK" --e2e --web | grep -E "^Target|^Added"
for f in web/package.json web/package-lock.json web/Dockerfile web/nginx/default.conf.template web/src/api/client.ts \
         web/src/features/items/api.ts .claude/skills/react-frontend/SKILL.md e2e/stack/stack.config.ts; do
  [ -f "$WORK/$f" ] || fail "install.sh --web didn't add $f"
done
! grep -rq '__APP__\|<APP>' "$WORK/web" "$WORK/e2e" || fail "placeholders left after install"

echo "== 2. adapt the sample feature to this app, then typecheck and build"
# the template's sample talks to /api/v1/items with {id, name}; kit-check's authors API has the same shape (+ titles)
perl -pi -e "s|const PATH = '/api/v1/items';|const PATH = '/api/v1/authors';|" "$WORK/web/src/features/items/api.ts"
grep -q "/api/v1/authors" "$WORK/web/src/features/items/api.ts" || fail "couldn't point the sample at /api/v1/authors"
(cd "$WORK/web" && npm ci --no-audit --no-fund --silent && npm run -s build)
[ -f "$WORK/web/dist/index.html" ] || fail "the front end didn't build"
! grep -q "<script>" "$WORK/web/dist/index.html" || fail "an inline script would be blocked by the CSP"
echo "   front end typechecked and built"

echo "== 3. images, stack with the web service, UI tests"
# kit-check has no actuator: wait on one of its endpoints instead (the kind of edit stack.config.ts is for)
perl -pi -e "s|readyPath: '/actuator/health'|readyPath: '/api/v1/authors'|" "$WORK/e2e/stack/stack.config.ts"
perl -pi -e "s#^  web: null as null \\| \\{ image: string; port: number; upstreamEnv: string \\},#  web: { image: 'kit-check-web:e2e', port: 8080, upstreamEnv: 'API_UPSTREAM' } as null | { image: string; port: number; upstreamEnv: string },#" "$WORK/e2e/stack/stack.config.ts"
grep -q "web: { image: 'kit-check-web:e2e'" "$WORK/e2e/stack/stack.config.ts" || fail "couldn't turn on the web service"
rm "$WORK/e2e/tests/smoke/app-is-up.spec.ts"      # needs actuator; replaced by the UI flow below
cat > "$WORK/e2e/tests/smoke/web.spec.ts" <<'EOF'
import { expect, test } from '@playwright/test';
import { newKey } from '../../support/api.ts';

test('add an item through the form, then see it in the list @smoke @writes', async ({ page }, testInfo) => {
  const errors: string[] = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  const name = newKey(testInfo.workerIndex);

  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Items' })).toBeVisible();
  await page.getByLabel('Name').fill(name);
  await page.getByRole('button', { name: 'Add' }).click();

  await expect(page.getByRole('list', { name: 'Items' }).getByText(name)).toBeVisible();
  await expect(page.getByLabel('Name')).toHaveValue('');
  expect(errors, 'console errors (a CSP violation shows up here)').toEqual([]);
});

test('a blank name shows the server problem detail @smoke', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Add' }).click();

  await expect(page.getByRole('alert')).toHaveText('request is invalid');
  await expect(page.getByLabel('Name')).toHaveAttribute('aria-invalid', 'true');
  await expect(page.getByText('must not be blank')).toBeVisible();
});

test('nginx proxies the API and sends the security headers @smoke', async ({ request }) => {
  const home = await request.get('/');
  expect(home.status()).toBe(200);
  expect(home.headers()['content-security-policy']).toContain("default-src 'self'");
  expect(home.headers()['x-content-type-options']).toBe('nosniff');
  expect(home.headers()['cache-control']).toBe('no-cache');
  const api = await request.get('/api/v1/authors');
  expect(api.status()).toBe(200);
  expect(api.headers()['content-type']).toContain('application/json');
  expect((await request.get('/some/client/route')).status()).toBe(200);   // SPA fallback to index.html
});
EOF
cd "$WORK/e2e"
npm install --no-audit --no-fund --silent
npx tsc --noEmit
npx playwright install chromium >/dev/null
npm run -s stack:build
docker image inspect kit-check-web:e2e >/dev/null 2>&1 || fail "stack:build didn't build the web image"
npx playwright test --reporter=list 2>&1 | tee run.log | grep -E "ready|✓|✘|passed|failed"
grep -qE "^\s+3 passed" run.log || fail "the web e2e run didn't pass"
[ -z "$(docker ps -q --filter label=purpose=e2e)" ] || fail "e2e containers left running"

echo "ALL WEB CHECKS PASSED"
