---
name: deploy
description: "Set up continuous deployment to Kubernetes through GitHub Actions: Kustomize base and overlays, the deploy workflow, environments and secrets through a wizard, then explain releases and rollback. Run once per project, and again when the deploy target changes."
disable-model-invocation: true
---

Set the project up so that every merge to `main` ships to staging, and production follows the human's approval. After
this, CI does every deploy. Claude writes files and walks the human through the steps only they can do; it never applies
anything to a cluster or touches secrets.

## 1. Check the starting point

Read `docs/agents/stack.md`: the pack, its templates path, the e2e command, and the **Deploy** section.

- **No cluster chosen yet:** stop here and suggest a research ticket, "Pick the Kubernetes host", on the current
  Wayfinder map, or a short `/grill-with-docs` if there's no map. The criteria:
  - monthly cost, especially the control plane
  - ingress and TLS
  - how GitHub Actions authenticates (OIDC or a kubeconfig secret)
  - where Postgres lives (in the cluster, or a managed service)
  - environment approvals: free on public repos; private repos need a paid plan

  Record the decision as an ADR if it passes the three-part bar, and in the stack card either way.
- **The project already has a `Dockerfile`, CI and `k8s/`:** you are updating, not starting; diff against the pack's
  templates and propose only the gaps.

Done when the target (host, registry, namespaces, hosts) is written in the stack card.

## 2. Write the files

From the pack's build templates (the stack card names the path), adapted to this project. Show the list first, then
write:

- **`Dockerfile`** and **`.dockerignore`**, if missing.
- **`k8s/base/`**: Deployment, Service, ConfigMap, PodDisruptionBudget, Ingress and `kustomization.yaml`.
- **`k8s/overlays/staging/`** and **`k8s/overlays/prod/`**: namespace, replicas, host, and the image tag placeholder
  `IMAGE_TAG` that CI replaces with the commit SHA.
- **`.github/workflows/deploy.yml`** from the pack's `deploy-github-actions.yml`:
  1. build and push the image to GHCR, tagged with the SHA
  2. apply the staging overlay, wait for the rollout (undo it on failure), run the smoke e2e against the staging host
     only
  3. production after the environment's approval: the same rollout, then only the smoke tests not tagged `@writes`
     (tests that create data never run against production), with an undo if they fail

  Fill the placeholders: the `env:` block at the top of the workflow (URLs, smoke command), and `OWNER/REPO` in
  `k8s/base/kustomization.yaml` and both overlays. The workflow refuses to deploy while the placeholder is there.

**No pack**, or a pack without deploy templates: write the same files to this shape, and say in the PR that they are
new rather than verified templates. The `spring` pack's `build-templates/` (in the toolkit repo, under
`spring-boot-learning/kit/.claude/skills/`) is a worked, tested example. Its deploy workflow is stack-neutral apart
from the image build; the Spring-specific parts of the rest are the base image, port, probe paths, config keys and
memory settings.

- **Dockerfile:** multi-stage; base images pinned to a version; the final image holds only the runtime and the app, and
  runs as a non-root user; a `.dockerignore` keeps `.git`, `.env*` and build output out.
- **Deployment:** rolling update with `maxSurge: 1` and `maxUnavailable: 0`. Three probes: startup (slow start),
  liveness (the process only, never a dependency) and readiness (can it serve now). A `preStop` sleep plus graceful
  shutdown that fits inside `terminationGracePeriodSeconds`. Non-root, read-only root filesystem with an `emptyDir` at
  `/tmp`, all capabilities dropped, no service account token. CPU and memory requests, a memory limit, no CPU limit.
  Settings from a ConfigMap, secrets from the `app-secrets` Secret, by name only.
- **Service, PodDisruptionBudget** (`maxUnavailable: 1`), **Ingress**, and a `kustomization.yaml` whose `images:` names
  the registry. The overlays set namespace, replicas, host and the `IMAGE_TAG`.
- **`deploy.yml`:** the three jobs above, one deploy at a time (a `concurrency` group), least-privilege `permissions`
  (`contents: read`, `packages: write` only on the build job), and actions pinned to a version.

Render each overlay locally (`kubectl kustomize k8s/overlays/staging`) to check it builds. Then hand the changed files to
`deploy-reviewer`, fix what it finds, and open the change as a normal PR through `/implement`'s steps 6–8.

Done when the overlays render, `deploy-reviewer` has no must-fix left, and the PR is open.

## 3. The steps only the human can do

Call the Skill tool with `wizard` to generate an interactive script for these steps. The human runs it in their own
terminal, so secret values never pass through this session:

1. **Namespaces:** a cluster admin creates `app-staging` and `app-prod`.
2. **Cluster access for CI:** create a deploy identity that can manage only its own namespace, then store its
   kubeconfig (base64) as the `KUBE_CONFIG` secret on the GitHub Environments `staging` and `production`.
3. **Image pulls:** make the GHCR package public, or give both namespaces an `imagePullSecret`.
4. **Approval:** on the `production` environment, add the human as a required reviewer.
5. **App secrets:** set an `APP_ENV` environment secret holding `KEY=value` lines (database password, API keys). The
   workflow writes it into the `app-secrets` Secret on each deploy; without it, an `app-secrets` created by hand stays
   as it is.
6. **DNS and TLS:** point the staging and production hosts at the ingress, and enable TLS (cert-manager or the host's
   own certificates).

Afterwards, verify without reading any secret value: the environments exist, and the secret names are present
(`gh api repos/{owner}/{repo}/environments`).

## 4. Explain how releases work

Tell the human, briefly:

- **A release:** merge a PR. CI builds, deploys to staging, runs the smoke test, then waits for their approval before
  production.
- **Database changes:** use expand → migrate → contract, so the previous version still runs against the new schema.
  That is what makes a rollback safe. (Spring: Flyway runs when the new version starts; `maxUnavailable: 0` keeps the
  old pods serving until the new ones are ready.)
- **Rollback:** CI runs `kubectl rollout undo` automatically when a rollout or the production smoke test fails. By
  hand, either run `kubectl rollout undo`, or open the deploy run of the last good commit in GitHub Actions and choose
  "Re-run all jobs" (`gh run rerun <run-id>`). A re-run uses that run's commit, so it redeploys exactly that version.
  GitHub allows re-runs for 30 days.
- **Watching it:** the probes, the JSON logs with request ids, and the one alert on the main symptom.

## 5. Stop

The first real deploy happens when the next PR merges. Claude doesn't run `kubectl apply`, push images or change
environments; CI and the human do. Next: `/pipeline:next`, in a fresh session (`/clear` first).
