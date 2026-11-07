#!/usr/bin/env bash
# prepare-llm.sh: sets up the LLM review evaluation on the invented fixture (fixtures/llm-claims, 10 planted defects).
#   Builds work/base as prepare.sh does, and adds the agents as they were BEFORE the LLM checklist change (from git,
#   at the commit given, default HEAD) as code-reviewer-before, spring-security-reviewer-before and
#   blind-reviewer-before, so the new and old versions are reviewed on the same code:
#     ./prepare-llm.sh [commit]
#     for n in 1 2 3; do ./run.sh code-reviewer $n & ./run.sh code-reviewer-before $n & done; wait
#   Free to prepare. The runs are headless Claude Code reviews on your subscription (run.sh unsets any API key), so
#   they use plan usage, not API credit: 18 Opus reviews is a sizeable share of a usage window, so spread them out.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; REF="${1:-HEAD}"
REPO_ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
PREFIX="$(git -C "$HERE" rev-parse --show-prefix | sed 's|kit-check/reviewer-eval/$||')"
# the agents moved to kit-pipeline/agents on 2026-11-01; older commits have them in kit/.claude/agents.
# spring-security-reviewer was called security-reviewer until 2026-11-05.
agent_at_ref() { local n; for n in "$1" "${1#spring-}"; do
  git -C "$REPO_ROOT" show "$REF:${PREFIX}kit-pipeline/agents/$n.md" 2>/dev/null && return
  git -C "$REPO_ROOT" show "$REF:${PREFIX}kit/.claude/agents/$n.md" 2>/dev/null && return
done; echo "no $1 agent at $REF" >&2; return 1; }
SRC="$(mktemp -d)/llm-claims"
trap 'rm -rf "$(dirname "$SRC")"' EXIT

# prepare.sh reviews a git repository's tracked files: give it one holding only the fixture's code
mkdir -p "$SRC" && (cd "$HERE/fixtures/llm-claims" && find . -type f ! -path '*/target/*' ! -path '*/.mvn/*' ! -name mvnw -print0 \
  | xargs -0 -I{} rsync -R "{}" "$SRC/")
(cd "$SRC" && git init -q && git add -A && git -c user.email=eval@local -c user.name=eval commit -qm fixture)
"$HERE/prepare.sh" "$SRC" "$HERE/fixtures/llm-claims.context.md"

B="$HERE/work/base"
# the product will have the LLM layer installed: both agent versions review with the skill present
"$HERE/../../install.sh" "$B" --ai >/dev/null && rm -f "$B/CLAUDE.ai.md" "$B/CLAUDE.learning.md"
for a in code-reviewer spring-security-reviewer blind-reviewer; do
  agent_at_ref "$a" > "$B/.claude/agents/$a-before.md"
  perl -pi -e "s/^name: \S+\$/name: $a-before/" "$B/.claude/agents/$a-before.md"
  if cmp -s "$B/.claude/agents/$a.md" <(perl -pe "s/^name: $a-before\$/name: $a/" "$B/.claude/agents/$a-before.md"); then
    echo "note: $a at $REF is the same as the current one: pass the commit before the change" >&2
  fi
done
(cd "$B" && git add -A && git -c user.email=eval@local -c user.name=eval commit -qm "before-versions of the agents")
echo "ready: $B (agents: code-reviewer, spring-security-reviewer, blind-reviewer, each also as <name>-before)"
echo "answer key: $HERE/fixtures/llm-claims.answer-key.md (keep it away from the reviewers)"
