#!/usr/bin/env bash
# Proves the pipeline plugin:
#   1. upstream: kit-pipeline/upstream/ equals mattpocock/skills at the pinned commit, after our two substitutions
#   2. merge guard: the hook blocks merges, pushes to main and destructive git, and lets feature-branch pushes through
#   3. plugins: `claude plugin validate` passes for the marketplace at the repo root
# Nothing is installed or changed; step 1 only downloads public files into a temp folder.
#   ./verify-pipeline.sh                    run all checks
#   ./verify-pipeline.sh --update-upstream  rewrite kit-pipeline/upstream/ from the commit pinned in upstream.lock
#                                           (moving the pin is a deliberate change: edit upstream.lock, run this, review the diff)
set -euo pipefail
cd "$(dirname "$0")"
K=../kit-pipeline
fail() { echo "FAIL: $*" >&2; exit 1; }

# The only edits we make to upstream text. Everything else is byte-for-byte.
substitute() {
  sed -e 's/setup-matt-pocock-skills/setup-project/g' \
      -e 's/see the `code-review` skill/see the `code-reviewer` agent/g'
}

fetch_upstream() {   # $1 = destination folder
  local repo sha
  read -r repo sha < <(grep -v '^#' "$K/upstream.lock" | head -1)
  grep -v '^#' "$K/upstream.lock" | tail -n +2 | while read -r path; do
    local rel="${path#skills/*/}"            # skills/engineering/tdd/SKILL.md -> tdd/SKILL.md
    mkdir -p "$1/$(dirname "$rel")"
    curl -fsSL "https://raw.githubusercontent.com/$repo/$sha/$path" | substitute > "$1/$rel" \
      || fail "could not fetch $path at $sha"
    case "$rel" in *.sh) chmod +x "$1/$rel" ;; esac
  done
}

if [ "${1:-}" = "--update-upstream" ]; then
  rm -rf "$K/upstream" && mkdir -p "$K/upstream"
  fetch_upstream "$K/upstream"
  echo "kit-pipeline/upstream/ rewritten from upstream.lock; review the diff before committing"
  exit 0
fi

echo "== 1. upstream skills match the pinned commit"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fetch_upstream "$tmp"
diff -r "$tmp" "$K/upstream" > "$tmp.diff" 2>&1 || { cat "$tmp.diff"; rm -f "$tmp.diff"; fail "kit-pipeline/upstream/ differs from upstream"; }
rm -f "$tmp.diff"
echo "   $(find "$K/upstream" -name SKILL.md | wc -l | tr -d ' ') skills identical to $(grep -v '^#' "$K/upstream.lock" | head -1)"

echo "== 2. merge guard"
G="$K/hooks/merge-guard.sh"
blocked=(
  "gh pr merge 12 --squash"
  "git push origin main"
  "git push origin HEAD:main"
  "git push -u origin master"
  "git push --force origin feature/x"
  "git push -f"
  "git push origin +feature/x"
  "git checkout feature/x && git push origin main"
  "gh api -X PUT repos/o/r/pulls/7/merge"
  "git reset --hard HEAD~1"
  "git clean -fd"
  "git branch -D old"
  "git checkout ."
  "git restore ."
)
allowed=(
  "git push -u origin feature/42-borrow-a-copy"
  "git push origin feature/x"
  "gh pr create --draft --title t --body b"
  "gh pr view 12"
  "git status"
  "git commit -m 'Merge main into feature' "
  "git log --oneline main..HEAD"
  "echo main"
)
guard() {   # $1 = command; prints the hook's exit code. Runs against a throwaway repo on branch $branch.
  local rc=0
  jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' \
    | CLAUDE_PROJECT_DIR="$repo" "$G" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}
repo=$(mktemp -d); trap 'rm -rf "$tmp" "$repo"' EXIT
git -C "$repo" init -q -b feature/x && git -C "$repo" commit -q --allow-empty -m init
for c in "${blocked[@]}"; do [ "$(guard "$c")" = 2 ] || fail "not blocked: $c"; done
for c in "${allowed[@]}"; do [ "$(guard "$c")" = 0 ] || fail "wrongly blocked: $c"; done
[ "$(guard "git push")" = 0 ] || fail "plain git push from a feature branch was blocked"
git -C "$repo" checkout -q -b main
[ "$(guard "git push")" = 2 ] || fail "plain git push from main was not blocked"
[ "$(guard "git push origin HEAD")" = 2 ] || fail "git push origin HEAD from main was not blocked"
echo "   $(( ${#blocked[@]} + 2 )) commands blocked, $(( ${#allowed[@]} + 1 )) allowed, as expected"

echo "== 3. plugin marketplace validates"
command -v claude >/dev/null || fail "claude CLI not found"
claude plugin validate ../.. 2>&1 | tail -5
claude plugin validate ../.. >/dev/null 2>&1 || fail "claude plugin validate reported errors"

echo "== 4. every plugin installs and loads its parts (throwaway HOME and project; your own config is untouched)"
sandbox=$(mktemp -d); trap 'rm -rf "$tmp" "$repo" "$sandbox"' EXIT
root="$(cd ../.. && pwd)"
mkdir -p "$sandbox/home" "$sandbox/proj" && git -C "$sandbox/proj" init -q
expect() {   # expect <plugin> <pattern...>: each pattern must appear in `claude plugin details`
  local p="$1" out; shift
  out=$(cd "$sandbox/proj" && HOME="$sandbox/home" claude plugin details "$p@kits" 2>&1)
  for pat in "$@"; do grep -qE "$pat" <<< "$out" || fail "$p: expected '$pat' in: $(grep -E 'Skills|Agents|Hooks|MCP' <<< "$out" | tr '\n' ' ')"; done
  echo "   $p: $(grep -E '^  (Skills|Agents)' <<< "$out" | sed -E 's/^  ([A-Za-z]+ \([0-9]+\)).*/\1/' | tr '\n' ' ')"
}
(cd "$sandbox/proj" && HOME="$sandbox/home" claude plugin marketplace add "$root" --scope project >/dev/null \
  && for p in pipeline spring e2e spring-ai spring-web; do HOME="$sandbox/home" claude plugin install "$p@kits" --scope project >/dev/null || exit 1; done) \
  || fail "a plugin did not install"
expect pipeline 'Skills \(2[6-9]|[3-9][0-9]\)' 'Agents \(6\)' 'Hooks \(1\)' 'implement' 'event-storming' 'tdd'
expect spring 'Skills \(8\)' 'spring-boot' 'build-templates'
expect e2e 'Agents \(1\)' 'e2e-tester' 'playwright'
expect spring-ai 'llm-engineering'
expect spring-web 'react-frontend'

echo "OK: pipeline plugin verified"
