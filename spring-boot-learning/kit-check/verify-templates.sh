#!/usr/bin/env bash
# Proves the build-templates skill on this Spring Boot app:
#   1. Dockerfile + .dockerignore + compose.yaml from the templates → build the image, run app + Postgres
#   2. call the API (201, 400), check the container user, JVM flags, JSON logs and a clean shutdown
#   3. validate the Kubernetes manifests (kubeconform, K8s 1.33 schemas) and the CI workflow (actionlint), offline
# Everything it starts or pulls is removed at the end, even on failure. Needs Docker; nothing leaves this machine
# except pulling public images. Ports (127.0.0.1 only): POSTGRES_PORT=15439, APP_PORT=18099 unless set.
#   ./verify-templates.sh
set -euo pipefail
cd "$(dirname "$0")"
T=../kit/.claude/skills/build-templates
P=kit-check-verify
export POSTGRES_DB=app POSTGRES_USER=app POSTGRES_PASSWORD=verify-only
export POSTGRES_PORT="${POSTGRES_PORT:-15439}" APP_PORT="${APP_PORT:-18099}"
KUBECONFORM=ghcr.io/yannh/kubeconform:v0.7.0 ACTIONLINT=rhysd/actionlint:1.7.7
pulled=() ci_dir=""
fail() { echo "FAIL: $*" >&2; exit 1; }

cleanup() {
  docker compose -p "$P" --profile app down -v >/dev/null 2>&1 || true
  docker rmi "${P}_app" "${P}-app" >/dev/null 2>&1 || true
  for img in "${pulled[@]+"${pulled[@]}"}"; do docker rmi "$img" >/dev/null 2>&1 || true; done
  rm -f Dockerfile .dockerignore compose.yaml
  [ -n "$ci_dir" ] && rm -rf "$ci_dir"
  return 0
}
trap cleanup EXIT

for port in "$POSTGRES_PORT" "$APP_PORT"; do
  ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 || fail "port $port is in use: set POSTGRES_PORT / APP_PORT"
done

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

echo "== 3. offline validation"
docker image inspect "$KUBECONFORM" >/dev/null 2>&1 || pulled+=("$KUBECONFORM")
docker run --rm -v "$PWD/$T/k8s":/k8s:ro "$KUBECONFORM" -strict -summary -kubernetes-version 1.33.0 /k8s
ci_dir=$(mktemp -d)
mkdir -p "$ci_dir/.github/workflows" && cp "$T/ci-github-actions.yml" "$ci_dir/.github/workflows/ci.yml"
docker image inspect "$ACTIONLINT" >/dev/null 2>&1 || pulled+=("$ACTIONLINT")
docker run --rm -v "$ci_dir":/repo:ro -w /repo "$ACTIONLINT" -no-color .github/workflows/ci.yml && echo "   actionlint: no problems"

echo "ALL TEMPLATE CHECKS PASSED"
