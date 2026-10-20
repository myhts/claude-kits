// The stack runs images built from this repo. If the code changed after the image was built, the tests would
// exercise yesterday's code: warn (or, with E2E_STRICT_IMAGES=1, as in CI, fail) and say how to rebuild.
// "Changed" = the newest file modification time under the sources, so it works with or without git.
import { execFileSync } from 'node:child_process';
import { readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { STACK } from './stack.config.ts';

const REPO = resolve(import.meta.dirname, '../..');

/** Images we build ourselves, and the paths (relative to the repo root) their code comes from. */
const OWN = [{ tag: STACK.app.image, sources: ['src', 'pom.xml', 'Dockerfile'] }];

function builtAt(tag: string): Date | null {
  try {
    return new Date(execFileSync('docker', ['image', 'inspect', '--format', '{{.Created}}', tag], { encoding: 'utf8' }).trim());
  } catch {
    return null;
  }
}

function newestChange(path: string): number {
  let stat;
  try { stat = statSync(path); } catch { return 0; }
  if (!stat.isDirectory()) return stat.mtimeMs;
  return readdirSync(path).reduce((max, name) => Math.max(max, newestChange(join(path, name))), stat.mtimeMs);
}

export function checkImages(): void {
  const problems: string[] = [];
  for (const { tag, sources } of OWN) {
    const built = builtAt(tag);
    const changed = Math.max(...sources.map((s) => newestChange(resolve(REPO, s))));
    if (!built) problems.push(`${tag} doesn't exist`);
    else if (changed > built.getTime() + 1000) problems.push(`${tag} is older than the code (built ${built.toISOString()})`);
  }
  if (problems.length === 0) return;
  const message = `e2e images: ${problems.join('; ')}.\n  Rebuild: npm run stack:build`;
  if (problems.some((p) => p.endsWith("doesn't exist")) || process.env.E2E_STRICT_IMAGES === '1') throw new Error(message);
  console.warn(`WARNING ${message}\n  (testing the image as it is; set E2E_STRICT_IMAGES=1 to make this an error)`);
}
