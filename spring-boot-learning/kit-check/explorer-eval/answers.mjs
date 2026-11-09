#!/usr/bin/env node
// Builds the answer key for the explorer's survey from the repository itself, so every run is scored the same way:
//   entry points · each rpc in the .proto files under protos/ (Service.Method), and each route a Go gorilla/mux router
//                  registers (METHOD /path)
//   calls        · each Kubernetes Deployment's env vars ending in _ADDR that name another workload (from → to)
//   stores       · the same, when the target is a database or cache (Redis, Postgres, MySQL, MongoDB, Memcached)
//   node answers.mjs <repo> [--protos protos] [--manifests kubernetes-manifests] [--optional <regex>] > answers.json
// Health checks, and anything matching --optional, may be reported but aren't required. Read the result before any
// run: it is the answer key, and a person should agree with it.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join, relative } from "node:path";
import { execFileSync } from "node:child_process";

const args = process.argv.slice(2);
const flag = (name, def) => { const i = args.indexOf(name); if (i < 0) return def; const v = args[i + 1]; args.splice(i, 2); return v; };
const protosDir = flag("--protos", "protos"), manifestsDir = flag("--manifests", "kubernetes-manifests");
const optionalArg = flag("--optional", "");
const repo = args[0];
if (!repo || !existsSync(repo)) { console.error("usage: node answers.mjs <repo> [--protos dir] [--manifests dir] [--optional regex]"); process.exit(2); }

const HEALTH = /health|robots\.txt/i;
const optional = (...names) => names.some((n) => HEALTH.test(n) || (optionalArg && new RegExp(optionalArg, "i").test(n)));
const STORE = /redis|postgres|mysql|mongo|memcache/i;
const SKIP = new Set([".git", "node_modules", "vendor", "target", "build", "dist", ".venv", "obj", "bin"]);

const files = (dir, test, out = []) => {
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir)) {
    if (SKIP.has(name)) continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) files(p, test, out); else if (test(p)) out.push(p);
  }
  return out;
};
const lineOf = (text, index) => text.slice(0, index).split("\n").length;
const where = (file, text, index) => `${relative(repo, file)}:${lineOf(text, index)}`;

// Workloads first: an rpc's owner is the Deployment named after its service (CartService → cartservice).
const deployments = [], calls = [], stores = [];
for (const file of files(join(repo, manifestsDir), (p) => /\.ya?ml$/.test(p))) {
  const text = readFileSync(file, "utf8");
  let offset = 0;
  for (const doc of text.split(/^---\s*$/m)) {
    const start = offset; offset += doc.length + 4;
    if (!/^kind:\s*Deployment\s*$/m.test(doc)) continue;
    const name = doc.match(/^metadata:\s*\n(?:\s+.*\n)*?\s{2}name:\s*"?([\w.-]+)/m)?.[1];
    if (!name) continue;
    deployments.push(name);
    for (const m of doc.matchAll(/-\s*name:\s*"?(\w+_ADDR)"?\s*\n\s*value:\s*"?([^"\s]+)"?/g)) {
      const to = m[2].split(":")[0], list = STORE.test(to) ? stores : calls;
      if (list.some((x) => x.from === name && x.to === to)) continue; // the same address given to two containers
      list.push({ from: name, to, env: m[1], where: where(file, text, start + m.index), optional: optional(name, to) });
    }
  }
}

const entryPoints = [];
const owner = (service) => deployments.find((d) => d.toLowerCase() === service.toLowerCase()) ?? service.toLowerCase();
for (const file of files(join(repo, protosDir), (p) => p.endsWith(".proto") && !/[/\\]grpc[/\\]health[/\\]/.test(p))) {
  const text = readFileSync(file, "utf8");
  for (const s of text.matchAll(/^service\s+(\w+)\s*\{([\s\S]*?)^\}/gm)) {
    for (const r of s[2].matchAll(/rpc\s+(\w+)\s*\(/g)) {
      const name = `${s[1]}.${r[1]}`;
      entryPoints.push({ name, service: owner(s[1]), where: where(file, text, s.index + s[0].indexOf(r[0])), optional: optional(name, s[1]) });
    }
  }
}

const METHOD = { MethodGet: "GET", MethodPost: "POST", MethodPut: "PUT", MethodDelete: "DELETE", MethodPatch: "PATCH" };
for (const file of files(repo, (p) => p.endsWith(".go") && !p.endsWith("_test.go"))) {
  const text = readFileSync(file, "utf8");
  if (!text.includes("HandleFunc(")) continue;
  const service = relative(repo, file).split(/[/\\]/).find((part, i, all) => i > 0 && all[i - 1] === "src") ?? basename(repo);
  for (const m of text.matchAll(/HandleFunc\(\s*(?:\w+\s*\+\s*)?"([^"]+)"[^\n]*/g)) {
    const listed = [...(m[0].match(/\.Methods\(([^)]*)\)/)?.[1] ?? "").matchAll(/http\.(\w+)/g)].map((x) => METHOD[x[1]]).filter(Boolean);
    for (const method of listed.length ? listed : ["ANY"]) {
      const name = `${method} ${m[1]}`;
      entryPoints.push({ name, service, where: where(file, text, m.index), optional: optional(name, service) });
    }
  }
}

let commit = null;
try { commit = execFileSync("git", ["-C", repo, "rev-parse", "HEAD"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); } catch {}
const required = (list) => list.filter((x) => !x.optional).length;
console.log(JSON.stringify({ repo: basename(repo), commit, services: deployments, entryPoints, calls, stores }, null, 2));
console.error(`answers: ${deployments.length} workloads; entry points ${required(entryPoints)} required (+${entryPoints.length - required(entryPoints)} optional); ` +
  `calls ${required(calls)} (+${calls.length - required(calls)}); stores ${required(stores)} (+${stores.length - required(stores)})`);
