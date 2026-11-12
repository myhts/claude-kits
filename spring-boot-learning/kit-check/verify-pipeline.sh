#!/usr/bin/env bash
# Proves the pipeline plugin:
#   1. upstream: kit-pipeline/upstream/ equals mattpocock/skills at the pinned commit, after our two substitutions
#   2. merge guard: the hook blocks merges, pushes to main and destructive git, and lets feature-branch pushes through
#   3. plugins: `claude plugin validate` passes for the marketplace at the repo root
#   4. every plugin installs and loads its parts
#   5. /next: its script names the right next step for each state of a repo (gh is stubbed, so it runs offline)
#   6. protecting main: protect-main.sh sends the right ruleset, and only adds to one that exists (gh is stubbed too)
#   7. interview: its runner and INTERVIEW.md agree on the phases, the prompt sheet and the files they link
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
  "gh api -X DELETE repos/o/r/rulesets/5"
  "gh api -X PUT repos/o/r/rulesets/5 --input ruleset.json"
  "gh api --method=PATCH repos/o/r/branches/main/protection/required_status_checks -F strict=false"
  "gh api repos/o/r/rulesets -f name=x"
  "gh api -XDELETE repos/o/r/branches/main/protection"
  "gh api graphql -f query='mutation { deleteRepositoryRuleset(input: {repositoryRulesetId: \"x\"}) { clientMutationId } }'"
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
  "gh api repos/o/r/rulesets"
  "gh api repos/o/r/rules/branches/main"
  "gh api -X GET repos/o/r/rulesets -f per_page=100"
  "gh api repos/o/r/branches/main/protection --jq .required_status_checks"
  "gh api repos/o/r/issues/7/comments -f body=done"
  "gh api -X POST repos/o/r/issues/7/comments -f body='the rulesets and branch protection docs'"
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
  && for p in pipeline spring e2e spring-ai spring-web interview; do HOME="$sandbox/home" claude plugin install "$p@kits" --scope project >/dev/null || exit 1; done) \
  || fail "a plugin did not install"
expect pipeline 'Skills \(2[6-9]|[3-9][0-9]\)' 'Agents \(7\)' 'Hooks \(1\)' 'implement' 'next' 'event-storming' 'tdd' 'project-explorer'
expect spring 'Skills \(8\)' 'spring-boot' 'build-templates'
expect e2e 'Agents \(1\)' 'e2e-tester' 'playwright'
expect spring-ai 'llm-engineering'
expect spring-web 'react-frontend'
expect interview 'Skills \(1\)' 'start'

echo "== 5. /next names the right step"
W="$(cd "$K" && pwd)/skills/next/where.sh"
nt=$(mktemp -d); trap 'rm -rf "$tmp" "$repo" "$sandbox" "$nt"' EXIT
bin=$nt/bin fix=$nt/fix proj=$nt/proj; mkdir -p "$bin" "$fix" "$proj"
cat > "$bin/gh" <<'GH'
#!/usr/bin/env bash
# Stands in for gh: answers each query where.sh makes from a fixture file.
case "$1 $2" in
  "repo view")  cat "$FIX/repo" ;;
  "pr list")    case "$*" in *"--state all"*) cat "$FIX/allprs" ;; *) cat "$FIX/prs" ;; esac ;;
  "issue list") case "$*" in *wayfinder:map*) cat "$FIX/maps" ;; *) cat "$FIX/issues" ;; esac ;;
  "run list")   cat "$FIX/runs" ;;
  "api repos/o/r/branches/main")       jq -c "$4" "$FIX/branch" ;;   # $3 is --jq, $4 its filter
  "api repos/o/r/rules/branches/main") jq -c "$4" "$FIX/rules" ;;
  *) exit 1 ;;
esac
GH
chmod +x "$bin/gh"
public='{"nameWithOwner":"o/r","defaultBranchRef":{"name":"main"},"visibility":"PUBLIC"}'
protected() {   # protected <check...>: the checks classic branch protection requires on main
  jq -n '{protection: {required_status_checks: {contexts: $ARGS.positional}}}' --args "$@" > "$fix/branch"; }
clear_fix() { local f; for f in prs allprs issues maps runs rules; do echo '[]' > "$fix/$f"; done
  echo "$public" > "$fix/repo"; protected human-review verify; }
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
protected
next_is "not protected, before the setup reaches main" $'1\t/pipeline:grill-with-docs'
mkdir -p "$proj/.github/workflows" && touch "$proj/.github/workflows/human-review.yml"
git -C "$proj" add -A && git -C "$proj" commit -q -m checks
next_is "main not protected" $'0\t/pipeline:setup-project protect'
jq -c '.visibility = "PRIVATE"' <<< "$public" > "$fix/repo"
next_is "a private repo, not protected" $'1\t/pipeline:grill-with-docs'
echo "$public" > "$fix/repo"
echo '[{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"human-review","integration_id":15368}]}}]' > "$fix/rules"
next_is "main protected by a ruleset" $'1\t/pipeline:grill-with-docs'
clear_fix
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
protected human-review
next_is "a PR check main doesn't require" $'6\t/pipeline:human-review #57'
grep -q $'^ALSO\t0\t/pipeline:setup-project protect\tPRs run verify,' <<< "$out" || fail "/next: an unrequired PR check isn't listed: $out"
printf -- '- **Checks not required:** e2e, verify\n' >> "$proj/docs/agents/stack.md"
next_is "a PR check left out on purpose" $'6\t/pipeline:human-review #57'
if grep -q 'PRs run verify' <<< "$out"; then fail "/next suggested a check the stack card leaves out"; fi
git -C "$proj" checkout -q docs/agents/stack.md
protected human-review verify
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

echo "== 6. protect-main.sh"
P="$(cd "$K" && pwd)/skills/setup-project/protect-main.sh"
pt=$(mktemp -d); trap 'rm -rf "$tmp" "$repo" "$sandbox" "$nt" "$pt"' EXIT
mkdir -p "$pt/bin" "$pt/fix"
cat > "$pt/bin/gh" <<'GH'
#!/usr/bin/env bash
# Stands in for gh: answers protect-main.sh from fixture files, and keeps what it sends in $FIX/sent.
case "$*" in
  "repo view"*)               cat "$FIX/repo" ;;
  "api apps/github-actions"*) echo 15368 ;;
  "api -X "*)                 echo "$3 $4" > "$FIX/sent.to"; cat > "$FIX/sent"
                              jq '. + {id: 7, _links: {html: {href: "https://github.com/o/r/rules/7"}}}' "$FIX/sent" ;;
  *"/rulesets?"*)             cat "$FIX/rulesets" ;;
  *"/rulesets/7")             cat "$FIX/ruleset" ;;
  *"/protection")             [ -f "$FIX/classic" ] && echo '{}' ;;
  *) exit 1 ;;
esac
GH
chmod +x "$pt/bin/gh"
protect() { rm -f "$pt/fix/sent" "$pt/fix/sent.to"; (cd "$pt" && PATH="$pt/bin:$PATH" FIX="$pt/fix" "$P" "$@"); }
sent() { jq -c "$1" "$pt/fix/sent"; }
expect_sent() {   # expect_sent <case> <jq filter> <expected compact JSON>
  [ "$(sent "$2")" = "$3" ] || fail "protect-main, $1: $2 gave $(sent "$2"), expected $3"; }
admin='{"nameWithOwner":"o/r","viewerPermission":"ADMIN","defaultBranchRef":{"name":"main"}}'
echo "$admin" > "$pt/fix/repo"; echo '[]' > "$pt/fix/rulesets"
pin='"integration_id":15368'

out=$(protect --dry-run human-review) || fail "protect-main --dry-run failed: $out"
grep -q '^Would send: POST repos/o/r/rulesets$' <<< "$out" || fail "protect-main --dry-run printed: $out"
[ ! -f "$pt/fix/sent" ] || fail "protect-main --dry-run sent something"

out=$(protect verify human-review) || fail "protect-main failed: $out"
[ "$(cat "$pt/fix/sent.to")" = "POST repos/o/r/rulesets" ] || fail "protect-main sent to $(cat "$pt/fix/sent.to")"
expect_sent "new" '[.name, .target, .enforcement, .conditions.ref_name.include, .bypass_actors]' \
  '["claude-kits: main","branch","active",["~DEFAULT_BRANCH"],[]]'
expect_sent "new" '[.rules[].type]' '["deletion","non_fast_forward","pull_request","required_status_checks"]'
expect_sent "new" '.rules[] | select(.type == "pull_request") | .parameters.required_approving_review_count' 0
expect_sent "new" '.rules[] | select(.type == "required_status_checks") | .parameters' \
  '{"required_status_checks":[{"context":"human-review",'"$pin"'},{"context":"verify",'"$pin"'}],"strict_required_status_checks_policy":false}'
grep -q '^Required checks: human-review, verify$' <<< "$out" || fail "protect-main printed: $out"
if grep -q 'classic' <<< "$out"; then fail "protect-main mentioned a classic rule that isn't there"; fi

protect --strict human-review >/dev/null || fail "protect-main --strict failed"
expect_sent "strict" '.rules[] | select(.type == "required_status_checks") | .parameters.strict_required_status_checks_policy' true

# A ruleset that exists, which a human tightened: one approval, linear history, branches up to date.
echo '[{"id":8,"name":"something else"},{"id":7,"name":"claude-kits: main"}]' > "$pt/fix/rulesets"
cat > "$pt/fix/ruleset" <<'JSON'
{"id":7,"name":"claude-kits: main","target":"branch","enforcement":"active","source_type":"Repository",
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"bypass_actors":[],
 "rules":[{"type":"pull_request","parameters":{"required_approving_review_count":1,"dismiss_stale_reviews_on_push":true,
   "require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}},
  {"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"human-review","integration_id":15368}],
   "strict_required_status_checks_policy":true}},
  {"type":"required_linear_history"}]}
JSON
touch "$pt/fix/classic"
out=$(protect human-review verify) || fail "protect-main on an existing ruleset failed: $out"
[ "$(cat "$pt/fix/sent.to")" = "PUT repos/o/r/rulesets/7" ] || fail "protect-main sent to $(cat "$pt/fix/sent.to")"
expect_sent "existing" '[.rules[].type]' \
  '["pull_request","required_status_checks","required_linear_history","deletion","non_fast_forward"]'
expect_sent "existing" '.rules[] | select(.type == "pull_request") | .parameters.required_approving_review_count' 1
expect_sent "existing" '.rules[] | select(.type == "required_status_checks") | .parameters' \
  '{"required_status_checks":[{"context":"human-review",'"$pin"'},{"context":"verify",'"$pin"'}],"strict_required_status_checks_policy":true}'
expect_sent "existing" 'has("id") or has("source_type")' false
grep -q 'classic branch protection rule' <<< "$out" || fail "protect-main didn't mention the classic rule: $out"

jq -c '.viewerPermission = "WRITE"' <<< "$admin" > "$pt/fix/repo"
if out=$(protect human-review 2>&1); then fail "protect-main ran without admin rights"; fi
grep -q 'needs admin rights' <<< "$out" || fail "protect-main without admin rights said: $out"
[ ! -f "$pt/fix/sent" ] || fail "protect-main sent something without admin rights"
if protect >/dev/null 2>&1; then fail "protect-main ran with no checks"; fi
echo "   6 cases: dry run, new, strict, an existing ruleset, no admin rights, no checks"

echo "== 7. interview: the runner and INTERVIEW.md agree"
I=../kit-interview/skills/start; D=../../INTERVIEW.md
[ "$(wc -l < "$I/SKILL.md")" -le 150 ] || fail "interview: SKILL.md is over 150 lines"
for f in phases.md bar.md checklists.md prompts.md; do grep -q "]($f)" "$I/SKILL.md" || fail "interview: SKILL.md doesn't link $f"; done
for ph in Orient Reproduce Diagnose Fix Review Wrap; do
  grep -q "^## $ph\$" "$I/phases.md" || fail "interview: phases.md has no '## $ph'"
  grep -q "^| \*\*$ph\*\* |" "$D" || fail "interview: INTERVIEW.md has no row for $ph"
done
diff <(grep '^| [0-9]' "$I/prompts.md") <(grep '^| [0-9]' "$D") >/dev/null || fail "interview: the prompt sheet differs between prompts.md and INTERVIEW.md"
grep -o '](spring-boot-learning/[^)#]*' "$D" | cut -c3- | sort -u | while read -r f; do [ -e "../../$f" ] || fail "interview: INTERVIEW.md links a missing file: $f"; done
grep -q '/interview:start' "$D" && [ "$(sed -n 's/^name: //p' "$I/SKILL.md")" = start ] || fail "interview: the command in INTERVIEW.md doesn't match the skill's name"
echo "   six phases, $(grep -c '^| [0-9]' "$I/prompts.md") prompts and every linked file match"

echo "OK: pipeline plugin verified"
