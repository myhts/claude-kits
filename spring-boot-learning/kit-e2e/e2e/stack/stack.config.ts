// What the e2e stack runs. Edit this file to match the application: turn services on, set env, add a web front end.
// __APP__ is replaced with the Maven artifactId when the kit is installed.
type Postgres = { image: string; database: string; user: string; password: string };

export const STACK = {
  app: {
    image: '__APP__:e2e',                     // built by `npm run stack:build` from the project's Dockerfile
    port: 8080,
    readyPath: '/actuator/health',            // must answer 200 when the app can serve (needs spring-boot-starter-actuator)
    memoryGb: 0.64,                           // the JVM takes 75% of this as heap (see the Dockerfile)
    env: {} as Record<string, string>,        // extra settings for the app container
  },
  postgres: { image: 'postgres:16-alpine', database: 'app', user: 'app', password: 'app' } as Postgres | null,
  kafka: null as null | { image: string },    // e.g. { image: 'apache/kafka:4.1.0' } → app gets SPRING_KAFKA_BOOTSTRAP_SERVERS
  redis: null as null | { image: string },    // e.g. { image: 'redis:7.4-alpine' } → app gets SPRING_DATA_REDIS_HOST
  web: null as null | { image: string; port: number; upstreamEnv: string },
  // e.g. { image: '__APP__-web:e2e', port: 8080, upstreamEnv: 'API_UPSTREAM' }: nginx proxying /api to the app;
  // then the web container is what's published, and tests use the UI through it.
  llmFake: null as null | { image: string; mappingsDir: string; baseUrlEnv: string },
  // e.g. { image: 'wiremock/wiremock:3.13.2', mappingsDir: 'llm-fake/mappings', baseUrlEnv: 'APP_CLAUDE_BASE_URL' }:
  // a WireMock that answers POST /v1/messages from canned responses, so e2e runs never call the real model, cost
  // nothing and give the same answer every time. The app gets <baseUrlEnv>=http://llm-fake:8080 and a fake API key.
};
