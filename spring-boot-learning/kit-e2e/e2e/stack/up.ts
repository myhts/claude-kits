// Starts the stack and keeps it running until Ctrl+C: for writing tests with the Playwright MCP, exploring by
// hand, or re-running the tests without restarting it (E2E_BASE_URL=$(cat .stack-url) npx playwright test).
//   npm run stack:up
import { rmSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { startStack } from './stack.ts';

const urlFile = resolve(import.meta.dirname, '../.stack-url');
console.log('starting the e2e stack…');
const stack = await startStack();
writeFileSync(urlFile, stack.baseUrl + '\n');
console.log(`\nREADY ${stack.baseUrl}  (also in e2e/.stack-url)\nCtrl+C to stop and remove everything.`);

let stopping = false;
const shutdown = async () => {
  if (stopping) return;
  stopping = true;
  console.log('\nstopping…');
  rmSync(urlFile, { force: true });
  await stack.stop();
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
setInterval(() => undefined, 1 << 30);   // keep the process alive
