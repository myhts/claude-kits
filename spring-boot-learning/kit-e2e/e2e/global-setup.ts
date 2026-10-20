// Before the tests: reuse a running stack (E2E_BASE_URL, e.g. from `npm run stack:up`), or start a fresh one in
// Testcontainers and remove it afterwards. Add a warm-up here if the first request is slow (JIT, consumers joining).
import type { FullConfig } from '@playwright/test';
import { startStack } from './stack/stack.ts';
import { assertAllowedTarget } from './support/guard.ts';

export default async function globalSetup(_config: FullConfig) {
  let stop: (() => Promise<void>) | undefined;
  if (process.env.E2E_BASE_URL) {
    console.log(`e2e: using the running stack at ${process.env.E2E_BASE_URL}`);
  } else {
    console.log('e2e: starting the stack in Testcontainers…');
    const stack = await startStack();
    process.env.E2E_BASE_URL = stack.baseUrl;   // read by playwright.config.ts in every worker
    stop = stack.stop;
  }
  assertAllowedTarget(process.env.E2E_BASE_URL);
  return async () => {
    if (stop) {
      console.log('e2e: stopping the stack');
      await stop();
    }
  };
}
