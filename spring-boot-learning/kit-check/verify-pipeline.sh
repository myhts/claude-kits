#!/usr/bin/env bash
# Proves the pipeline plugin:
#   1. upstream: kit-pipeline/upstream/ equals mattpocock/skills at the pinned commit, after our two substitutions
#   2. merge guard: the hook blocks merges, pushes to main and destructive git, and lets feature-branch pushes through
#   3. plugins: `claude plugin validate` passes for the marketplace at the repo root
#   4. every plugin installs and loads its parts
#   5. /next: its script names the right next step for each state of a repo (gh is stubbed, so it runs offline)
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
expect pipeline 'Skills \(2[6-9]|[3-9][0-9]\)' 'Agents \(6\)' 'Hooks \(1\)' 'implement' 'next' 'event-storming' 'tdd'
expect spring 'Skills \(8\)' 'spring-boot' 'build-templates'
expect e2e 'Agents \(1\)' 'e2e-tester' 'playwright'
expect spring-ai 'llm-engineering'
expect spring-web 'react-frontend'

echo "== 5. /next names the right step"
W="$(cd "$K" && pwd)/skills/next/where.sh"
nt=$(mktemp -d); trap 'rm -rf "$tmp" "$repo" "$sandbox" "$nt"' EXIT
bin=$nt/bin fix=$nt/fix proj=$nt/proj; mkdir -p "$bin" "$fix" "$proj"
cat > "$bin/gh" <<'GH'
#!/usr/bin/env bash
# Stands in for gh: answers each query where.sh makes from a fixture file.
case "$1 $2" in
  "repo view")  echo '{"nameWithOwner":"o/r","defaultBranchRef":{"name":"main"}}' ;;
  "pr list")    case "$*" in *"--state all"*) cat "$FIX/allprs" ;; *) cat "$FIX/prs" ;; esac ;;
  "issue list") case "$*" in *wayfinder:map*) cat "$FIX/maps" ;; *) cat "$FIX/issues" ;; esac ;;
  "run list")   cat "$FIX/runs" ;;
  *) exit 1 ;;
esac
GH
chmod +x "$bin/gh"
clear_fix() { local f; for f in prs allprs issues maps runs; do echo '[]' > "$fix/$f"; done; }
cases=0 out=
next_is() {   # next_is <case> <step><TAB><start of the NEXT line's what-to-do>; leaves the whole output in $out
  local got; out=$(cd "$proj" && PATH="$bin:$PATH" FIX="$fix" "$W")
  got=$(awk -F'\t' '$1 == "NEXT" {print $2 "\t" $3}' <<< "$out")
  case "$got" in "$2"*) ;; *) fail "/next, $1: expected '$2', got: $out" ;; esac
  cases=$((cases + 1))
}
git -C "$proj" init -q -b main && git -C "$proj" commit -q --allow-empty -m init
clear_fix
sha=1111111111111111111111111111111111111111
spec='{"number":40,"title":"Reservations","body":"## Problem Statement\nx","parent":null,"subIssuesSummary":{"total":2,"completed":0},"blockedBy":{"nodes":[]}}'
t42='{"number":42,"title":"Reserve a title","body":"## What to build\nx","parent":{"number":40},"subIssuesSummary":{"total":0,"completed":0},"blockedBy":{"nodes":[]}}'
t43='{"number":43,"title":"Notify the member","body":"## What to build\nx","parent":{"number":40},"subIssuesSummary":{"total":0,"completed":0},"blockedBy":{"nodes":[{"number":42,"state":"OPEN"}]}}'
t44='{"number":44,"title":"Renew a loan","body":"## What to build\nx","parent":{"number":40},"subIssuesSummary":{"total":0,"completed":0},"blockedBy":{"nodes":[]}}'
pr='{"number":57,"title":"Reserve a title","url":"https://github.com/o/r/pull/57","headRefName":"ticket/42-reserve","headRefOid":"'$sha'","isDraft":false,"mergeable":"MERGEABLE","statusCheckRollup":[{"__typename":"CheckRun","name":"verify","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"StatusContext","context":"human-review","state":"FAILURE"}],"comments":[],"closingIssuesReferences":[{"number":42}]}'
record() { echo "[{\"authorAssociation\":\"$1\",\"body\":\"<!-- human-review-record sha=$2 -->\"}]"; }

next_is "not set up" $'0\t/pipeline:setup-project'
mkdir -p "$proj/docs/agents" && printf -- '- **Default:** deliver\n- **Base branch:** main\n' > "$proj/docs/agents/stack.md"
git -C "$proj" add -A && git -C "$proj" commit -q -m card
next_is "nothing open" $'1\t/pipeline:grill-with-docs'
jq -n "[$spec | .subIssuesSummary.total = 0]" > "$fix/issues"
next_is "a spec with no tickets" $'2\t/pipeline:to-tickets #40'
jq -n "[$spec | .subIssuesSummary.completed = 2]" > "$fix/issues"
next_is "a delivered spec" $'2\tClose spec #40, then /pipeline:retro'
jq -n "[$t43]" > "$fix/issues"
next_is "every ticket blocked" $'3\tLook at #42'
jq -n "[$spec, $t42, $t43]" > "$fix/issues"
next_is "a ready ticket" $'3\t/pipeline:implement #42'
jq -n "[$spec, $t42, $t43, $t44]" > "$fix/issues"
next_is "two ready tickets of a spec, deliver mode" $'3\t/pipeline:implement #42'
grep -q 'implement #40 builds its 2 ready tickets' <<< "$out" || fail "/next: no deliver-mode hint"
jq -n "[$spec, $t42, $t43]" > "$fix/issues"
jq -n "[$pr]" > "$fix/prs"
next_is "a PR to review" $'6\t/pipeline:human-review #57'
if grep -q 'implement #42' <<< "$out"; then fail "/next suggested a ticket that already has a PR"; fi
jq -n "[$pr | .comments = $(record OWNER 2222222)]" > "$fix/prs"
next_is "new commits since the review" $'6\t/pipeline:human-review #57'
grep -q 'new commits' <<< "$out" || fail "/next: a stale record didn't say 'new commits'"
jq -n "[$pr | .comments = $(record NONE $sha)]" > "$fix/prs"
next_is "a record by someone without write access" $'6\t/pipeline:human-review #57'
jq -n "[$pr | .comments = $(record OWNER $sha)]" > "$fix/prs"
next_is "reviewed and green" $'7\tPress Merge on PR #57'
jq -n "[$pr | .statusCheckRollup[0].conclusion = \"FAILURE\"]" > "$fix/prs"
next_is "a failing check" $'4\tFix PR #57'
jq -n "[$pr | .isDraft = true]" > "$fix/prs"
next_is "a draft PR" $'4\tFinish draft PR #57'
echo '[{"databaseId":9,"workflowName":"ci","status":"completed","conclusion":"failure","event":"push","url":"u9"},{"databaseId":8,"workflowName":"ci","status":"completed","conclusion":"success","event":"push","url":"u8"}]' > "$fix/runs"
next_is "main is red" $'8\tgh run view 9'
echo '[{"databaseId":10,"workflowName":"deploy","status":"waiting","conclusion":"","event":"push","url":"u10"}]' > "$fix/runs"
next_is "production waits for approval" $'9\tApprove production: u10'
clear_fix
echo '[{"number":57,"headRefName":"ticket/42-reserve","state":"MERGED"}]' > "$fix/allprs"
next_is "merged, and nothing deploys it" $'1\t/pipeline:grill-with-docs'
grep -q $'^ALSO\t9\t/pipeline:deploy' <<< "$out" || fail "/next: undeployed merged code isn't listed"
mkdir -p "$proj/.github/workflows" && touch "$proj/.github/workflows/deploy.yml"
git -C "$proj" add -A && git -C "$proj" commit -q -m deploy
echo '[{"number":30,"title":"Payments","subIssuesSummary":{"total":3,"completed":1}}]' > "$fix/maps"
next_is "an open wayfinder map" $'1\t/pipeline:wayfinder #30'
clear_fix
git -C "$proj" switch -q -c ticket/44-renew && git -C "$proj" commit -q --allow-empty -m wip
next_is "a ticket branch with no PR" $'3\tFinish ticket #44'
git -C "$proj" switch -q main && echo x > "$proj/stray.txt"
next_is "uncommitted files on main" $'3\tMove the changes on main'
echo "garbage" > "$fix/prs"
next_is "gh returns something other than JSON" $'3\tMove the changes on main'
grep -q '^WARN' <<< "$out" || fail "/next: bad JSON from gh didn't produce a WARN line"
echo "   $cases repo states, each with the expected next step"

echo "OK: pipeline plugin verified"
