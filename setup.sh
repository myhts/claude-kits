#!/usr/bin/env bash
# One-time setup after cloning: checks the tools. /project-explorer used to be linked into ~/.claude/skills/ from here;
# it now comes with the pipeline plugin and with copy installs of the learning kit, so the old link is removed.
#   ./setup.sh            check, then remove the old link
#   ./setup.sh --check    only check the tools
set -euo pipefail
cd "$(dirname "$0")"
REPO="$PWD" CHECK_ONLY=0
for a in "$@"; do
  case "$a" in
    --check) CHECK_ONLY=1 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
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

# Only a link this script made, pointing at the folder that moved; anything else is left alone.
old="$HOME/.claude/skills/project-explorer"
if [ -L "$old" ] && [ "$(readlink "$old")" = "$REPO/skills/project-explorer" ]; then
  rm "$old"; echo "Removed $old: /project-explorer now comes with the pipeline plugin."
fi

cat <<EOF

Done. Next:
  ./new-project.sh my-app --e2e        # a new Spring Boot project with the kit (see README.md)
  cd my-app && claude                  # then /learning-loop
  /pipeline:project-explorer           # in any repository with the pipeline plugin, any language
Full guide: GUIDE.md
EOF
