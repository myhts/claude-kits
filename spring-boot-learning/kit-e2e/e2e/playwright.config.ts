import { defineConfig, devices } from '@playwright/test';

// E2E_BASE_URL is set by global-setup.ts (a fresh Testcontainers stack) or by you (a stack that's already up).
// The run id tags everything this run creates: see newKey() in support/api.ts.
process.env.E2E_RUN_ID ??= new Date().toISOString().replace(/\D/g, '').slice(0, 14);

export default defineConfig({
  testDir: './tests',
  globalSetup: './global-setup.ts',
  fullyParallel: true,
  workers: process.env.CI ? 2 : 3,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,          // locally a failure is a failure: flakiness should be seen, not hidden
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'test-results/results.json' }],
  ],
  use: {
    baseURL: process.env.E2E_BASE_URL,
    trace: 'retain-on-failure',             // a failed test leaves a trace: npm run report
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
