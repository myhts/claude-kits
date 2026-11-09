#!/usr/bin/env node
// Scores explorer survey files against the answer key, then applies the decision rule fixed before any run:
//   an arm passes when it finds every required call the baseline found, at least 95% of the required entry points,
//   and cites no broken file:line; calls missing from the key are listed for a person to check in the code.
//   The choice is the cheapest arm that passes, by measured usage (usage.mjs); if none passes, the baseline stays.
//   This script ranks the passing arms by model price (haiku, sonnet, opus), which measured usage can overturn.
//   node score.mjs answers.json <repo> opus=runs/opus/survey.json sonnet=… haiku=… [--baseline opus] [--json]
// Exit code 1 when a survey file can't be read.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
const flag = (name, def) => { const i = args.indexOf(name); if (i < 0) return def; const v = args[i + 1]; args.splice(i, 2); return v; };
const bool = (name) => { const i = args.indexOf(name); if (i >= 0) args.splice(i, 1); return i >= 0; };
const baseline = flag("--baseline", "opus"), asJson = bool("--json");
const ORDER = ["haiku", "sonnet", "opus"], MIN_ENTRY_RECALL = 0.95;
const [answersFile, repo, ...armArgs] = args;
if (!answersFile || !repo || !armArgs.length) { console.error("usage: node score.mjs answers.json <repo> <arm>=<survey.json> … [--baseline opus] [--json]"); process.exit(2); }

// Names are compared loosely: "CheckoutService", "checkoutservice" and "checkout" are the same workload, and a note in
// brackets after a name is ignored ("EmailService.SendOrderConfirmation (a dummy: only logs)"), except a route's
// method, which may be the bracket ("/buy (POST)").
const bare = (s) => String(s ?? "").replace(/\s*\([^)]*\)/g, "").trim();
const svc = (s) => bare(s).toLowerCase().replace(/[^a-z0-9]/g, "").replace(/(.)service$/, "$1");
const store = (s) => String(s ?? "").toLowerCase().match(/redis|postgres|mysql|mongo|memcache/)?.[0] ?? svc(s);
const entry = (name, owner) => {
  const s = String(name ?? "");
  const method = s.match(/\b(GET|POST|PUT|DELETE|PATCH|ANY)\b/i)?.[1], path = s.match(/\/[^\s)]*/)?.[0];
  if (method && path) {
    const p = path.toLowerCase().replace(/\{[^}]*\}|:\w+/g, "{}").replace(/(.)\/$/, "$1");
    return `${method.toUpperCase()} ${p}`;
  }
  const parts = bare(s).split(/[./#\s]+/).filter(Boolean);
  const [service, rpc] = parts.length >= 2 ? parts.slice(-2) : [owner, parts[0]];
  return `${svc(service)}.${String(rpc ?? "").toLowerCase()}`;
};

const answers = JSON.parse(readFileSync(answersFile, "utf8"));
const key = {
  entry: new Map(answers.entryPoints.map((e) => [entry(e.name, e.service), e])),
  call: new Map(answers.calls.map((c) => [`${svc(c.from)}>${svc(c.to)}`, c])),
  store: new Map(answers.stores.map((s) => [`${svc(s.from)}>${store(s.to)}`, s])),
};
const required = (map) => [...map].filter(([, v]) => !v.optional).map(([k]) => k);
// A call not in the key either names a workload of the app (it may be invented) or something outside it (telemetry,
// a cloud API). Both are listed for a person to check; the split only says which to read first.
const workloads = new Set((answers.services ?? []).map(svc));
const toApp = (k) => workloads.has(k.split(">")[1]);

const lineCounts = new Map();
const brokenRef = (ref) => {
  const m = String(ref ?? "").match(/^(.+?):(\d+)(?:-\d+)?$/);
  if (!m) return "no line number";
  const file = join(repo, m[1]);
  if (!lineCounts.has(file)) lineCounts.set(file, existsSync(file) ? readFileSync(file, "utf8").split("\n").length : 0);
  const lines = lineCounts.get(file), line = Number(m[2]);
  return !lines ? "no such file" : line < 1 || line > lines ? `line ${line} of ${lines}` : null;
};

const score = (arm, file) => {
  let survey;
  try { survey = JSON.parse(readFileSync(file, "utf8")); } catch (e) { console.error(`${arm}: can't read ${file}: ${e.message}`); process.exit(1); }
  const found = { entry: new Set(), call: new Set(), store: new Set() }, extra = { entry: new Set(), call: new Set() };
  const broken = [];
  let refs = 0, unsure = 0;
  const cite = (ref, what) => { refs++; const why = brokenRef(ref); if (why) broken.push(`${what}: ${ref ?? "(none)"} (${why})`); };
  for (const s of survey.services ?? []) {
    unsure += (s.unsure ?? []).length;
    for (const e of s.entryPoints ?? []) {
      let k = entry(e.name, s.name);
      if (!key.entry.has(k) && key.entry.has(k.replace(/^\w+ /, "ANY "))) k = k.replace(/^\w+ /, "ANY "); // a route for every method
      (key.entry.has(k) ? found.entry : extra.entry).add(k); cite(e.ref, `${s.name} ${e.name}`);
    }
    for (const c of s.calls ?? []) {
      const sk = `${svc(s.name)}>${store(c.to)}`, k = `${svc(s.name)}>${svc(c.to)}`;
      if (key.store.has(sk)) found.store.add(sk); else (key.call.has(k) ? found.call : extra.call).add(k);
      cite(c.ref, `${s.name} → ${c.to}`);
    }
    for (const st of s.stores ?? []) {
      const k = `${svc(s.name)}>${store(st.name)}`;
      if (key.store.has(k)) found.store.add(k); cite(st.ref, `${s.name} ⇢ ${st.name}`);
    }
  }
  const req = { entry: required(key.entry), call: required(key.call), store: required(key.store) };
  const hit = (kind) => req[kind].filter((k) => found[kind].has(k));
  return {
    arm, file,
    entryPoints: { found: hit("entry").length, of: req.entry.length, missed: req.entry.filter((k) => !found.entry.has(k)), notInKey: [...extra.entry] },
    calls: { found: hit("call").length, of: req.call.length, foundKeys: hit("call"), missed: req.call.filter((k) => !found.call.has(k)),
      notInKey: [...extra.call], toApp: [...extra.call].filter(toApp), outside: [...extra.call].filter((k) => !toApp(k)) },
    stores: { found: hit("store").length, of: req.store.length, missed: req.store.filter((k) => !found.store.has(k)) },
    refs: { cited: refs, broken },
    unsure,
  };
};

const results = armArgs.map((a) => { const [arm, file] = a.split("="); return score(arm, file); });
const base = results.find((r) => r.arm === baseline);
for (const r of results) {
  const reasons = [];
  if (base && r !== base) {
    const lost = base.calls.foundKeys.filter((k) => !r.calls.foundKeys.includes(k));
    if (lost.length) reasons.push(`misses calls ${baseline} found: ${lost.join(", ")}`);
  }
  if (r.entryPoints.found / r.entryPoints.of < MIN_ENTRY_RECALL) reasons.push(`entry points ${r.entryPoints.found}/${r.entryPoints.of} (< 95%)`);
  if (r.refs.broken.length) reasons.push(`${r.refs.broken.length} broken file:line`);
  r.verdict = r === base ? "baseline" : reasons.length ? "fails" : r.calls.notInKey.length ? "passes, if the calls not in the key check out" : "passes";
  r.reasons = reasons;
}
const passing = results.filter((r) => r.verdict.startsWith("passes") || r.verdict === "baseline");
const choice = ORDER.map((a) => passing.find((r) => r.arm === a)).find(Boolean)?.arm ?? baseline;

if (asJson) { console.log(JSON.stringify({ results, choice }, null, 2)); process.exit(0); }
const pct = (x) => `${x.found}/${x.of}`;
console.log(`answer key: ${answers.repo}${answers.commit ? ` @ ${answers.commit.slice(0, 8)}` : ""}\n`);
console.log("arm      entry points  calls   stores  refs (broken)  unsure  calls not in key (to the app / outside)");
for (const r of results)
  console.log(`${r.arm.padEnd(8)} ${pct(r.entryPoints).padEnd(13)} ${pct(r.calls).padEnd(7)} ${pct(r.stores).padEnd(7)} ` +
    `${`${r.refs.cited} (${r.refs.broken.length})`.padEnd(14)} ${String(r.unsure).padEnd(7)} ${r.calls.toApp.length} / ${r.calls.outside.length}`);
console.log("");
for (const r of results) {
  console.log(`${r.arm}: ${r.verdict}${r.reasons.length ? ` (${r.reasons.join("; ")})` : ""}`);
  if (r.entryPoints.missed.length) console.log(`  missed entry points: ${r.entryPoints.missed.join(", ")}`);
  if (r.calls.missed.length) console.log(`  missed calls: ${r.calls.missed.join(", ")}`);
  if (r.calls.toApp.length) console.log(`  calls to the app not in the key (check each first): ${r.calls.toApp.join(", ")}`);
  if (r.calls.outside.length) console.log(`  calls outside the app: ${r.calls.outside.join(", ")}`);
  for (const b of r.refs.broken.slice(0, 5)) console.log(`  broken: ${b}`);
}
console.log(`\npassing, by model price: ${ORDER.filter((a) => passing.some((r) => r.arm === a)).join(", ") || baseline}`);
console.log(`choose: the cheapest of these by measured usage (usage.mjs); by price alone, ${choice}. Then the blind read of the ` +
  "draft maps, and a person checks any call not in the key.");
