#!/usr/bin/env bash
# Merge guard: only the human merges, pushes to main or master, throws work or data away, skips the git hooks, or
# changes branch protection.
# A PreToolUse hook on Bash. Exit 2 blocks the command and shows the reason to Claude; exit 0 lets it run.
# Pushing a feature branch and opening a PR stay allowed: that is how work reaches the human. So does reading
# protection, and /setup-project's protect-main.sh, which only ever adds to it.
# It reads shell commands only. A file emptied with an editing tool, or a delete inside a script, is not seen here:
# the reviewers and the human's review cover those.
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
short_recursive='^-[a-zA-Z]*[rR]'
short_volumes='^-[a-zA-Z]*v'
short_message='^-[a-zA-Z]*[mF]'
commit_no_verify='^-[aepsvqzio]*n'   # -n reached only through flags that take no value, so -uno is not -n
before_command='^(sudo|command|exec|time|nohup|then|do|else|[A-Za-z_][A-Za-z0-9_]*=.*)$'
db_client='(^|[^a-z0-9_.-])(psql|mysql|mariadb|sqlite3|sqlcmd)([[:space:]]|$)'
sql_drop='drop[[:space:]]+(table|database|schema)'
sql_truncate='truncate[[:space:]]+(table[[:space:]]+)?[a-z_"]'
dropdb='(^|[^a-z0-9_.-])dropdb([[:space:]]|$)'
redis_flush='redis-cli.*flush(all|db)'

current_branch() { git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null; }

check_push() {   # arguments: the words after "push"
  local args=() w dst
  for w in "$@"; do
    case "$w" in
      --force|--force-with-lease*|--force-if-includes|--mirror|--delete|--prune) block "a push with $w" ;;
      --no-verify) block "a push that skips the git hooks (--no-verify)" ;;
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

check_no_verify() {   # arguments: a git subcommand, then its words. Skipping the hooks is the human's call.
  local sub=$1 w; shift
  for w in "$@"; do
    case "$w" in
      --no-verify) block "git $sub that skips the git hooks (--no-verify)" ;;
      -m|-F|--message|--message=*|--file|--file=*) return 0 ;;   # what follows is the message, not flags
      --*) ;;
      -*)
        # In "git commit", -n is --no-verify.
        [ "$sub" = commit ] && [[ "$w" =~ $commit_no_verify ]] && block "git commit that skips the git hooks ($w)"
        [[ "$w" =~ $short_message ]] && return 0 ;;
    esac
  done
  return 0
}

check_rm() {   # arguments: the words after "rm", with quotes removed
  local w t recursive=no
  for w in "$@"; do
    case "$w" in
      --recursive) recursive=yes ;;
      --*) ;;
      -*) [[ "$w" =~ $short_recursive ]] && recursive=yes ;;
    esac
  done
  for w in "$@"; do
    case "$w" in
      -*) continue ;;
      .github/workflows/*|./.github/workflows/*) block "deleting a CI workflow ($w)" ;;
    esac
    [ "$recursive" = yes ] || continue
    t=${w%/}
    case "$w" in
      '/'|'/*'|'~'|'~/'|'~/*'|'$HOME'|'$HOME/'|'$HOME/*'|'${HOME}'|'${HOME}/'|'${HOME}/*'|'.'|'./'|'./*'|'..'|'../'|'../*'|'*')
        block "deleting a whole folder tree (rm -r $w)" ;;
      .git|.git/*|./.git|./.git/*|.github|.github/*|./.github|./.github/*)
        block "deleting the repository's history or its checks (rm -r $w)" ;;
    esac
    { [ "$t" = "${HOME:-/nonexistent}" ] || [ "$t" = "${CLAUDE_PROJECT_DIR:-/nonexistent}" ]; } \
      && block "deleting a whole folder tree (rm -r $w)"
  done
  return 0
}

check_docker() {   # arguments: the words after "docker" or "docker-compose"
  local r=" $* " w after_down=no
  case "$r" in
    *" volume rm "*|*" volume remove "*|*" volume prune "*) block "deleting a Docker volume" ;;
    *" system prune "*) block "docker system prune, which also deletes what other projects left" ;;
  esac
  for w in "$@"; do
    if [ "$after_down" = yes ]; then
      { [ "$w" = --volumes ] || [[ "$w" =~ $short_volumes ]]; } && block "docker compose down with volumes ($w), which deletes their data"
    fi
    [ "$w" = down ] && after_down=yes
  done
  return 0
}

check_segment() {   # one simple command, already split into words
  local words=("$@") n=$# i j sub w
  for ((i = 0; i < n; i++)); do
    case "${words[$i]}" in
      gh)
        [ "${words[$((i + 1))]:-}" = pr ] && [ "${words[$((i + 2))]:-}" = merge ] && block "merging a pull request"
        [ "${words[$((i + 1))]:-}" = api ] && check_api "${words[@]:$((i + 2))}"
        ;;
      docker|docker-compose)
        check_docker "${words[@]:$((i + 1))}"
        ;;
      git)
        j=$((i + 1))
        while [ "${words[$j]:-}" = -C ] || [ "${words[$j]:-}" = -c ]; do
          if [ "${words[$j]}" = -c ]; then
            w=$(printf '%s' "${words[$((j + 1))]:-}" | tr '[:upper:]' '[:lower:]')
            [[ "$w" == core.hookspath=* ]] && block "turning the git hooks off (-c core.hooksPath)"
          fi
          j=$((j + 2))
        done
        sub="${words[$j]:-}"
        local rest=("${words[@]:$((j + 1))}")
        [ -n "$sub" ] && check_no_verify "$sub" ${rest[@]+"${rest[@]}"}
        case "$sub" in
          push) check_push ${rest[@]+"${rest[@]}"} ;;
          rm)
            for w in ${rest[@]+"${rest[@]}"}; do
              case "$w" in .github/workflows|.github/workflows/*|./.github/workflows|./.github/workflows/*) block "deleting a CI workflow ($w)" ;; esac
            done ;;
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

# Database clients: checked on the whole command, so a statement piped in or given in a here-document is seen too.
lower=$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')
if [[ "$lower" =~ $db_client ]]; then
  [[ "$lower" =~ $sql_drop ]] && block "dropping a table, schema or database"
  [[ "$lower" =~ $sql_truncate ]] && block "emptying a table (TRUNCATE)"
fi
[[ "$lower" =~ $dropdb ]] && block "dropping a database (dropdb)"
[[ "$lower" =~ $redis_flush ]] && block "emptying Redis (FLUSHALL or FLUSHDB)"

set -f   # words like * must not expand while we inspect them
while IFS= read -r seg; do
  [[ "$seg" =~ pulls/[0-9]+/merge ]] && block "merging a pull request through the API"
  [[ "$seg" =~ mutation.*(RepositoryRuleset|BranchProtectionRule) ]] && block "changing branch protection or a ruleset through GraphQL"
  # rm is read from a copy with the quotes deleted, so "$dir"/* stays one word, and only where a command starts,
  # so the words of a commit message are not mistaken for it.
  raw=${seg//\"/}; raw=${raw//\'/}; raw=${raw//(/ }; raw=${raw//)/ }
  read -ra rparts <<< "$raw"
  k=0
  while [[ "${rparts[$k]:-}" =~ $before_command ]]; do k=$((k + 1)); done
  [ "${rparts[$k]:-}" = rm ] && check_rm "${rparts[@]:$((k + 1))}"
  seg=${seg//\"/ }; seg=${seg//\'/ }; seg=${seg//(/ }; seg=${seg//)/ }
  read -ra parts <<< "$seg"
  [ "${#parts[@]}" -gt 0 ] && check_segment "${parts[@]}"
done < <(printf '%s\n' "$cmd" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }')

exit 0
