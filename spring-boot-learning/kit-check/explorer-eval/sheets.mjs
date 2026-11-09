#!/usr/bin/env node
// The readers' own fact sheets from a headless run's log, merged into one survey, so score.mjs can score the readers
// alone, before the main session checked and merged their work. Each reader runs as a background task; its final
// reply, the fact sheet, is the `summary` of its task_notification line.
//   node sheets.mjs work/<arm>-<n>/run.jsonl > work/<arm>-<n>/raw-survey.json
// Prints the number of sheets on stderr, and any it couldn't read; exit code 1 when none could be read.
import { readFileSync } from "node:fs";

const file = process.argv[2];
if (!file) { console.error("usage: node sheets.mjs <run.jsonl>"); process.exit(2); }
const lines = readFileSync(file, "utf8").split("\n").filter(Boolean)
  .map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
const services = [], unreadable = [];
for (const n of lines.filter((m) => m.type === "system" && m.subtype === "task_notification")) {
  const text = n.summary ?? "";
  const json = text.match(/```(?:json)?\s*\n([\s\S]*?)\n```/)?.[1] ?? text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1);
  try {
    const sheet = JSON.parse(json);
    services.push(...(Array.isArray(sheet.services) ? sheet.services : [sheet]));
  } catch { unreadable.push(n.task_id); }
}
console.log(JSON.stringify({ services }, null, 1));
console.error(`${services.length} sheets${unreadable.length ? `; unreadable: ${unreadable.join(", ")}` : ""}`);
process.exit(services.length ? 0 : 1);
