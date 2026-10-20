# e2e

End-to-end tests: the app and its infrastructure in Testcontainers (fresh databases, random port, nothing shared),
driven by Playwright through the API (and the UI, once there is one). Needs Docker and Node 22+.

```bash
npm install                 # first time (then commit package-lock.json and use npm ci)
npx playwright install chromium
npm run stack:build         # builds __APP__:e2e from the project's Dockerfile; re-run after code changes
npx playwright test         # starts the stack, runs the tests, removes the stack
```

What the stack runs: `stack/stack.config.ts`. How to write tests: `.claude/skills/e2e-testing/SKILL.md`.
