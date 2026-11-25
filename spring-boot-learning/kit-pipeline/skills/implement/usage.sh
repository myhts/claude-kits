#!/usr/bin/env bash
# Time and usage for one step: how long it took and how many tokens this session and each of its agents used.
#   usage.sh <command>    e.g. usage.sh implement: counts from the last time /implement or /pipeline:implement was
#                         typed in this session. With no such line, it counts the whole session.
# It reads Claude Code's own records of this session (the session file and one file per agent) and changes nothing.
# Their layout is not a published contract, so every failure ends the same way: one line that starts
# "Time and usage: not available", and exit 0. Needs jq. Written for macOS bash 3.2.
# The number an agent reports when it finishes is its size at the end, not what it used; that is why this script
# adds up every reply instead.
set -uo pipefail

cmd=${1:-}
na() { echo "Time and usage: not available ($1)."; exit 0; }
command -v jq >/dev/null 2>&1 || na "jq is not installed"
sid=${CLAUDE_CODE_SESSION_ID:-}
[ -n "$sid" ] || na "this session has no id"
root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
main=$(ls "$root"/*/"$sid".jsonl 2>/dev/null | head -1)
[ -n "$main" ] || na "no record of this session was found"
agents_dir="$(dirname "$main")/$sid/subagents"

tmp=$(mktemp -d) || na "no temp folder"
trap 'rm -rf "$tmp"' EXIT

# One short row per message: time, kind, reply id, model, usage, whether it carries a tool result, and whether it
# is the line where the command was typed (a tool result that only quotes the command is not).
rows() {
  jq -c --arg re "<command-name>/(pipeline:)?${cmd:-no-command}</command-name>" '
    select((.type == "user" or .type == "assistant") and .timestamp != null)
    | ((.message.content | type) == "array" and any(.message.content[]; .type? == "tool_result")) as $tool
    | {t: .timestamp, ty: .type, id: .message.id, model: .message.model, u: .message.usage, tool: $tool,
       cmd: (.type == "user" and ($tool | not) and ((.message.content | tostring) | test($re)))}' "$1" 2>/dev/null
}

# stdin: rows. $1: count from this time. Prints: model, replies, working seconds, input, input from cache, output.
# One reply can be stored on several lines, so replies are counted once each. Working time leaves out the waits
# before a new prompt: a gap counts only when it ends in a reply or in a tool result. For the main session that
# still includes the human's answers to questions, so the table shows working minutes for agents only.
summarise() {
  jq -rs --arg since "$1" '
    def ts: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
    map(select(.t >= $since)) as $r
    | ($r | map(select(.ty == "assistant" and .u != null and .id != null and .model != "<synthetic>"))
          | group_by(.id) | map(max_by(.u.output_tokens // 0))) as $a
    | if ($a | length) == 0 then empty else
        [ ($a | group_by(.model) | max_by(length) | .[0].model),
          ($a | length),
          ([range(1; $r | length) as $i | select($r[$i].ty == "assistant" or $r[$i].tool)
            | (($r[$i].t | ts) - ($r[$i - 1].t | ts))] | add // 0),
          ($a | map((.u.input_tokens // 0) + (.u.cache_creation_input_tokens // 0)) | add),
          ($a | map(.u.cache_read_input_tokens // 0) | add),
          ($a | map(.u.output_tokens // 0) | add) ] | @tsv
      end' 2>/dev/null
}

rows "$main" > "$tmp/main"
[ -s "$tmp/main" ] || na "the session record could not be read"
since=$(jq -rs 'map(select(.cmd)) | last | .t // ""' "$tmp/main" 2>/dev/null)
if [ -n "$since" ]; then from="since /$cmd was typed"
else since=$(head -1 "$tmp/main" | jq -r '.t'); from="in this session (no /${cmd:-command} line was found)"; fi
start=$(jq -rn --arg t "$since" '$t | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601' 2>/dev/null) || na "a time could not be read"
now=${USAGE_NOW:-$(date +%s)}

{
  s=$(summarise "$since" < "$tmp/main")
  [ -n "$s" ] && printf 'this session\t%s\n' "$s"
  for f in "$agents_dir"/agent-*.jsonl; do
    [ -e "$f" ] || continue
    s=$(rows "$f" | summarise "$since")
    [ -n "$s" ] || continue
    who=$(jq -r '.agentType // "agent"' "${f%.jsonl}.meta.json" 2>/dev/null) || who=agent
    printf '%s\t%s\n' "${who#pipeline:}" "$s"
  done
} > "$tmp/table"
[ -s "$tmp/table" ] || na "no replies were found"

awk -F'\t' -v wall="$(( (now - start + 30) / 60 ))" -v from="$from" '
  function tok(n) { if (n >= 999500) return sprintf("%.1fM", n / 1000000); if (n >= 1000) return sprintf("%.0fk", n / 1000); return n "" }
  function mins(s) { return sprintf("%.0f", s / 60) }
  {
    model = $2; sub(/^claude-/, "", model); sub(/-20[0-9][0-9][0-9][0-9][0-9][0-9]$/, "", model)
    key = $1 "\t" model
    if (!(key in runs)) order[++n] = key
    runs[key]++; secs[key] += $4; fresh[key] += $5; cached[key] += $6; out[key] += $7
    if ($1 != "this session") { agents++; tsecs += $4 }
    tfresh += $5; tcached += $6; tout += $7
  }
  END {
    printf "**Time and usage:** %d min on the clock %s, %d agent%s.\n\n", wall, from, agents, (agents == 1 ? "" : "s")
    print "| Who | Model | Working min | Input | Input from cache | Output |"
    print "|---|---|---|---|---|---|"
    for (i = 1; i <= n; i++) {
      key = order[i]; split(key, p, "\t")
      who = p[1] (runs[key] > 1 ? " ×" runs[key] : "")
      printf "| %s | %s | %s | %s | %s | %s |\n", who, p[2], (p[1] == "this session" ? "–" : mins(secs[key])), tok(fresh[key]), tok(cached[key]), tok(out[key])
    }
    printf "| **Total** | | %s | %s | %s | %s |\n\n", mins(tsecs), tok(tfresh), tok(tcached), tok(tout)
    print "Tokens, not money. \"Input\" is text a model read for the first time. \"Input from cache\" is text it read again, at a fraction of the price. \"Output\" is what it wrote, the dearest kind. This session has no working minutes of its own: its time is the clock time, with your answers in it."
  }' "$tmp/table"
