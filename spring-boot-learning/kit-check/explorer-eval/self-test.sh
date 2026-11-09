#!/usr/bin/env bash
# Proves the evaluation's own scripts on a tiny invented repo, offline and with no model calls:
#   answers.mjs finds the rpcs, routes, calls and store (and skips the health service);
#   score.mjs passes a perfect survey and one spelled differently, fails a flawed one for the right reasons, and
#   ranks the passing arms by price; usage.mjs reads a headless run's totals and adds up a session log once per message;
#   sheets.mjs pulls the readers' own fact sheets out of a run's log.
set -euo pipefail
H="$(cd "$(dirname "$0")" && pwd)"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
R="$T/repo"; mkdir -p "$R/protos/grpc/health/v1" "$R/src/web" "$R/src/shopservice" "$R/kubernetes-manifests"

cat > "$R/protos/demo.proto" <<'EOF'
syntax = "proto3";
package shop;

service ShopService {
    rpc Buy(BuyRequest) returns (BuyResponse) {}
    rpc List(Empty) returns (ListResponse) {}
}
service PayService {
    rpc Charge(ChargeRequest) returns (ChargeResponse) {}
}
EOF
cat > "$R/protos/grpc/health/v1/health.proto" <<'EOF'
service Health {
  rpc Check(HealthCheckRequest) returns (HealthCheckResponse);
}
EOF
cat > "$R/src/web/main.go" <<'EOF'
package main
func main() {
	r.HandleFunc(baseUrl+"/", h.home).Methods(http.MethodGet, http.MethodHead)
	r.HandleFunc(baseUrl+"/buy", h.buy).Methods(http.MethodPost)
	r.HandleFunc(baseUrl+"/_healthz", func(w http.ResponseWriter, _ *http.Request) {})
}
EOF
printf 'const server = grpc();\nserver.add("Buy");\nserver.add("List");\n\nconst redis = connect(process.env.REDIS_ADDR);\n' > "$R/src/shopservice/server.js"
deployment() { printf 'apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: %s\n  labels:\n    app: %s\nspec:\n  template:\n    spec:\n      containers:\n        - name: server\n          env:\n' "$1" "$1"; }
env_addr() { printf '            - name: %s\n              value: "%s"\n' "$1" "$2"; }
{ deployment web; env_addr SHOP_SERVICE_ADDR shopservice:7000; env_addr PAY_SERVICE_ADDR payservice:50051
  printf -- '---\napiVersion: v1\nkind: Service\nmetadata:\n  name: web\n'; } > "$R/kubernetes-manifests/web.yaml"
{ deployment shopservice; env_addr REDIS_ADDR redis-cart:6379; printf -- '---\n'; deployment redis-cart; } > "$R/kubernetes-manifests/shopservice.yaml"
deployment payservice > "$R/kubernetes-manifests/payservice.yaml"

echo "== answers.mjs"
node "$H/answers.mjs" "$R" > "$T/answers.json" 2> "$T/answers.err"
cat "$T/answers.err"
grep -q "4 workloads; entry points 5 required (+1 optional); calls 2 (+0); stores 1 (+0)" "$T/answers.err" || fail "unexpected answer key"
grep -q '"Health' "$T/answers.json" && fail "the health service should be skipped"

cat > "$T/opus.json" <<'EOF'
{"services": [
  {"name": "web", "entryPoints": [{"name": "GET /", "ref": "src/web/main.go:3"}, {"name": "POST /buy", "ref": "src/web/main.go:4"}],
   "calls": [{"to": "shopservice", "ref": "src/web/main.go:3"}, {"to": "payservice", "ref": "src/web/main.go:4"},
             {"to": "OpenTelemetry collector (COLLECTOR_SERVICE_ADDR)", "ref": "src/web/main.go:1"}]},
  {"name": "shopservice", "entryPoints": [{"name": "ShopService.Buy", "ref": "src/shopservice/server.js:2"}, {"name": "ShopService.List", "ref": "src/shopservice/server.js:3"}],
   "stores": [{"name": "Redis", "ref": "src/shopservice/server.js:5"}]},
  {"name": "payservice", "entryPoints": [{"name": "PayService.Charge (a fake: logs and returns an id)", "ref": "protos/demo.proto:9"}]}
]}
EOF
cat > "$T/sonnet.json" <<'EOF'
{"services": [
  {"name": "Web", "entryPoints": [{"name": "GET /", "ref": "src/web/main.go:3"}, {"name": "/buy (POST)", "ref": "src/web/main.go:4"}],
   "calls": [{"to": "ShopService", "ref": "src/web/main.go:3"}, {"to": "pay", "ref": "src/web/main.go:4"}]},
  {"name": "ShopService", "entryPoints": [{"name": "shop.ShopService/Buy", "ref": "src/shopservice/server.js:2"}, {"name": "List", "ref": "src/shopservice/server.js:3"}],
   "calls": [{"to": "redis-cart", "ref": "src/shopservice/server.js:5"}]},
  {"name": "payservice", "entryPoints": [{"name": "Charge", "ref": "protos/demo.proto:9-10"}]}
]}
EOF
cat > "$T/haiku.json" <<'EOF'
{"services": [
  {"name": "web", "entryPoints": [{"name": "GET /", "ref": "src/web/main.go:999"}, {"name": "POST /buy", "ref": "src/web/main.go:4"}],
   "calls": [{"to": "shopservice", "ref": "src/web/main.go:3"}]},
  {"name": "shopservice", "entryPoints": [{"name": "ShopService.Buy", "ref": "src/shopservice/server.js:2"}, {"name": "ShopService.List", "ref": "src/shopservice/server.js:3"}],
   "calls": [{"to": "payservice", "ref": "src/shopservice/server.js:1"}], "stores": [{"name": "redis", "ref": "src/shopservice/server.js:5"}],
   "unsure": ["where List reads from"]}
]}
EOF

echo "== score.mjs"
node "$H/score.mjs" "$T/answers.json" "$R" opus="$T/opus.json" sonnet="$T/sonnet.json" haiku="$T/haiku.json"
node "$H/score.mjs" "$T/answers.json" "$R" opus="$T/opus.json" sonnet="$T/sonnet.json" haiku="$T/haiku.json" --json > "$T/score.json"
node -e '
  const { results, choice } = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const by = Object.fromEntries(results.map((r) => [r.arm, r]));
  const check = (ok, what) => { if (!ok) { console.error("FAIL: " + what); process.exit(1); } };
  check(by.opus.verdict === "baseline" && by.opus.entryPoints.found === 5 && by.opus.calls.found === 2 && by.opus.stores.found === 1, "opus scores 5/5, 2/2, 1/1");
  check(by.sonnet.verdict === "passes" && by.sonnet.entryPoints.found === 5 && by.sonnet.stores.found === 1, "sonnet passes despite other spellings");
  check(by.haiku.verdict === "fails", "haiku fails");
  for (const why of ["misses calls opus found: web>pay", "entry points 4/5", "1 broken file:line"])
    check(by.haiku.reasons.some((r) => r.includes(why)), "haiku fails because: " + why);
  check(by.haiku.calls.toApp.includes("shop>pay") && by.haiku.unsure === 1, "haiku invented call listed, unsure counted");
  check(by.opus.calls.outside.join() === "web>opentelemetrycollector" && !by.opus.calls.toApp.length, "a call outside the app is listed apart, its note ignored");
  check(choice === "sonnet", "chooses sonnet");
' "$T/score.json"
node "$H/score.mjs" "$T/answers.json" "$R" opus="$T/opus.json" haiku="$T/opus.json" --json | node -e '
  let s = ""; process.stdin.on("data", (d) => s += d).on("end", () => { if (JSON.parse(s).choice !== "haiku") { console.error("FAIL: a passing haiku should be chosen"); process.exit(1); } });'

echo "== usage.mjs"
cat > "$T/run.jsonl" <<'EOF'
{"type":"assistant","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":1,"output_tokens":3}}}
{"type":"result","modelUsage":{"claude-opus-5-5":{"inputTokens":10,"outputTokens":100,"cacheReadInputTokens":1000,"cacheCreationInputTokens":200,"costUSD":0.5},"claude-sonnet-5-5":{"inputTokens":5,"outputTokens":40,"cacheReadInputTokens":300,"cacheCreationInputTokens":50,"costUSD":0.1}}}
EOF
node "$H/usage.mjs" "$T/run.jsonl" --json | node -e '
  let s = ""; process.stdin.on("data", (d) => s += d).on("end", () => { const u = JSON.parse(s);
    if (!u.exact || Math.abs(u.listPriceUsd - 0.6) > 1e-9 || u.models.length !== 2) { console.error("FAIL: headless totals"); process.exit(1); } });'
mkdir -p "$T/session/subagents"
cat > "$T/session.jsonl" <<'EOF'
{"type":"assistant","message":{"id":"a","model":"claude-opus-5-5","usage":{"input_tokens":2,"output_tokens":5}}}
{"type":"assistant","message":{"id":"a","model":"claude-opus-5-5","usage":{"input_tokens":2,"output_tokens":50}}}
{"type":"assistant","message":{"id":"b","model":"claude-opus-5-5","usage":{"input_tokens":3,"output_tokens":7}}}
{"type":"assistant","message":{"id":"s","model":"<synthetic>","usage":{"input_tokens":0,"output_tokens":0}}}
EOF
echo '{"type":"assistant","message":{"id":"c","model":"claude-sonnet-5-5","usage":{"input_tokens":4,"output_tokens":20}}}' > "$T/session/subagents/agent-x.jsonl"
node "$H/usage.mjs" "$T/session.jsonl" --json | node -e '
  let s = ""; process.stdin.on("data", (d) => s += d).on("end", () => { const u = JSON.parse(s), m = Object.fromEntries(u.models.map((x) => [x.model, x]));
    if (u.exact || m["claude-opus-5-5"].output !== 57 || m["claude-opus-5-5"].input !== 5 || m["claude-sonnet-5-5"].output !== 20 || m["<synthetic>"])
      { console.error("FAIL: session log sums " + JSON.stringify(u.models)); process.exit(1); } });'

echo "== sheets.mjs"
node -e '
  const n = (id, summary) => JSON.stringify({ type: "system", subtype: "task_notification", task_id: id, summary });
  console.log([n("t1", "Here is the fact sheet:\n\n```json\n{\"name\": \"web\", \"calls\": []}\n```"),
    n("t2", "{\"services\": [{\"name\": \"a\"}, {\"name\": \"b\"}]}"), n("t3", "I could not finish.")].join("\n"));' > "$T/readers.jsonl"
node "$H/sheets.mjs" "$T/readers.jsonl" > "$T/raw.json" 2> "$T/sheets.err"
grep -q "3 sheets; unreadable: t3" "$T/sheets.err" || fail "sheets.mjs: $(cat "$T/sheets.err")"
node -e 'const s = require(process.argv[1]).services.map((x) => x.name).join(); if (s !== "web,a,b") { console.error("FAIL: sheets " + s); process.exit(1); }' "$T/raw.json"
echo "OK: explorer-eval verified"
