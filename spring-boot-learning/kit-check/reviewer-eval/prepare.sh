#!/usr/bin/env bash
# prepare.sh <repo> <project-context.md>: builds work/base, the code-only copy every reviewer reviews.
#   Tracked files only (nothing gitignored), minus everything that describes the known defects (EXCLUDE below: edit it
#   for your project); the kit installed; CLAUDE.md's "This project" filled from project-context.md (the context a
#   context-using agent is designed to have; a blind agent never sees it).
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: $0 <repo> <project-context.md>" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"; SRC="$(cd "$1" && pwd)"; CONTEXT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; B="$HERE/work/base"
EXCLUDE='^(docs/|e2e/|\.claude/|\.mcp\.json$|infra/scripts/lab\.mjs$)'   # what describes the defects in the first project
rm -rf "$HERE/work"; mkdir -p "$B"
(cd "$SRC" && git ls-files -z | grep -zvE "$EXCLUDE" | xargs -0 -I{} rsync -R "{}" "$B/")
"$HERE/../../install.sh" "$B" >/dev/null
perl -0pi -e 's/## This project \(fill in\).*\z//s' "$B/CLAUDE.md"; cat "$CONTEXT" >> "$B/CLAUDE.md"
(cd "$B" && git init -q && git add -A && git -c user.email=eval@local -c user.name=eval commit -qm baseline)
echo "ready: $B"
