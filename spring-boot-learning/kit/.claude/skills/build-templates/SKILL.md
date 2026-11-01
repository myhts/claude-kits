---
name: build-templates
description: Verified starting files for shipping a Spring Boot 4 app - Dockerfile (layered, non-root, container-aware JVM), .dockerignore, docker-compose for local dev, GitHub Actions CI, a GitHub Actions deploy workflow (GHCR → staging → approved production, rollback on a failed rollout), and Kubernetes manifests as a Kustomize base (deployment, service, config, PDB, ingress) with staging and prod overlays. Used by the implementer agent; learners can compare their own versions against them.
---

# Build and deploy templates

Files in this folder, checked on 2026-10-18 (Kubernetes and deploy files on 2026-11-01) by
`kit-check/verify-templates.sh`:

| File | What it is | How it was checked |
|---|---|---|
| `Dockerfile` | Multi-stage: JDK build → extracted Spring Boot layers on a JRE, non-root (uid 10001), heap from the container limit, G1, exit on OOM | Built a Spring Boot 4.1.1 app with it; ran it under compose: API 201/400, Flyway migrated, ran as uid 10001, JVM flags picked up, JSON logs, clean shutdown in 2 s |
| `.dockerignore` | Keeps `target/`, `.git/`, secrets and docs out of the build context | Same build |
| `compose.yaml` + `.env.example` | Postgres with a health check; the app behind a profile; ports on 127.0.0.1; secrets from `.env` | `docker compose config` and the run above (works on Compose v2.2+: no top-level `name:`) |
| `ci-github-actions.yml` | Build + all tests on PRs and main; least-privilege token; cancel superseded runs; test reports on failure; image build | `actionlint` 1.7.7: clean (and it catches injected errors). Not run on GitHub |
| `deploy-github-actions.yml` | On push to `main`: image to GHCR tagged with the full commit SHA → `staging` (apply the overlay, `rollout status` with a timeout, `rollout undo` on failure, smoke e2e against the staging host only) → `production` after the Environment's required reviewer approves, read-only smoke, rollback if it fails. Per-environment concurrency | `actionlint` 1.7.7: clean; the image guard (rendered image = pushed image) tried by hand. Not run on GitHub |
| `k8s/base/` | Deployment (startup/liveness/readiness probes, preStop, grace period, `maxUnavailable: 0`, memory request = limit, no CPU limit, non-root, read-only root fs), Service, ConfigMap, PodDisruptionBudget (`maxUnavailable: 1`), Ingress (TLS off, cert-manager commented), `kustomization.yaml` (`images:`) | Rendered through each overlay; with `--kind`, applied to a throwaway kind cluster (Kubernetes 1.33.12): rollout 2/2, uid 10001, a release that can't start kept 2/2 old pods serving and `rollout undo` restored it, the API answered through the Service |
| `k8s/overlays/staging`, `k8s/overlays/prod` | Namespace (`app-staging`, `app-prod`), replicas (1, 2), Ingress host, image tag `IMAGE_TAG` that CI replaces with the SHA | `kubectl kustomize` (kubectl 1.33.13) then `kubeconform -strict` against Kubernetes 1.33 schemas: valid. **Never applied to a real cluster** |
| `k8s/overlays/kind` | Test only: the base + an in-cluster Postgres and a generated Secret, with the locally built image | Applied by `verify-templates.sh --kind` |

## Adapting them

- Replace `<APP>` / `<app>` with the Maven artifactId (the Dockerfile's jar name depends on it).
- Pin the base image tags you choose and bump them deliberately (`eclipse-temurin:21.0.8_9-*` here).
- The probes need `spring-boot-starter-actuator`; Spring Boot enables the liveness/readiness groups on Kubernetes,
  and `MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED=true` (in the ConfigMap) enables them anywhere.
- `readOnlyRootFilesystem: true` needs a writable `/tmp` (Tomcat's work dir): the `emptyDir` mount provides it.
- `preStop: sleep` is a native action (Kubernetes 1.30+). On older clusters use `exec: { command: ["sh", "-c", "sleep 10"] }`
  (the Temurin JRE image has a shell).
- Secrets never go in these files. Compose reads `.env` (gitignored); Kubernetes references the Secret
  `app-secrets`, which the deploy workflow writes from the GitHub Environment secret `APP_ENV` (KEY=value lines), or
  which is created out of band (`kubectl create secret generic app-secrets --from-env-file=…`) or managed by
  External/Sealed Secrets.
- Kubernetes: replace `OWNER/REPO` (the GHCR image, lowercase) in `k8s/base/kustomization.yaml` and both overlays,
  the hosts in the overlays and in the deploy workflow's `STAGING_URL`/`PROD_URL`, and `ingressClassName` with the
  class your cluster has (`kubectl get ingressclass`). Check with `kubectl kustomize k8s/overlays/staging`.
- The deploy workflow needs, per GitHub Environment (`staging`, `production`), the secret `KUBE_CONFIG` (a base64
  kubeconfig limited to that namespace), namespaces created by a cluster admin, a cluster that can pull from GHCR,
  and on `production` a required reviewer. Its smoke step runs the e2e smoke command from the placeholders at the top.
- Size memory from measurements: heap ≈ 75% of the limit, and non-heap (metaspace, threads, buffers) needs
  ~200–300 MiB for a typical service. 768 MiB is a starting point, not an answer.

## Why each choice (so the learner can explain it)

- **Layers**: dependencies change rarely, the app often; ordering layers that way makes rebuilds and pushes small.
- **Non-root + read-only root fs + dropped capabilities**: a compromised app can do much less.
- **Liveness without dependencies**: if the DB is down, restarting every pod doesn't fix the DB and causes a storm.
  Readiness is where "can I serve?" belongs.
- **Grace period > preStop + shutdown phase**: otherwise Kubernetes kills the pod mid-request.
- **Memory request = limit, no CPU limit**: the JVM sizes itself from the limit; CPU limits cause throttling pauses.
- **`maxUnavailable: 0` + expand/contract migrations**: old pods serve until new ones are ready, so a broken release
  never takes traffic and `rollout undo` is instant. Flyway runs at startup, so old and new code share one schema;
  only additive (expand/contract) migrations keep that safe.
- **PDB `maxUnavailable: 1`, not `minAvailable: 1`**: on staging's single replica `minAvailable: 1` would block every
  node drain; `maxUnavailable: 1` lets the drain through there and still keeps one of prod's two pods serving.
- **Image tag = commit SHA, written in by CI**: each deploy names one exact build, git never holds a "current
  version" to keep in sync, and rolling back means redeploying an older SHA.
- **Approval on the GitHub Environment, not in the workflow**: production's secrets reach the job only after a
  reviewer approves, so the workflow file alone can't deploy to production.
