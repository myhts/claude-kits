#!/usr/bin/env bash
# protect-main.sh: protect the default branch with a GitHub ruleset, so nothing reaches it without a pull request and
# the required checks. /setup-project runs it after the human's OK; running it again only adds.
#   protect-main.sh [--dry-run] [--strict] <check>...
#   <check>    a check every PR must pass: human-review, plus the CI jobs that run on pull requests
#   --dry-run  print what it would send to GitHub, and change nothing
#   --strict   also require a PR's branch to be up to date with the base before it merges
# The ruleset is named "claude-kits: main" and targets the default branch. It requires:
#   - a pull request, with no approvals: a solo owner can't approve their own PR, and human-review is the gate;
#   - each check, set by GitHub Actions: a status posted any other way (by hand with gh api, say) doesn't count;
#   - no force pushes, and no deleting the branch.
# Nobody bypasses it, admins included. In an emergency a human switches it off in Settings → Rules → Rulesets.
# Running it again merges into the ruleset that's there: new checks are added, and everything already in it stays,
# including anything a human tightened. It never removes a check or loosens a rule; that's done in Settings.
# Rulesets are free on public repositories; a private one needs GitHub Pro, Team or Enterprise.
# Needs gh, logged in as an admin of the repository, and jq. Written for macOS bash 3.2.
set -uo pipefail

NAME="claude-kits: main"
usage() { echo "usage: protect-main.sh [--dry-run] [--strict] <check>..." >&2; exit 64; }
die() { echo "protect-main: $*" >&2; exit 1; }

dry=no strict=false checks=()
for a in "$@"; do
  case "$a" in
    --dry-run) dry=yes ;;
    --strict) strict=true ;;
    -*) usage ;;
    *) checks+=("$a") ;;
  esac
done
[ ${#checks[@]} -gt 0 ] || usage
command -v jq >/dev/null || die "needs jq (brew install jq)"

api() {   # api <gh api arguments...>: prints GitHub's answer, or stops with its error message
  local out
  if out=$(gh api "$@" 2>&1); then printf '%s\n' "$out"; return 0; fi
  case "$out" in
    *"Upgrade to GitHub Pro"*) die "rulesets on a private repository need GitHub Pro, Team or Enterprise. The merge guard still stops Claude merging." ;;
    *) die "gh api $*: $(grep -m1 '^gh: ' <<< "$out" || tail -1 <<< "$out")" ;;
  esac
}

info=$(gh repo view --json nameWithOwner,viewerPermission,defaultBranchRef 2>/dev/null) \
  || die "gh can't read a GitHub repository here (try gh auth status)"
repo=$(jq -r .nameWithOwner <<< "$info")
branch=$(jq -r .defaultBranchRef.name <<< "$info")
[ "$(jq -r .viewerPermission <<< "$info")" = ADMIN ] || die "protecting $branch needs admin rights on $repo"
app=$(api apps/github-actions --jq .id) || exit 1
[[ "$app" =~ ^[0-9]+$ ]] || die "unexpected GitHub Actions app id '$app'"

# Our rules. Each check is pinned to GitHub Actions, which runs the workflows that set them.
ours=$(printf '%s\n' "${checks[@]}" | jq -R . | jq -s --argjson app "$app" --argjson strict "$strict" '
  unique | map({context: ., integration_id: $app}) as $checks | [
  {type: "deletion"},
  {type: "non_fast_forward"},
  {type: "pull_request", parameters: {required_approving_review_count: 0, dismiss_stale_reviews_on_push: false,
    require_code_owner_review: false, require_last_push_approval: false, required_review_thread_resolution: false}},
  {type: "required_status_checks", parameters: {required_status_checks: $checks,
    strict_required_status_checks_policy: $strict}}]')

# --paginate prints one JSON array per page; jq -s joins them.
id=$(api --paginate "repos/$repo/rulesets?includes_parents=false" \
  | jq -rs --arg n "$NAME" '[add[] | select(.name == $n)][0].id // empty') || exit 1

if [ -z "$id" ]; then
  method=POST path="repos/$repo/rulesets"
  body=$(jq -n --arg n "$NAME" --argjson rules "$ours" '{name: $n, target: "branch", enforcement: "active",
    conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}}, bypass_actors: [], rules: $rules}')
else
  # Add whatever of ours is missing. A rule of ours that's already there keeps its settings; for the status checks,
  # new ones join the list and "up to date" stays on once anyone has turned it on.
  method=PUT path="repos/$repo/rulesets/$id"
  current=$(api "$path") || exit 1
  body=$(jq --argjson ours "$ours" '
    def add_checks($o):
      .parameters.required_status_checks as $have
      | .parameters.required_status_checks = $have + [$o.parameters.required_status_checks[]
          | select(.context as $c | all($have[]; .context != $c))]
      | .parameters.strict_required_status_checks_policy |= (. or $o.parameters.strict_required_status_checks_policy);
    {name, target, enforcement, conditions, bypass_actors: (.bypass_actors // []),
     rules: (reduce $ours[] as $o (.rules // [];
       if any(.[]; .type == $o.type) then
         map(if .type == "required_status_checks" and $o.type == .type then add_checks($o) else . end)
       else . + [$o] end))}' <<< "$current")
fi

if [ "$dry" = yes ]; then
  echo "Would send: $method $path"
  jq . <<< "$body"
  exit 0
fi

result=$(api -X "$method" "$path" --input - <<< "$body") || exit 1
jq -r '"Ruleset \"\(.name)\" (\(.enforcement)) on \(.conditions.ref_name.include | join(", ")): \(._links.html.href // "")",
  "Required checks: \([.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context] | join(", "))"' <<< "$result"
[ "$(jq -r .enforcement <<< "$result")" = active ] \
  || echo "It's switched off, so it protects nothing: switch it on in Settings → Rules → Rulesets."
if gh api "repos/$repo/branches/$branch/protection" >/dev/null 2>&1; then
  echo "$branch also has a classic branch protection rule. Both apply, and the stricter setting wins. Once the ruleset looks right, you can delete the classic rule in Settings → Branches."
fi
