// The first e2e test of any project: the app, built from your code, starts against real infrastructure and
// says it's healthy. Replace or extend it with your first real flow (see .claude/skills/e2e-testing).
import { expect, test } from '@playwright/test';

test('the app starts and reports healthy @smoke', async ({ request }) => {
  const health = await request.get('/actuator/health');
  expect(health.status()).toBe(200);
  expect(await health.json()).toMatchObject({ status: 'UP' });
});

test('unknown paths answer 404, not a stack trace @smoke', async ({ request }) => {
  const r = await request.get('/this-does-not-exist');
  expect(r.status()).toBe(404);
  expect(await r.text()).not.toMatch(/Exception|at [a-z]+\.[A-Za-z.]+\(/);
});
