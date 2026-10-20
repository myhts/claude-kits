// Helpers for talking to the API directly: set up and check state without the UI, wait for asynchronous work
// without sleeping, and tag everything a run creates so it can be found afterwards.
import { expect, type APIRequestContext } from '@playwright/test';

/** Run-tagged ids (e.g. for Idempotency-Key headers or names): e2e-<run>-w<worker>-<n>. */
let counter = 0;
export function newKey(workerIndex: number): string {
  return `e2e-${process.env.E2E_RUN_ID ?? 'local'}-w${workerIndex}-${++counter}`;
}

/**
 * Polls a GET until `done(body)` is true: for anything asynchronous (a 202 + Location, a queue, a projection).
 * Never replace this with a sleep: a sleep is too long on a fast machine and too short on a slow one.
 */
export async function eventually<T>(request: APIRequestContext, url: string, done: (body: T) => boolean,
                                    options: { headers?: Record<string, string>; timeout?: number } = {}): Promise<T> {
  let last: T | undefined;
  await expect.poll(async () => {
    const r = await request.get(url, { headers: options.headers });
    last = r.ok() ? await r.json() : undefined;
    return last !== undefined && done(last);
  }, { message: `${url} to reach the expected state`, timeout: options.timeout ?? 20_000, intervals: [100, 200, 500, 1000] })
    .toBe(true);
  return last!;
}
