---
name: react-frontend
description: The project's front end in web/ - React 19 + Vite + TypeScript + TanStack Query, organised by feature, talking to the Spring Boot API through /api (nginx in the image, Vite in development, so no CORS), RFC 9457 problem details shown in forms, loading/error/empty states, accessible markup that matches the e2e tests' getByRole selectors, user and model text rendered safely, and the nginx image with security headers. Verified end to end against a Spring Boot 4.1.1 API. Use when building, reviewing or testing anything in web/.
---

# React front end (web/)

**Verified** (2026-10-25) by the kit's `kit-check/verify-web.sh`: it installs the template with `--e2e --web` into a
copy of a Spring Boot 4.1.1 app, points the sample feature at the app's API, typechecks and builds it, builds the
app and web images, starts the e2e stack with the `web` service (nginx in front of the app, Postgres behind it) and
drives the UI with Playwright: create through the form and see it in the list, a blank field shows the server's
problem detail and marks the input invalid, nginx proxies `/api` and sends the security headers, the SPA fallback
works, and the page logs no console errors (so the CSP blocks nothing the app needs).
**Not covered:** component tests (there are none in the template), routing, authentication.

Versions (exact, each released at least two weeks before 2026-10-25): react / react-dom 19.3.0, @tanstack/react-query
5.104.1, vite 8.3.4, @vitejs/plugin-react 6.1.2, typescript 7.0.2, @types/react(-dom) 19.3.0; images
`node:22.23.3-alpine3.24` (build) and `nginxinc/nginx-unprivileged:1.30.4-alpine3.24` (serve).

## Layout

```
web/
  src/main.tsx                 QueryClient + providers
  src/App.tsx                  the page(s); add a router only when there's a second page
  src/api/client.ts            the only code that calls fetch: JSON in/out, ProblemError from problem details
  src/features/<feature>/      one folder per bounded context / feature (mirrors the backend's modules)
    api.ts                     the feature's endpoints, query keys and hooks (useX, useCreateX)
    XPage.tsx, XForm.tsx       screens
  nginx/                       the image's server config (template + security headers)
  Dockerfile, package.json, package-lock.json (commit it; npm ci in the image)
```

- **A feature owns its API calls, its query keys and its screens.** Features don't import each other's internals;
  shared UI pieces go in `src/components/` once a second feature needs them, not before.
- The sample feature `src/features/items/` is marked REPLACE ME. Copy its shape, then delete it.
- No global state library: server data lives in TanStack Query's cache; form state lives in the component.

## Talking to the API

- **Same origin**: the browser calls `/api/...`; Vite (`npm run dev`, `API_UPSTREAM`, default `http://localhost:8080`)
  or nginx (`API_UPSTREAM` env in the image, default `http://app:8080`) forwards it. No CORS configuration, no API
  URL baked into the bundle: the same image runs in every environment.
- **Errors are problem details.** `client.ts` turns an `application/problem+json` response into a `ProblemError`
  with `status`, `title`, `detail` and `fields` (the kit's `ApiExceptionHandler` lists invalid fields there). A
  non-problem error becomes a `ProblemError` with the status text.
- **Retries**: queries retry once for a network blip and never for a 4xx (`retryUnlessClientError`): asking again
  won't change the server's mind. Mutations don't retry: a POST isn't idempotent unless the API takes an
  idempotency key.

## Data with TanStack Query

```ts
const keys = { all: ['items'] as const };

export function useItems() {
  return useQuery({ queryKey: keys.all, queryFn: () => getJson<Item[]>(PATH) });
}

export function useCreateItem() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (item: NewItem) => postJson<Item>(PATH, item),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: keys.all }),   // the server is the truth: refetch
  });
}
```

- Query keys in one object per feature, so a mutation invalidates exactly what it changed. Verified: the created
  item appears in the list after the POST, through the invalidation, with no manual cache edit.
- `staleTime: 10_000` by default: switching tabs doesn't refetch everything. Lower it for data that changes under
  the user (a work queue), or poll with `refetchInterval`.
- After a write the API answers `202 Accepted` (asynchronous)? Invalidate, and let the list show the pending
  state the API reports; don't fake the result in the cache.

## Every screen has four states

Loading, failed, empty and the data. The sample shows all four. A failed load is a `role="alert"` with the
server's message; an empty list says so in words ("No items yet"), never a blank area.

## Forms

- **The server validates; the form shows what it says.** The sample uses `noValidate` and no client rules, so the
  problem detail's `detail` goes in a `role="alert"` and each `fields[name]` message sits next to its input,
  linked with `aria-describedby`, with `aria-invalid="true"` on the input. Verified with a blank name: the alert
  reads "request is invalid", the input is marked invalid and "must not be blank" is shown.
- Client-side checks can be added for speed, but the server's answer stays authoritative.
- Disable the submit button while pending, and clear the form only on success.

## Accessibility and the e2e selectors

The e2e tests find things the way a user does (`getByRole`, `getByLabel`, `getByText`): if a test can't find an
element that way, neither can a screen reader. So:

- Every input has a `<label htmlFor>` (`useId()` for the id); buttons have visible text.
- Regions and lists have names (`<section aria-labelledby>`, `<ul aria-label="Items">`), so tests can scope
  (`getByRole('list', { name: 'Items' })`).
- Errors use `role="alert"`; headings form an outline (one `h1` per page).
- No CSS-class or XPath selectors in tests, and no `data-testid` unless there is truly no user-facing handle.

## Text from users and from the model

- **Render it as text.** React escapes `{value}`. Never `dangerouslySetInnerHTML` for user or model content: a
  claim description or a model's explanation can contain markup, and the model can be steered to produce it.
- If formatted model output is really needed (Markdown), render it with a library that doesn't allow raw HTML, and
  keep the CSP.
- Show model output as a **recommendation** with its sources (citations), not as a decision, and make the human's
  action (approve, override) the explicit step.

## The image

- Build stage `npm ci && npm run build` (typecheck first), then `nginx-unprivileged` (runs as uid 101, listens on
  8080) serving `dist/`.
- `nginx/default.conf.template` is rendered at container start by the image's envsubst step: only variables set
  in the environment (`API_UPSTREAM`) are replaced, so nginx's own `$uri`, `$host` stay intact.
- `/assets/*` (hashed names) are cached for a year; `index.html` is `no-cache`, so a deploy shows up at once; unknown
  paths fall back to `index.html` for client-side routes. Verified.
- **Security headers in every location** (`nginx/security-headers.conf` is included in each: an `add_header` inside
  a location drops the server-level ones): CSP `default-src 'self'` with no inline scripts or styles (Vite's
  production build has none; verified no console errors), `nosniff`, `X-Frame-Options: DENY`,
  `Referrer-Policy: no-referrer`.
- The app image's `.dockerignore` (build-templates) excludes `web/` and `e2e/`, so their `node_modules` aren't sent
  to the app build.

## Testing

| Layer | How | Status in the template |
|---|---|---|
| Type check | `npm run typecheck` (also first step of `npm run build`) | Yes |
| End to end, the main layer | The e2e stack's `web` service: `{ image: '<app>-web:e2e', port: 8080, upstreamEnv: 'API_UPSTREAM' }` in `e2e/stack/stack.config.ts`; `npm run stack:build` builds both images; Playwright drives the real UI against the real API and database | Verified by `verify-web.sh` |
| Component tests | Vitest + Testing Library, for complex UI logic only | Not included: add them when a component has logic worth testing on its own, and verify them before relying on them |

Write UI tests by the e2e-testing skill's rules: user-facing selectors, wait on conditions (auto-retrying
`expect(locator)`), unique data per test (`newKey`), never sleep.
