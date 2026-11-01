#!/usr/bin/env bash
# Proves the build-templates skill on this Spring Boot app:
#   1. Dockerfile + .dockerignore + compose.yaml from the templates → build the image, run app + Postgres
#   2. call the API (201, 400), check the container user, JVM flags, JSON logs and a clean shutdown
#   3. render every Kustomize overlay (kubectl kustomize) and validate the output (kubeconform, K8s 1.33 schemas,
#      strict), and lint the workflows (actionlint): CI and deploy from build-templates, pr-size and human-review
#      from the pipeline plugin. No cluster involved
#   4. only with --kind: a throwaway kind cluster gets the image (plus actuator, which the probes need) and
#      k8s/overlays/kind (the base + an in-cluster Postgres); the rollout must succeed and the API answer through
#      the Service
# Everything it starts, builds or pulls is removed at the end, even on failure (the kind cluster included). Needs
# Docker, and kind for --kind; nothing leaves this machine except pulling public images and kubeconform's schemas.
# Ports (127.0.0.1 only): POSTGRES_PORT=15439, APP_PORT=18099 unless set.
#   ./verify-templates.sh [--kind]
set -euo pipefail
cd "$(dirname "$0")"
T=../kit/.claude/skills/build-templates
GH=../kit-pipeline/skills/setup-project/templates/github
P=kit-check-verify
export POSTGRES_DB=app POSTGRES_USER=app POSTGRES_PASSWORD=verify-only
export POSTGRES_PORT="${POSTGRES_PORT:-15439}" APP_PORT="${APP_PORT:-18099}"
KUBECONFORM=ghcr.io/yannh/kubeconform:v0.7.0 ACTIONLINT=rhysd/actionlint:1.7.7
KUBECTL=registry.k8s.io/kubectl:v1.33.13       # the kubectl (and built-in kustomize v5.6) the deploy workflow pins
KIND_NODE=kindest/node:v1.33.12@sha256:3f5c8443c620245e4d355cfe09e96a91ead32ceaa569d3f1ca9edf0cb2fe2ff4
KIND_IMAGE=kit-check-verify-app:kind           # the name k8s/overlays/kind expects
pulled=() work="" kind_cluster="" kind_net=""
fail() { echo "FAIL: $*" >&2; exit 1; }

with_kind=0
for arg in "$@"; do
  case "$arg" in
    --kind) with_kind=1 ;;
    *) fail "unknown option '$arg' (the only option is --kind)" ;;
  esac
done

cleanup() {
  if [ -n "$kind_cluster" ]; then kind delete cluster --name "$kind_cluster" --kubeconfig "$work/kubeconfig" >/dev/null 2>&1 || true; fi
  if [ -n "$kind_net" ]; then docker network rm "$kind_net" >/dev/null 2>&1 || true; fi
  docker compose -p "$P" --profile app down -v >/dev/null 2>&1 || true
  docker rmi "${P}_app" "${P}-app" "$KIND_IMAGE" >/dev/null 2>&1 || true
  for img in "${pulled[@]+"${pulled[@]}"}"; do docker rmi "$img" >/dev/null 2>&1 || true; done
  rm -f Dockerfile .dockerignore compose.yaml
  if [ -n "$work" ]; then rm -rf "$work"; fi
  return 0
}
trap cleanup EXIT

for port in "$POSTGRES_PORT" "$APP_PORT"; do
  ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 || fail "port $port is in use: set POSTGRES_PORT / APP_PORT"
done
if [ "$with_kind" = 1 ]; then
  command -v kind >/dev/null || fail "--kind needs kind (https://kind.sigs.k8s.io)"
  ! kind get clusters 2>/dev/null | grep -qx "$P" || fail "a kind cluster named $P already exists; this script won't touch it"
fi

echo "== 1. image from the template Dockerfile"
sed 's/<APP>/kit-check/' "$T/Dockerfile" > Dockerfile
cp "$T/.dockerignore" .dockerignore
cp "$T/compose.yaml" compose.yaml
docker compose -p "$P" --profile app config -q
docker compose -p "$P" --profile app build -q app

echo "== 2. run it with the template compose file"
docker compose -p "$P" --profile app up -d >/dev/null 2>&1
for _ in $(seq 1 90); do curl -sf -o /dev/null "http://127.0.0.1:$APP_PORT/api/v1/authors" && break; sleep 1; done
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$APP_PORT/api/v1/authors" \
  -H 'Content-Type: application/json' -H 'X-Request-Id: verify-1' -d '{"name":"Ada","titles":["Notes"]}')
[ "$code" = 201 ] || fail "POST answered $code, expected 201"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$APP_PORT/api/v1/authors" \
  -H 'Content-Type: application/json' -d '{"name":""}')
[ "$code" = 400 ] || fail "invalid POST answered $code, expected 400"
app=$(docker compose -p "$P" ps -q app)
[ "$(docker exec "$app" id -u)" = 10001 ] || fail "container doesn't run as uid 10001"
logs=$(docker logs "$app" 2>&1)
grep -q 'Picked up JAVA_TOOL_OPTIONS: -XX:MaxRAMPercentage=75 -XX:+UseG1GC' <<<"$logs" || fail "JVM flags not applied"
grep -q '"requestId":"verify-1"' <<<"$logs" || fail "request id missing from the JSON logs"
start=$(date +%s); docker compose -p "$P" stop app >/dev/null 2>&1; took=$(( $(date +%s) - start ))
[ "$took" -lt 30 ] || fail "shutdown took ${took}s"
echo "   201 + 400 ok · uid 10001 · JVM flags · JSON logs with requestId · stopped in ${took}s"

echo "== 3. render and validate the Kubernetes overlays, lint the workflows (no cluster)"
for img in "$KUBECTL" "$KUBECONFORM" "$ACTIONLINT"; do
  docker image inspect "$img" >/dev/null 2>&1 || { pulled+=("$img"); docker pull -q "$img" >/dev/null; }
done
work=$(mktemp -d)
mkdir -p "$work/rendered" "$work/repo/.github/workflows"
overlays=""
for dir in "$T"/k8s/overlays/*/; do
  o=$(basename "$dir"); overlays+=" $o"
  docker run --rm -v "$PWD/$T/k8s":/k8s:ro "$KUBECTL" kustomize "/k8s/overlays/$o" > "$work/rendered/$o.yaml" \
    || fail "kubectl kustomize couldn't render overlays/$o"
done
docker run --rm -v "$work/rendered":/rendered:ro "$KUBECONFORM" -strict -summary -kubernetes-version 1.33.0 /rendered \
  || fail "kubeconform rejected a rendered overlay"
# What each environment must differ in. The image line also proves the overlays name the image as the base emits it.
expect() { grep -qF -- "$2" "$work/rendered/$1.yaml" || fail "overlays/$1 doesn't render '$2'"; }
for o in staging prod; do expect "$o" 'image: ghcr.io/OWNER/REPO:IMAGE_TAG'; expect "$o" 'maxUnavailable: 1'; done
expect staging 'namespace: app-staging'; expect staging 'replicas: 1'; expect staging 'host: app-staging.example.com'
expect prod 'namespace: app-prod'; expect prod 'replicas: 2'; expect prod 'host: app.example.com'
echo "   overlays${overlays} rendered and valid · staging 1 replica, prod 2 · hosts and namespaces per environment"
cp "$T/ci-github-actions.yml" "$work/repo/.github/workflows/ci.yml"
cp "$T/deploy-github-actions.yml" "$work/repo/.github/workflows/deploy.yml"
cp "$GH/pr-size.yml" "$GH/human-review.yml" "$work/repo/.github/workflows/"
docker run --rm -v "$work/repo":/repo:ro -w /repo "$ACTIONLINT" -no-color \
  .github/workflows/ci.yml .github/workflows/deploy.yml .github/workflows/pr-size.yml .github/workflows/human-review.yml \
  || fail "actionlint found problems in the workflows"
echo "   actionlint: no problems in ci, deploy, pr-size, human-review"

if [ "$with_kind" = 1 ]; then
  echo "== 4. apply overlays/kind to a throwaway kind cluster"
  # kit-check has no actuator, and the base's probes need it (as any app using these templates does): build the
  # same app plus spring-boot-starter-actuator, from a copy, with the template Dockerfile from step 1.
  mkdir "$work/app"
  cp -R .mvn mvnw pom.xml src Dockerfile .dockerignore "$work/app/"
  perl -0pi -e 's|<dependencies>|<dependencies>\n\t\t<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency>|' "$work/app/pom.xml"
  DOCKER_BUILDKIT=1 docker build -q -t "$KIND_IMAGE" "$work/app" >/dev/null || fail "couldn't build the image with actuator"

  docker network inspect kind >/dev/null 2>&1 || kind_net=kind       # kind creates it; removed only if we created it
  docker image inspect "$KIND_NODE" >/dev/null 2>&1 || pulled+=("kindest/node@${KIND_NODE##*@}")
  kind_cluster=$P                                                    # set first: a half-created cluster is deleted too
  # --kubeconfig: the cluster's credentials go to the temp folder, never into ~/.kube/config
  kind create cluster --name "$P" --image "$KIND_NODE" --kubeconfig "$work/kubeconfig" --wait 120s >/dev/null 2>&1 \
    || fail "kind couldn't create the cluster"
  # What `kind load docker-image` does, by hand: older kind releases can't detect containerd 2's snapshotter.
  for img in "$KIND_IMAGE" postgres:16-alpine; do
    docker save "$img" | docker exec -i "$P-control-plane" ctr --namespace=k8s.io images import --all-platforms - >/dev/null \
      || fail "couldn't load $img into the kind node"
  done
  kind get kubeconfig --internal --name "$P" > "$work/kubeconfig-internal"
  # The pinned kubectl, in a container on kind's network, so the host's kubectl version doesn't matter.
  k() { docker run --rm -i --network kind -v "$work/kubeconfig-internal":/kubeconfig:ro "$KUBECTL" --kubeconfig /kubeconfig "$@"; }
  k apply -f - < "$work/rendered/kind.yaml" >/dev/null
  if ! k -n app-kind rollout status deployment/postgres --timeout=120s >/dev/null \
     || ! k -n app-kind rollout status deployment/app --timeout=300s >/dev/null; then
    k -n app-kind get pods -o wide || true
    k -n app-kind describe deployment app | tail -20 || true
    k -n app-kind logs deployment/app --tail=40 || true
    fail "the app didn't roll out on kind"
  fi
  ready=$(k -n app-kind get deployment app -o jsonpath='{.status.readyReplicas}/{.spec.replicas}')
  uid=$(k -n app-kind exec deployment/app -- id -u)
  [ "$uid" = 10001 ] || fail "the pod runs as uid $uid, expected 10001"
  # A broken release, handled like deploy-github-actions.yml does: the new pod can't start (no such image), the
  # rollout times out, rollout undo restores the release. maxUnavailable: 0 must keep both old pods serving meanwhile.
  k -n app-kind set image deployment/app app=kit-check-verify-app:missing >/dev/null
  ! k -n app-kind rollout status deployment/app --timeout=20s >/dev/null 2>&1 || fail "a release that can't start rolled out"
  during=$(k -n app-kind get deployment app -o jsonpath='{.status.readyReplicas}')
  [ "$during" = 2 ] || fail "$during pod(s) ready during a failing rollout; maxUnavailable: 0 should keep 2"
  k -n app-kind rollout undo deployment/app >/dev/null
  k -n app-kind rollout status deployment/app --timeout=120s >/dev/null || fail "rollout undo didn't restore the release"
  # Through the Service, from another pod (busybox wget in the Postgres image): the app answers and reads the DB.
  body=$(k -n app-kind exec deployment/postgres -- wget -qO- http://app/api/v1/authors) \
    || fail "GET http://app/api/v1/authors through the Service failed"
  [[ "$body" == \[* ]] || fail "unexpected answer through the Service: $body"
  node=$(k get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')
  echo "   kind, Kubernetes $node: rollout complete, $ready ready · uid 10001"
  echo "   broken release: 2/2 old pods kept serving, rollout undo restored it · GET /api/v1/authors through the Service ok"
fi

echo "ALL TEMPLATE CHECKS PASSED"
