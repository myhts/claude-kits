---
name: build-templates
description: Verified starting files for shipping a Spring Boot 4 app - Dockerfile (layered, non-root, container-aware JVM), .dockerignore, docker-compose for local dev, GitHub Actions CI, and Kubernetes manifests (deployment, service, config, PDB). Used by the implementer agent; learners can compare their own versions against them.
---

# Build and deploy templates

Files in this folder, all checked on 2026-10-18:

| File | What it is | How it was checked |
|---|---|---|
| `Dockerfile` | Multi-stage: JDK build → extracted Spring Boot layers on a JRE, non-root (uid 10001), heap from the container limit, G1, exit on OOM | Built a Spring Boot 4.1.1 app with it; ran it under compose: API 201/400, Flyway migrated, ran as uid 10001, JVM flags picked up, JSON logs, clean shutdown in 2 s |
| `.dockerignore` | Keeps `target/`, `.git/`, secrets and docs out of the build context | Same build |
| `compose.yaml` + `.env.example` | Postgres with a health check; the app behind a profile; ports on 127.0.0.1; secrets from `.env` | `docker compose config` and the run above (works on Compose v2.2+: no top-level `name:`) |
| `ci-github-actions.yml` | Build + all tests on PRs and main; least-privilege token; cancel superseded runs; test reports on failure; image build | `actionlint` 1.7.7: clean (and it catches injected errors). Not run on GitHub |
| `k8s/*.yaml` | Deployment (startup/liveness/readiness probes, preStop, grace period, memory request = limit, no CPU limit, non-root, read-only root fs), Service, ConfigMap, PodDisruptionBudget | `kubeconform -strict` against Kubernetes 1.33 schemas: 4/4 valid. **Never applied to a cluster** |

## Adapting them

- Replace `<APP>` / `<app>` with the Maven artifactId (the Dockerfile's jar name depends on it).
- Pin the base image tags you choose and bump them deliberately (`eclipse-temurin:21.0.8_9-*` here).
- The probes need `spring-boot-starter-actuator`; Spring Boot enables the liveness/readiness groups on Kubernetes,
  and `MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED=true` (in the ConfigMap) enables them anywhere.
- `readOnlyRootFilesystem: true` needs a writable `/tmp` (Tomcat's work dir): the `emptyDir` mount provides it.
- `preStop: sleep` is a native action (Kubernetes 1.30+). On older clusters use `exec: { command: ["sh", "-c", "sleep 10"] }`
  (the Temurin JRE image has a shell).
- Secrets never go in these files. Compose reads `.env` (gitignored); Kubernetes references a Secret created out of
  band (`kubectl create secret generic app-secrets --from-env-file=…`) or managed by External/Sealed Secrets.
- Size memory from measurements: heap ≈ 75% of the limit, and non-heap (metaspace, threads, buffers) needs
  ~200–300 MiB for a typical service. 768 MiB is a starting point, not an answer.

## Why each choice (so the learner can explain it)

- **Layers**: dependencies change rarely, the app often; ordering layers that way makes rebuilds and pushes small.
- **Non-root + read-only root fs + dropped capabilities**: a compromised app can do much less.
- **Liveness without dependencies**: if the DB is down, restarting every pod doesn't fix the DB and causes a storm.
  Readiness is where "can I serve?" belongs.
- **Grace period > preStop + shutdown phase**: otherwise Kubernetes kills the pod mid-request.
- **Memory request = limit, no CPU limit**: the JVM sizes itself from the limit; CPU limits cause throttling pauses.
