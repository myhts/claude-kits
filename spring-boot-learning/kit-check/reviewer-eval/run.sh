#!/usr/bin/env bash
# run.sh <agent> <n>: one review in its own copy; stream-json transcript kept for the audit
E="$(cd "$(dirname "$0")" && pwd)/work"; A=$1; N=$2; W="$E/run-$A-$N"
/bin/rm -rf "$W"; /bin/cp -R "$E/base" "$W"; cd "$W"
CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 claude -p "Use the $A agent to review the backend module. Scope: backend/src/main, the whole module is the change under review (there is no diff; treat every file as new). Don't run the build or the tests: the full suite has already passed, and Docker on this machine is shared. Pass the agent only that scope and that note. Then reply with the agent's complete report verbatim and nothing else." \
  --model opus --no-session-persistence --output-format stream-json --verbose \
  --allowedTools "Agent" "Read" "Grep" "Glob" "WebFetch" "WebSearch" "Bash(git:*)" "Bash(ls:*)" "Bash(find:*)" "Bash(wc:*)" "Bash(grep:*)" "Bash(head:*)" "Bash(sed:*)" "Bash(cat:*)" \
  < /dev/null > "$E/$A-$N.jsonl" 2> "$E/$A-$N.err"
echo "$A-$N exit $?"
