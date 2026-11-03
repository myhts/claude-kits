#!/usr/bin/env bash
# Merge guard: only the human merges, pushes to main or master, throws work away, or changes branch protection.
# A PreToolUse hook on Bash. Exit 2 blocks the command and shows the reason to Claude; exit 0 lets it run.
# Pushing a feature branch and opening a PR stay allowed: that is how work reaches the human. So does reading
# protection, and /setup-project's protect-main.sh, which only ever adds to it.
# Adapted from git-guardrails-claude-code in mattpocock/skills (MIT, see NOTICE.md). Written for macOS bash 3.2.
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

block() {
  echo "Blocked by the merge guard: $1. This step is the human's; tell them what you wanted to run and why." >&2
  exit 2
}

protected='^(main|master)$'
short_force='^-[a-zA-Z]*f'
short_delete='^-[a-zA-Z]*d'
short_branch_force_delete='^-[a-zA-Z]*D'

current_branch() { git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null; }

check_push() {   # arguments: the words after "push"
  local args=() w dst
  for w in "$@"; do
    case "$w" in
      --force|--force-with-lease*|--force-if-includes|--mirror|--delete|--prune) block "a push with $w" ;;
      --*) ;;
      -*) [[ "$w" =~ $short_force ]] && block "a force push ($w)"
          [[ "$w" =~ $short_delete ]] && block "a push that deletes ($w)" ;;
      *) args+=("$w") ;;
    esac
  done
  # args: [remote] [refspec...]. With no refspec, git pushes the current branch.
  if [ "${#args[@]}" -le 1 ]; then
    [[ "$(current_branch)" =~ $protected ]] && block "a push from $(current_branch)"
    return 0
  fi
  for w in "${args[@]:1}"; do
    [[ "$w" == +* ]] && block "a force push (refspec $w)"
    [[ "$w" == :* ]] && block "deleting a remote branch ($w)"
    dst="${w##*:}"; dst="${dst#refs/heads/}"
    [ "$dst" = HEAD ] && dst="$(current_branch)"
    [[ "$dst" =~ $protected ]] && block "a push to $dst"
  done
  return 0
}

check_api() {   # arguments: the words after "gh api". A write to a ruleset or branch protection is blocked.
  local w prev= target=no method= fields=no
  for w in "$@"; do
    case "$w" in *repos/*/rulesets*|*orgs/*/rulesets*|*/branches/*/protection*) target=yes ;; esac
    case "$prev" in -X|--method) method=$w ;; esac
    case "$w" in
      -X?*) method=${w#-X} ;;
      --method=*) method=${w#--method=} ;;
      -f|-F|--field|--raw-field|--input|-f?*|-F?*|--field=*|--raw-field=*|--input=*) fields=yes ;;
    esac
    prev=$w
  done
  [ "$target" = yes ] || return 0
  # gh api sends GET unless told otherwise, and POST when it has fields and no method.
  if [ -n "$method" ]; then [[ "$method" =~ ^(GET|get)$ ]] && return 0
  else [ "$fields" = no ] && return 0; fi
  block "changing branch protection or a ruleset"
}

check_segment() {   # one simple command, already split into words
  local words=("$@") n=$# i j sub w
  for ((i = 0; i < n; i++)); do
    case "${words[$i]}" in
      gh)
        [ "${words[$((i + 1))]:-}" = pr ] && [ "${words[$((i + 2))]:-}" = merge ] && block "merging a pull request"
        [ "${words[$((i + 1))]:-}" = api ] && check_api "${words[@]:$((i + 2))}"
        ;;
      git)
        j=$((i + 1))
        while [ "${words[$j]:-}" = -C ] || [ "${words[$j]:-}" = -c ]; do j=$((j + 2)); done
        sub="${words[$j]:-}"
        local rest=("${words[@]:$((j + 1))}")
        case "$sub" in
          push) check_push ${rest[@]+"${rest[@]}"} ;;
          reset)
            for w in ${rest[@]+"${rest[@]}"}; do [ "$w" = --hard ] && block "git reset --hard"; done ;;
          clean)
            for w in ${rest[@]+"${rest[@]}"}; do
              { [[ "$w" =~ $short_force ]] || [ "$w" = --force ]; } && block "git clean with force"
            done ;;
          branch)
            for w in ${rest[@]+"${rest[@]}"}; do [[ "$w" =~ $short_branch_force_delete ]] && block "force-deleting a branch"; done ;;
          checkout)
            for w in ${rest[@]+"${rest[@]}"}; do [ "$w" = . ] && block "discarding all local changes (git checkout .)"; done ;;
          restore)
            local staged_only=no
            [[ " ${rest[*]-} " == *" --staged "* && " ${rest[*]-} " != *" --worktree "* ]] && staged_only=yes
            for w in ${rest[@]+"${rest[@]}"}; do
              [ "$w" = . ] && [ "$staged_only" = no ] && block "discarding all local changes (git restore .)"
            done ;;
        esac
        ;;
    esac
  done
  return 0
}

set -f   # words like * must not expand while we inspect them
while IFS= read -r seg; do
  [[ "$seg" =~ pulls/[0-9]+/merge ]] && block "merging a pull request through the API"
  [[ "$seg" =~ mutation.*(RepositoryRuleset|BranchProtectionRule) ]] && block "changing branch protection or a ruleset through GraphQL"
  seg=${seg//\"/ }; seg=${seg//\'/ }; seg=${seg//(/ }; seg=${seg//)/ }
  read -ra parts <<< "$seg"
  [ "${#parts[@]}" -gt 0 ] && check_segment "${parts[@]}"
done < <(printf '%s\n' "$cmd" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }')

exit 0
