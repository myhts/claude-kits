#!/usr/bin/env bash
# One-time setup after cloning: checks the tools, then makes the personal skills in skills/ available to Claude Code in
# every project by linking them into ~/.claude/skills/ (so a `git pull` here updates them).
#   ./setup.sh            check, then link
#   ./setup.sh --check    only check the tools
#   ./setup.sh --force    replace an existing ~/.claude/skills/<name> folder (moved to ~/.claude/skills-replaced/)
set -euo pipefail
cd "$(dirname "$0")"
REPO="$PWD" CHECK_ONLY=0 FORCE=0
for a in "$@"; do
  case "$a" in
    --check) CHECK_ONLY=1 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

ok=1
need() {   # need <command> <why> [version command] [minimum major]
  local cmd="$1" why="$2" vcmd="${3:-}" min="${4:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then echo "  ✗ $cmd: missing ($why)"; ok=0; return; fi
  if [ -n "$vcmd" ]; then
    local v; v="$($vcmd 2>&1 | grep -oE '[0-9]+(\.[0-9]+)*' | head -1)"
    if [ -n "$min" ] && [ "${v%%.*}" -lt "$min" ] 2>/dev/null; then echo "  ✗ $cmd $v: need $min+ ($why)"; ok=0; return; fi
    echo "  ✓ $cmd $v"
  else
    echo "  ✓ $cmd"
  fi
}
echo "Tools:"
need git    "version control"
need claude "Claude Code: https://claude.com/claude-code" "claude --version"
need java   "Java 21+ for the Spring Boot projects" "java -version" 21
need docker "Testcontainers and the e2e stack"
need node   "Node 22+ for the e2e tests and the explorer tools" "node --version" 22
need curl   "new-project.sh downloads from start.spring.io"
if command -v docker >/dev/null 2>&1 && ! docker info >/dev/null 2>&1; then echo "  ! docker is installed but not running"; fi
[ "$ok" -eq 1 ] || echo "Install what's missing, then run ./setup.sh again (linking still works without it)."
[ "$CHECK_ONLY" -eq 1 ] && exit 0

echo "Personal skills (available in every project):"
mkdir -p "$HOME/.claude/skills"
for skill in "$REPO"/skills/*/; do
  name="$(basename "$skill")" target="$HOME/.claude/skills/$(basename "$skill")"
  if [ -L "$target" ]; then
    ln -sfn "$REPO/skills/$name" "$target"; echo "  ✓ $name (link updated)"
  elif [ -e "$target" ]; then
    if [ "$FORCE" -eq 1 ]; then
      aside="$HOME/.claude/skills-replaced/$name.$(date +%Y%m%d%H%M%S)"   # outside skills/, or it would load twice
      mkdir -p "$(dirname "$aside")" && mv "$target" "$aside"
      ln -s "$REPO/skills/$name" "$target"; echo "  ✓ $name (old folder moved to $aside)"
    else
      echo "  ! $name: $target already exists and isn't a link; left alone (use --force to move it aside)"
    fi
  else
    ln -s "$REPO/skills/$name" "$target"; echo "  ✓ $name"
  fi
done

cat <<EOF

Done. Next:
  ./new-project.sh my-app --e2e        # a new Spring Boot project with the kit (see README.md)
  cd my-app && claude                  # then /learning-loop
  /project-explorer                    # in any repository, any language
Full guide: GUIDE.md
EOF
