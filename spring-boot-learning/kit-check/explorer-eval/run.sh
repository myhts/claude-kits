#!/usr/bin/env bash
# run.sh <repo> <arm> [n]: one survey by the project-explorer, its readers on the arm's model (opus, sonnet, haiku),
# in a fresh clone of <repo>. The main session is MAIN=opus in every arm; only the readers change. It stops before
# gate 1, having written docs/explorer/survey.json (survey-format.md) and docs/explorer/draft-map.md.
#   Runs on your Claude Code login (a Max/Pro subscription), never an API key: the key variables are unset below.
#   Loads the pipeline plugin from this checkout of claude-kits (--plugin-dir), so the copy needs nothing installed.
#   Output in work/<arm>-<n>/: repo/ (the clone), run.jsonl (for usage.mjs), survey.json and draft-map.md (for score.mjs).
set -uo pipefail
H="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$1" && pwd)"; ARM=$2; N=${3:-1}; MAIN="${MAIN:-opus}"
case "$ARM" in opus|sonnet|haiku) ;; *) echo "arm must be opus, sonnet or haiku" >&2; exit 2 ;; esac
W="$H/work/$ARM-$N"; /bin/rm -rf "$W"; mkdir -p "$W"
git clone -q "$REPO" "$W/repo" && cd "$W/repo" || exit 1
PROMPT="Use the project-explorer skill on this repository, for an evaluation run. Follow its Phase 0 and Phase 1 only, with these changes.
Survey with one Explore subagent per service folder under src/, all started in one message, each with model \"$ARM\". Give each the reader rules and the fact-sheet format below, and ask it to return only its fact sheet.
Don't run the app, build anything or start containers: trace from the code, using read-only commands only.
When the fact sheets are back, merge them into docs/explorer/survey.json in the format below, and write the draft map (boxes and arrows, by lane) and the flow list to docs/explorer/draft-map.md.
Don't ask gate 1: stop after writing those two files, and reply with one line saying they're written.

$(cat "$H/survey-format.md")"
env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 claude -p "$PROMPT" \
  --model "$MAIN" --plugin-dir "$H/../../kit-pipeline" --no-session-persistence --output-format stream-json --verbose \
  --allowedTools "Skill" "Agent" "Read" "Grep" "Glob" "Write" "Edit" "Bash(ls:*)" "Bash(find:*)" "Bash(grep:*)" "Bash(rg:*)" \
    "Bash(head:*)" "Bash(tail:*)" "Bash(sed:*)" "Bash(cat:*)" "Bash(wc:*)" "Bash(git:*)" "Bash(mkdir:*)" "Bash(node --version)" \
  < /dev/null > "$W/run.jsonl" 2> "$W/run.err"
status=$?
cp docs/explorer/survey.json docs/explorer/draft-map.md "$W/" 2>/dev/null || echo "$ARM-$N: survey files missing" >&2
echo "$ARM-$N exit $status · $(git rev-parse --short HEAD) · $(ls "$W" | tr '\n' ' ')"
