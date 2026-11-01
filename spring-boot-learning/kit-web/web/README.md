# web: the front end

React + Vite + TypeScript + TanStack Query, organised by feature (`src/features/<feature>/`). Served in production
by nginx, which also forwards `/api` to the Spring Boot app, so the browser only ever talks to one origin.
Read `.claude/skills/react-frontend/SKILL.md` for the conventions.

```bash
npm install                 # once; commit package-lock.json, then npm ci
npm run dev                 # http://localhost:5173, /api forwarded to http://localhost:8080 (API_UPSTREAM to change)
npm run typecheck
npm run build               # type-checks, then writes dist/
docker build -t <APP>-web . # the image: nginx on 8080, API_UPSTREAM=http://app:8080 by default
```

The sample feature (`src/features/items/`) is marked REPLACE ME: it shows the shape (API calls and query keys in
`api.ts`, a form that shows the server's problem details, a list with loading, error and empty states). Copy the
shape for your first real feature, then delete it.

End-to-end tests drive this UI through the e2e stack: set `web` in `e2e/stack/stack.config.ts`
(`{ image: '<APP>-web:e2e', port: 8080, upstreamEnv: 'API_UPSTREAM' }`); `npm run stack:build` builds this image too.
