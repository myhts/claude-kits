#!/usr/bin/env bash
# where.sh: where this repository is in the delivery flow, and the one thing to do next. /pipeline:next runs it.
# Read-only: git, gh and jq queries. Nothing is written here or on GitHub.
# Prints tab-separated lines:
#   REPO  <owner/repo>  <branch>  <build mode>
#   WARN  <something it couldn't read>
#   NEXT  <step 0-9>  <what to type or do>  <why>    the first rule that matches
#   ALSO  <step 0-9>  <what to type or do>  <why>    up to three more matches, in rule order
# The rules run from production back to planning, so work in flight finishes before new work starts.
# Needs git, gh and jq. Written for macOS bash 3.2.
set -uo pipefail

hits=() warns=()
hit()  { hits+=("$1"$'\t'"$2"$'\t'"$3"); }   # hit <step> <what to type or do> <why>
warn() { warns+=("$1"); }
plural() { if [ "$1" = 1 ]; then echo "1 $2"; else echo "$1 ${2}s"; fi; }
report() {   # report <repo>: print everything collected, then stop
  local h i=0
  printf 'REPO\t%s\t%s\t%s\n' "$1" "$branch" "${mode:--}"
  for h in ${warns[@]+"${warns[@]}"}; do printf 'WARN\t%s\n' "$h"; done
  for h in ${hits[@]+"${hits[@]}"}; do
    if [ $i -eq 0 ]; then printf 'NEXT\t%s\n' "$h"; else printf 'ALSO\t%s\n' "$h"; fi
    i=$((i + 1)); [ $i -lt 4 ] || break
  done
  exit 0
}

branch=- mode=
root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  hit 0 "git init, then /pipeline:setup-project" "This folder is not a git repository."; report -; }
cd "$root" || exit 1
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo -)
card=docs/agents/stack.md
[ -f "$card" ] || { hit 0 /pipeline:setup-project "There is no stack card ($card): the flow isn't set up here yet."; report -; }
mode=$(sed -n 's/^- \*\*Default:\*\* *\([a-z-][a-z-]*\).*/\1/p' "$card" | head -1)
base=$(sed -n 's/^- \*\*Base branch:\*\* *\([^ ]*\).*/\1/p' "$card" | head -1)
command -v jq >/dev/null || {
  hit 0 "Install jq (brew install jq, or apt install jq)" "The merge guard reads commands with jq; without it, it lets everything through."
  report -; }

# ---- read GitHub once -----------------------------------------------------------------------------------------------
repo=- prs='[]' allprs='[]' issues='[]' maps='[]' runs='[]'
q() {   # q <variable> <gh arguments...>: sets the variable to the JSON, or to [] with a warning
  local var=$1 out; shift
  if out=$(gh "$@" 2>/dev/null) && jq -e . >/dev/null 2>&1 <<< "$out"; then printf -v "$var" '%s' "$out"
  else warn "gh $1 $2 failed or returned something other than JSON, so it was skipped"; printf -v "$var" '[]'; fi
}
if ! command -v gh >/dev/null; then
  hit 0 "Install gh 2.94 or later" "Specs, tickets and pull requests live on GitHub, and the flow reaches them through gh."
elif ! info=$(gh repo view --json nameWithOwner,defaultBranchRef,visibility 2>/dev/null); then
  warn "gh can't read a GitHub repository here (try gh auth status), so only local state was checked"
else
  repo=$(jq -r .nameWithOwner <<< "$info")
  [ -n "$base" ] || base=$(jq -r '.defaultBranchRef.name // empty' <<< "$info")
  q prs pr list --state open --limit 50 \
    --json number,title,url,headRefName,headRefOid,isDraft,mergeable,statusCheckRollup,comments,closingIssuesReferences
  q allprs pr list --state all --limit 200 --json number,headRefName,state
  q issues issue list --state open --label ready-for-agent --limit 100 --json number,title,body,parent,subIssuesSummary,blockedBy
  q maps issue list --state open --label wayfinder:map --limit 20 --json number,title,subIssuesSummary
fi
base=${base:-main}
since=$base; git rev-parse -q --verify "origin/$base" >/dev/null && since=origin/$base   # a local base can be behind
[ "$repo" = - ] || q runs run list --branch "$base" --limit 30 --json databaseId,workflowName,status,conclusion,event,url

# The checks the base requires, from classic branch protection and from rulesets. Empty when it couldn't be read.
required=
if [ "$repo" != - ]; then
  if classic=$(gh api "repos/$repo/branches/$base" --jq '[.protection.required_status_checks.contexts[]?]' 2>/dev/null) \
     && ruled=$(gh api "repos/$repo/rules/branches/$base" \
          --jq '[.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context]' 2>/dev/null) \
     && required=$(jq -cs 'add | unique' <<< "$classic$ruled" 2>/dev/null); then :
  else required=; warn "gh couldn't read the protection of $base, so it wasn't checked"; fi
fi
requires() { [ -n "$required" ] && jq -e --arg c "$1" 'any(. == $c)' <<< "$required" >/dev/null; }

# ---- 0: the base isn't protected yet. Once the setup is on it, this comes first: it takes a minute -------------------
if [ -n "$required" ] && ! requires human-review && [ "$(jq -r '.visibility // ""' <<< "$info")" != PRIVATE ] \
   && git cat-file -e "$since:.github/workflows/human-review.yml" 2>/dev/null; then
  hit 0 "/pipeline:setup-project protect" "$base doesn't require the human-review check yet, so a PR can merge without your review. This adds GitHub's protection."
fi

# ---- 9 and 8: what is on its way to production ----------------------------------------------------------------------
row=$(jq -r '[.[] | select(.status == "waiting")] | first // empty | [.workflowName, .url] | @tsv' <<< "$runs")
if [ -n "$row" ]; then
  IFS=$'\t' read -r wf url <<< "$row"
  hit 9 "Approve production: $url" "The $wf run passed staging and waits for your approval."
fi
row=$(jq -r '[.[] | select(.event == "push" or .event == "workflow_dispatch")] | group_by(.workflowName)
  | map(max_by(.databaseId)) | map(select(.conclusion | IN("failure", "timed_out", "startup_failure")))
  | first // empty | [.workflowName, .databaseId, .url] | @tsv' <<< "$runs")
if [ -n "$row" ]; then
  IFS=$'\t' read -r wf id url <<< "$row"
  hit 8 "gh run view $id --log-failed" "The last $wf run on $base failed ($url). Fix it in a small PR first: every merge builds on it."
fi

# ---- 7 to 4: open pull requests ---------------------------------------------------------------------------------------
# One row per PR: state, number, title, url, branch, short head, failed checks, running checks, first or again.
# human-review is left out of the checks: it is red until the review, which is what the states below are about.
pr_rows=$(jq -r '
  def bad: (.conclusion // "" | IN("FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"))
        or (.state // "" | IN("FAILURE", "ERROR"));
  def running: (.__typename == "CheckRun" and .status != "COMPLETED") or (.state // "" | IN("PENDING", "EXPECTED"));
  def check: .name // .context;
  sort_by(.number)[] | .headRefOid as $sha
  | [.statusCheckRollup[]? | select(check != "human-review")] as $checks
  | ([$checks[] | select(bad) | check] | unique | join(", ")) as $failed
  | ([$checks[] | select(running)] | length) as $running
  | [.comments[]? | select(.authorAssociation | IN("OWNER", "MEMBER", "COLLABORATOR")) | .body
     | select(contains("<!-- human-review-record sha="))] as $records
  | any($records[]; contains("<!-- human-review-record sha=" + $sha + " -->")) as $current
  | (if .isDraft then "draft" elif .mergeable == "CONFLICTING" then "conflict" elif $failed != "" then "failing"
     elif $current and $running == 0 then "merge" elif $current then "checks" else "review" end) as $state
  | [$state, .number, .title, .url, .headRefName, $sha[0:7], (if $failed == "" then "-" else $failed end), $running,
     (if ($records | length) > 0 and ($current | not) then "again" else "first" end)] | @tsv' <<< "$prs")
pr_state() { awk -F'\t' -v s="$1" '$1 == s' <<< "$pr_rows"; }
for state in merge review conflict failing checks draft; do
  rows=$(pr_state "$state"); [ -n "$rows" ] || continue
  more=$(( $(grep -c . <<< "$rows") - 1 )); extra=""
  IFS=$'\t' read -r _ n title url head sha failed running again <<< "$(head -1 <<< "$rows")"
  case $state in
    merge)    [ $more -eq 0 ] || extra=" $(plural $more "more PR") also ready."
              hit 7 "Press Merge on PR #$n: $url" "\"$title\" has your review record for its head commit $sha and green checks. Only you can merge.$extra" ;;
    review)   [ $more -eq 0 ] || extra=" $(plural $more "more PR") also wait."
              [ "$running" = 0 ] || extra=" CI is still running; you can start anyway.$extra"
              if [ "$again" = again ]; then why="\"$title\" has new commits since your last review record; $sha needs one."
              else why="\"$title\" has no review record for its head commit $sha yet."; fi
              hit 6 "/pipeline:human-review #$n" "$why$extra" ;;
    conflict) hit 4 "Update PR #$n with $base" "\"$title\" conflicts with $base. Ask Claude to merge $base into $head and resolve the conflicts." ;;
    failing)  hit 4 "Fix PR #$n (gh pr checks $n)" "$failed failed on \"$title\". Ask Claude to fix it on $head; your review comes after green checks." ;;
    checks)   hit 7 "Wait for CI on PR #$n, then press Merge" "\"$title\" is reviewed; $(plural "$running" check) still running." ;;
    draft)    hit 4 "Finish draft PR #$n" "\"$title\" is a draft. When it's done: gh pr ready $n." ;;
  esac
done

# ---- 3: work on a branch with no pull request yet ---------------------------------------------------------------------
heads=$(jq -r '.[].headRefName' <<< "$allprs")
ticket_of() { sed -n 's#^ticket/\([0-9][0-9]*\).*#\1#p' <<< "$1"; }
ahead() { git rev-list --count "$since..$1" 2>/dev/null || echo 0; }
dirty=$(git status --porcelain | grep -c .)
if [ "$branch" = "$base" ]; then
  [ "$dirty" -eq 0 ] || hit 3 "Move the changes on $base to a branch: git switch -c <name>" \
    "$(plural "$dirty" "uncommitted file") on $base. Changes reach $base only through a PR."
elif [ "$branch" != HEAD ] && ! grep -qxF "$branch" <<< "$heads"; then
  n=$(ahead "$branch")
  if [ "$dirty" -gt 0 ] || [ "$n" -gt 0 ]; then
    what=""; [ "$n" -eq 0 ] || what=$(plural "$n" commit)
    [ "$dirty" -eq 0 ] || what="${what:+$what and }$(plural "$dirty" "uncommitted file")"
    t=$(ticket_of "$branch")
    if [ -n "$t" ]; then hit 3 "Finish ticket #$t on $branch" "It has $what and no PR yet. Ask Claude to finish it and open the PR."
    else hit 4 "Open a PR for $branch" "It has $what and no PR yet."; fi
  fi
fi
for b in $(git for-each-ref --format='%(refname:short)' refs/heads/ticket/); do
  [ "$b" != "$branch" ] && ! grep -qxF "$b" <<< "$heads" && [ "$(ahead "$b")" -gt 0 ] || continue
  hit 3 "Finish ticket #$(ticket_of "$b") on $b" "The branch has commits and no PR yet (a worktree, perhaps). Ask Claude to finish it and open the PR."
  break
done

# ---- 3 to 1: tickets, specs and maps ----------------------------------------------------------------------------------
# A ticket is busy when an open PR closes it or a ticket/<n>- branch exists for it.
busy=$( { jq -r '.[].closingIssuesReferences[]?.number' <<< "$prs"
          git for-each-ref --format='%(refname:short)' refs/heads/ticket/ | sed -n 's#^ticket/\([0-9][0-9]*\).*#\1#p'; } | sort -u)
# One row per ready-for-agent issue: kind, number, title, open blockers, sub-issues total and closed, parent.
issue_rows=$(jq -r '
  def kind: (.body // "") as $b
    | if $b | test("^## (Acceptance criteria|What to build)"; "m") then "ticket"
      elif (.subIssuesSummary.total // 0) > 0 or ($b | test("^## (Problem Statement|User Stories)"; "m")) then "spec"
      else "ticket" end;
  sort_by(.number)[]
  | [kind, .number, .title,
     ([.blockedBy.nodes[]? | select(.state == "OPEN") | .number | tostring] | join(",") | if . == "" then "-" else . end),
     (.subIssuesSummary.total // 0), (.subIssuesSummary.completed // 0), (.parent.number // "-")] | @tsv' <<< "$issues")
ready=$(awk -F'\t' '$1 == "ticket" && $4 == "-"' <<< "$issue_rows" | while IFS=$'\t' read -r _ n title _ _ _ parent; do
  grep -qxF "$n" <<< "$busy" || printf '%s\t%s\t%s\n' "$n" "$title" "$parent"; done)
if [ -n "$ready" ]; then
  IFS=$'\t' read -r n title parent <<< "$(head -1 <<< "$ready")"
  more=$(( $(grep -c . <<< "$ready") - 1 )); extra=""
  [ $more -eq 0 ] || extra=" $(plural $more "more ticket") also ready."
  if [ "$mode" = deliver ] && [ "$parent" != - ]; then
    siblings=$(awk -F'\t' -v p="$parent" '$3 == p' <<< "$ready" | grep -c .)
    [ "$siblings" -lt 2 ] || extra="$extra In deliver mode, /pipeline:implement #$parent builds its $siblings ready tickets in parallel."
  fi
  hit 3 "/pipeline:implement #$n" "\"$title\" is ready: nothing blocks it, and it has no PR or branch yet.$extra"
elif [ -z "$pr_rows" ]; then
  row=$(awk -F'\t' '$1 == "ticket" && $4 != "-"' <<< "$issue_rows" | head -1)
  if [ -n "$row" ]; then
    IFS=$'\t' read -r _ n title blockers _ <<< "$row"
    hit 3 "Look at #${blockers%%,*}" "Every ready ticket is blocked. \"$title\" (#$n) waits on #${blockers//,/, #}, and nothing is in review."
  fi
fi
row=$(awk -F'\t' '$1 == "spec" && $5 > 0 && $5 == $6' <<< "$issue_rows" | head -1)
if [ -n "$row" ]; then
  IFS=$'\t' read -r _ n title _ <<< "$row"
  hit 2 "Close spec #$n, then /pipeline:retro" "Every ticket of \"$title\" is closed, so the feature is delivered."
fi
row=$(awk -F'\t' '$1 == "spec" && $5 == 0' <<< "$issue_rows" | head -1)
if [ -n "$row" ]; then
  IFS=$'\t' read -r _ n title _ <<< "$row"
  hit 2 "/pipeline:to-tickets #$n" "Spec \"$title\" has no tickets yet."
fi
row=$(jq -r 'sort_by(.number) | first // empty
  | [.number, .title, (.subIssuesSummary.total // 0), (.subIssuesSummary.completed // 0)] | @tsv' <<< "$maps")
if [ -n "$row" ]; then
  IFS=$'\t' read -r n title total closed <<< "$row"
  if [ "$total" -gt 0 ] && [ "$total" = "$closed" ]; then
    hit 2 "/pipeline:to-spec #$n" "Every decision on the map \"$title\" is made, so it's ready to become a spec."
  elif [ "$total" -eq 0 ]; then
    hit 1 "/pipeline:wayfinder #$n" "The map \"$title\" has no decision tickets yet."
  else
    hit 1 "/pipeline:wayfinder #$n" "The map \"$title\" has $(plural $((total - closed)) "open decision") to work through."
  fi
fi

# ---- 1: nothing open, so start something ------------------------------------------------------------------------------
if [ ${#hits[@]} -eq 0 ]; then
  why="No open PRs, ready tickets, specs or maps."
  [ -f GLOSSARY.md ] || [ -f GLOSSARY-MAP.md ] || why="$why The first feature also starts GLOSSARY.md."
  hit 1 "/pipeline:grill-with-docs <your next idea>" "$why For work bigger than one session: /pipeline:wayfinder <idea>."
fi

# ---- 9: nothing deploys what is merged. Never first: not every project ships, and new work can start without it ----
merged=$(jq '[.[] | select(.state == "MERGED")] | length' <<< "$allprs")
if [ "$merged" -gt 0 ] && [ ! -f .github/workflows/deploy.yml ] && [ ! -f .github/workflows/deploy.yaml ]; then
  hit 9 /pipeline:deploy "Code is merged, but nothing deploys it yet. Run this once, before the first release."
fi

# ---- 0: a check PRs run that the base doesn't require. Never first: it matters before the next merge, not now ------
# The kit's own pr-size and human-review jobs never gate a merge, and the stack card can list checks left out on purpose.
if requires human-review; then
  optional=$(sed -n 's/^- \*\*Checks not required:\*\* *//p' "$card" | head -1)
  loose=$(jq -r --argjson req "$required" --arg opt "$optional" '
    ($opt | split(",") | map(gsub("^ +| +$"; ""))) as $skip
    | [.[].statusCheckRollup[]? | select(.__typename == "CheckRun")
       | select(.workflowName // "" | IN("pr-size", "human-review") | not)
       | .name | select(IN($req[]) | not) | select(IN($skip[]) | not)] | unique | join(", ")' <<< "$prs")
  [ -z "$loose" ] || hit 0 "/pipeline:setup-project protect" \
    "PRs run $loose, which $base doesn't require yet, so a PR could merge with it red. To leave it out on purpose, list it under Checks not required in $card."
fi
report "$repo"
