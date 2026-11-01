// The application in containers, on a private network, for one test run (or one `npm run stack:up`).
// Only one container is published (the web front end if there is one, else the app), on a random localhost port.
// Fresh, empty databases every time; nothing shared with any other stack on this machine.
import { resolve } from 'node:path';
import { GenericContainer, Network, Wait, type StartedNetwork, type StartedTestContainer } from 'testcontainers';
import { checkImages } from './images.ts';
import { STACK } from './stack.config.ts';

export type Stack = { baseUrl: string; stop: () => Promise<void> };

const LABELS = { purpose: 'e2e' };

export async function startStack(log: (line: string) => void = console.log): Promise<Stack> {
  checkImages();
  const started: StartedTestContainer[] = [];
  let network: StartedNetwork | undefined;
  const stop = async () => {
    for (const c of started.reverse()) await c.stop({ timeout: 15_000 }).catch(() => undefined);
    await network?.stop().catch(() => undefined);
  };
  try {
    const t0 = Date.now();
    const since = () => `${((Date.now() - t0) / 1000).toFixed(1)} s`;
    network = await new Network().start();
    const appEnv: Record<string, string> = {};
    const infra: Promise<StartedTestContainer>[] = [];

    if (STACK.postgres) {
      const pg = STACK.postgres;
      infra.push(new GenericContainer(pg.image)
        .withNetwork(network).withNetworkAliases('postgres').withLabels(LABELS)
        .withEnvironment({ POSTGRES_DB: pg.database, POSTGRES_USER: pg.user, POSTGRES_PASSWORD: pg.password })
        .withTmpFs({ '/var/lib/postgresql/data': 'rw' })          // throwaway data: RAM is faster than disk
        .withResourcesQuota({ memory: 0.25 })
        .withWaitStrategy(Wait.forLogMessage(/database system is ready to accept connections/, 2))
        .start());
      Object.assign(appEnv, {
        SPRING_DATASOURCE_URL: `jdbc:postgresql://postgres:5432/${pg.database}`,
        SPRING_DATASOURCE_USERNAME: pg.user,
        SPRING_DATASOURCE_PASSWORD: pg.password,
      });
    }
    if (STACK.kafka) {
      infra.push(new GenericContainer(STACK.kafka.image)
        .withNetwork(network).withNetworkAliases('kafka').withLabels(LABELS)
        .withEnvironment({
          KAFKA_NODE_ID: '1', KAFKA_PROCESS_ROLES: 'broker,controller',
          KAFKA_CONTROLLER_QUORUM_VOTERS: '1@kafka:29093', KAFKA_CONTROLLER_LISTENER_NAMES: 'CONTROLLER',
          KAFKA_LISTENERS: 'INTERNAL://:29092,CONTROLLER://:29093',
          KAFKA_ADVERTISED_LISTENERS: 'INTERNAL://kafka:29092',    // only containers on this network use it
          KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: 'INTERNAL:PLAINTEXT,CONTROLLER:PLAINTEXT',
          KAFKA_INTER_BROKER_LISTENER_NAME: 'INTERNAL',
          KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: '1', KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: '1',
          KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: '1', KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: '0',
          KAFKA_HEAP_OPTS: '-Xms128m -Xmx256m',
        })
        .withResourcesQuota({ memory: 0.5 })
        .withWaitStrategy(Wait.forLogMessage(/Kafka Server started/))
        .withStartupTimeout(120_000)
        .start());
      appEnv.SPRING_KAFKA_BOOTSTRAP_SERVERS = 'kafka:29092';
    }
    if (STACK.redis) {
      infra.push(new GenericContainer(STACK.redis.image)
        .withNetwork(network).withNetworkAliases('redis').withLabels(LABELS)
        .withResourcesQuota({ memory: 0.06 })
        .withWaitStrategy(Wait.forLogMessage(/Ready to accept connections/))
        .start());
      appEnv.SPRING_DATA_REDIS_HOST = 'redis';
    }
    if (STACK.llmFake) {
      infra.push(new GenericContainer(STACK.llmFake.image)
        .withNetwork(network).withNetworkAliases('llm-fake').withLabels(LABELS)
        .withCopyDirectoriesToContainer([{ source: resolve(import.meta.dirname, '..', STACK.llmFake.mappingsDir), target: '/home/wiremock/mappings' }])
        .withEnvironment({ JAVA_OPTS: '-Xmx128m' })
        .withCommand(['--disable-banner'])
        .withResourcesQuota({ memory: 0.25 })
        .withExposedPorts(8080)                                        // for the wait only; the app uses the network alias
        .withWaitStrategy(Wait.forHttp('/__admin/mappings', 8080).forStatusCode(200))
        .start());
      appEnv[STACK.llmFake.baseUrlEnv] = 'http://llm-fake:8080';
      appEnv.ANTHROPIC_API_KEY = 'e2e-fake-key';                      // never a real key in the e2e stack
    }
    started.push(...(await Promise.all(infra)));
    if (infra.length) log(`  infrastructure up (${since()})`);

    const app = await new GenericContainer(STACK.app.image)
      .withNetwork(network).withNetworkAliases('app').withLabels(LABELS)
      .withEnvironment({ ...appEnv, ...STACK.app.env, ...extraAppEnv() })
      .withResourcesQuota({ memory: STACK.app.memoryGb })
      .withExposedPorts(STACK.app.port)
      .withWaitStrategy(Wait.forHttp(STACK.app.readyPath, STACK.app.port).forStatusCode(200))
      .withStartupTimeout(180_000)
      .start();
    started.push(app);
    log(`  app ready (${since()})`);

    let baseUrl = `http://localhost:${app.getMappedPort(STACK.app.port)}`;
    if (STACK.web) {
      const web = await new GenericContainer(STACK.web.image)
        .withNetwork(network).withNetworkAliases('web').withLabels(LABELS)
        .withEnvironment({ [STACK.web.upstreamEnv]: `http://app:${STACK.app.port}` })
        .withResourcesQuota({ memory: 0.06 })
        .withExposedPorts(STACK.web.port)
        .withWaitStrategy(Wait.forHttp('/', STACK.web.port).forStatusCode(200))
        .start();
      started.push(web);
      baseUrl = `http://localhost:${web.getMappedPort(STACK.web.port)}`;
    }
    log(`  ready at ${baseUrl} (${since()})`);
    return { baseUrl, stop };
  } catch (e) {
    await stop();
    throw e;
  }
}

/** Extra app settings for one run, e.g. a lab switch: E2E_APP_ENV='APP_DRILL_PARTNER_FAILURE_RATE=1'. */
function extraAppEnv(): Record<string, string> {
  const raw = process.env.E2E_APP_ENV?.trim();
  if (!raw) return {};
  return Object.fromEntries(raw.split(/\s+/).map((kv) => {
    const i = kv.indexOf('=');
    if (i < 1) throw new Error(`E2E_APP_ENV: expected KEY=value, got "${kv}"`);
    return [kv.slice(0, i), kv.slice(i + 1)];
  }));
}
