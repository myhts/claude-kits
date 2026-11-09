#!/usr/bin/env node
// What a Claude Code run used, per model, subagents included:
//   node usage.mjs <run.jsonl | session.jsonl> [--json]
// A headless run (`claude -p … --output-format stream-json`) ends with a result line that has exact totals per model
// and a cost at list price; that is what's reported. An interactive session's log (~/.claude/projects/<project>/<id>.jsonl,
// subagents in <id>/subagents/) has no such line, so its per-message usage is added up instead, marked "estimated".
// Every session also makes a few small calls of Claude Code's own on a Haiku model; they're included.
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
const asJson = args.includes("--json");
const file = args.find((a) => !a.startsWith("--"));
if (!file || !existsSync(file)) { console.error("usage: node usage.mjs <run.jsonl | session.jsonl> [--json]"); process.exit(2); }

const parse = (text) => text.split("\n").filter(Boolean).flatMap((l) => { try { return [JSON.parse(l)]; } catch { return []; } });
const lines = parse(readFileSync(file, "utf8"));
const results = lines.filter((l) => l.type === "result" && l.modelUsage);
let models, exact = results.length > 0;

if (exact) {
  models = Object.entries(results.at(-1).modelUsage).map(([model, u]) => ({
    model, input: u.inputTokens, cacheWrite: u.cacheCreationInputTokens, cacheRead: u.cacheReadInputTokens,
    output: u.outputTokens, listPriceUsd: u.costUSD,
  }));
} else {
  const sub = file.replace(/\.jsonl$/, "/subagents");
  const all = [...lines, ...(existsSync(sub) ? readdirSync(sub).filter((f) => f.endsWith(".jsonl")).flatMap((f) => parse(readFileSync(join(sub, f), "utf8"))) : [])];
  // One message is logged once per content block; keep each message once, with its largest output count.
  const byId = new Map();
  for (const l of all) {
    if (l.type !== "assistant" || !l.message?.usage || l.message.model === "<synthetic>") continue;
    const id = l.message.id ?? l.requestId, seen = byId.get(id);
    if (!seen || (l.message.usage.output_tokens ?? 0) > (seen.usage.output_tokens ?? 0)) byId.set(id, { model: l.message.model, usage: l.message.usage });
  }
  const sum = new Map();
  for (const { model, usage: u } of byId.values()) {
    const m = sum.get(model) ?? { model, input: 0, cacheWrite: 0, cacheRead: 0, output: 0, listPriceUsd: null };
    m.input += u.input_tokens ?? 0; m.cacheWrite += u.cache_creation_input_tokens ?? 0;
    m.cacheRead += u.cache_read_input_tokens ?? 0; m.output += u.output_tokens ?? 0;
    sum.set(model, m);
  }
  models = [...sum.values()];
}

const total = models.reduce((t, m) => t + (m.listPriceUsd ?? 0), 0);
if (asJson) { console.log(JSON.stringify({ file, exact, models, listPriceUsd: exact ? total : null }, null, 2)); process.exit(0); }
const n = (x) => String(x ?? 0).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
console.log(`${exact ? "exact (result line)" : "estimated (per-message usage)"}: ${file}\n`);
console.log("model                        input   cache write    cache read      output   list price");
for (const m of models.sort((a, b) => (b.listPriceUsd ?? b.output) - (a.listPriceUsd ?? a.output)))
  console.log(`${m.model.padEnd(26)} ${n(m.input).padStart(7)} ${n(m.cacheWrite).padStart(13)} ${n(m.cacheRead).padStart(13)} ` +
    `${n(m.output).padStart(11)}   ${m.listPriceUsd == null ? "-" : `$${m.listPriceUsd.toFixed(4)}`}`);
if (exact) console.log(`\ntotal at list price: $${total.toFixed(4)}  (on a Max plan nothing is billed; this is the fair way to compare arms)`);
