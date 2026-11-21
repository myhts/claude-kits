#!/usr/bin/env bash
# prepare-arms.sh <agent> <model>:<effort> [...]: the same agent on other models and effort levels, to find the
#   cheapest setting that reviews as well as today's.
#   Adds one copy of the agent per arm to work/base (built first by prepare.sh or prepare-llm.sh), named
#   <agent>-<model>-<effort>, with only `model` and `effort` changed in its frontmatter: what the kit would ship if
#   the arm won. The unchanged agent (`model: inherit`) is the baseline. Both are always set, because a session's
#   effort doesn't reach a subagent that runs on a different model.
#     ./prepare-arms.sh code-reviewer opus:medium sonnet:high
#     for n in 1 2 3; do for a in code-reviewer code-reviewer-opus-medium code-reviewer-sonnet-high; do
#       MODEL=opus EFFORT=high ./run.sh $a $n; done; done
#   Free to prepare; the runs use plan usage (see prepare-llm.sh).
set -euo pipefail
[ $# -ge 2 ] || { echo "usage: $0 <agent> <model>:<effort> [...]" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"; D="$HERE/work/base/.claude/agents"; A=$1; shift
[ -f "$D/$A.md" ] || { echo "no $A in $D: run prepare.sh or prepare-llm.sh first" >&2; exit 1; }
grep -q '^model: ' "$D/$A.md" || { echo "$A has no model line in its frontmatter" >&2; exit 1; }
for arm in "$@"; do
  M="${arm%%:*}"; E="${arm#*:}"
  case "$arm" in *:*) ;; *) echo "arm '$arm' must be <model>:<effort>" >&2; exit 2;; esac
  case "$E" in low|medium|high|xhigh|max) ;; *) echo "effort '$E' must be low, medium, high, xhigh or max" >&2; exit 2;; esac
  case "$M" in *[!a-z0-9.-]*|"") echo "model '$M' must be an alias (opus, sonnet, haiku) or a model id" >&2; exit 2;; esac
  N="$A-$M-$E"
  # only the frontmatter (between the first two --- lines) changes; an `effort:` already there is replaced
  awk -v n="$N" -v m="$M" -v e="$E" '
    /^---$/ { fm++; print; next }
    fm == 1 && /^name: / { print "name: " n; next }
    fm == 1 && /^effort: / { next }
    fm == 1 && /^model: / { print "model: " m; print "effort: " e; next }
    { print }' "$D/$A.md" > "$D/$N.md"
  echo "arm: $N (model $M, effort $E)"
done
cd "$HERE/work/base" && git add -A
git diff --cached --quiet || git -c user.email=eval@local -c user.name=eval commit -qm "arms of $A: $*"
