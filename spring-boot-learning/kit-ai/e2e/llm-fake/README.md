# llm-fake: canned Claude answers for the e2e stack

WireMock answers `POST /v1/messages` from `mappings/*.json`, so end-to-end tests never call the real model: no key,
no cost, the same answer every run. Turn it on in `stack/stack.config.ts`:

```ts
llmFake: { image: 'wiremock/wiremock:3.13.2', mappingsDir: 'llm-fake/mappings', baseUrlEnv: 'APP_CLAUDE_BASE_URL' },
```

The app then gets `APP_CLAUDE_BASE_URL=http://llm-fake:8080` (bind it to the client's base URL, e.g.
`app.claude.base-url`) and `ANTHROPIC_API_KEY=e2e-fake-key`.

- One mapping per behaviour a test needs, chosen by a marker in the request body (`e2e-refuse`, `e2e-overloaded`)
  or by `bodyPatterns` on the input; lower `priority` wins. The default answers everything else.
- Keep each response in the real shape (`id`, `type`, `role`, `model`, `content`, `stop_reason`, `usage`); copy new
  ones from a recorded live response rather than writing them from memory.
- What the e2e run proves is **the app around the model** (wiring, routing, error handling, the UI). Model quality is
  the eval's job, not the e2e's.
