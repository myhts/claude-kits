#!/usr/bin/env bash
# Installs the Spring Boot learning kit into a project:
#   .claude/agents/*, .claude/skills/*, CLAUDE.md, docs/learning/{LESSONS,PROGRESS}.md
#   --e2e also adds end-to-end testing: e2e/ (Playwright + Testcontainers), the e2e-testing skill, the e2e-tester
#         agent, .mcp.json (Playwright MCP, localhost only), and a Dockerfile from build-templates if there is none.
#   --ai  adds the LLM layer: the llm-engineering skill (method, evals, synthetic data, review checklist, CI eval
#         job) and CLAUDE.ai.md (rules to merge into CLAUDE.md); with --e2e also e2e/llm-fake (canned model answers).
#   --web adds a React + Vite front end template in web/ and the react-frontend skill.
#   --plugins copies only the project files (CLAUDE.md, docs/learning/, e2e/, web/, Dockerfile) and leaves out the
#         agents, skills and MCP config: the project gets those from the plugins (pipeline@kits and its pack).
# The agents and the stack-neutral core skills live in kit-pipeline/; the Spring skills in kit/.
# Usage: ./install.sh <project-dir> [--e2e] [--ai] [--web] [--plugins] [--dry-run] [--force]
#   Existing files are never overwritten unless --force. An existing CLAUDE.md or .mcp.json is left alone; the kit's
#   version is written next to it (CLAUDE.learning.md, .mcp.e2e.json) for you to merge. Settings are never touched.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT="$HERE/kit" KIT_E2E="$HERE/kit-e2e" KIT_AI="$HERE/kit-ai" KIT_WEB="$HERE/kit-web" KIT_PIPELINE="$HERE/kit-pipeline"
CORE_SKILLS="system-design distributed-systems design-patterns resilience-patterns interview-drill learning-loop project-explorer"
TARGET="" DRY=0 FORCE=0 E2E=0 AI=0 WEB=0 PLUGINS=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --force) FORCE=1 ;;
    --e2e) E2E=1 ;;
    --ai) AI=1 ;;
    --web) WEB=1 ;;
    --plugins) PLUGINS=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) TARGET="$a" ;;
  esac
done
[ -n "$TARGET" ] || { echo "usage: $0 <project-dir> [--e2e] [--ai] [--web] [--plugins] [--dry-run] [--force]" >&2; exit 2; }
[ -d "$TARGET" ] || { echo "not a directory: $TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"
[ "$TARGET" != "$HOME" ] || { echo "refusing to install into your home directory: pick a project folder" >&2; exit 2; }

# The app's name: the project's own artifactId (after the <parent> block), else the folder name.
APP=""
if [ -f "$TARGET/pom.xml" ]; then
  APP="$(perl -0777 -ne 's/<parent>.*?<\/parent>//s; print $1 if /<artifactId>\s*([^<\s]+)\s*</' "$TARGET/pom.xml" || true)"
fi
APP="${APP:-$(basename "$TARGET")}"
[[ "$APP" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || { echo "app name \"$APP\" isn't a valid image name: rename the artifactId or folder" >&2; exit 2; }

added=() skipped=() side=()
copy() {   # copy <src> <dest> [substitute]: substitute replaces __APP__ / <APP> with the app's name
  local src="$1" dest="$2" sub="${3:-0}"
  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then skipped+=("${dest#$TARGET/}"); return; fi
  added+=("${dest#$TARGET/}")
  [ "$DRY" -eq 1 ] && return
  mkdir -p "$(dirname "$dest")"
  /bin/cp -f "$src" "$dest"
  [ "$sub" -eq 1 ] && APP="$APP" perl -pi -e 's/__APP__|<APP>/$ENV{APP}/g' "$dest"
  return 0
}
side_copy() {   # copy <src> <dest> <side-name>: if dest exists with other content, write the side file instead
  local src="$1" dest="$2" sidename="$3"
  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ] && ! cmp -s "$src" "$dest"; then
    side+=("$sidename")
    copy "$src" "$(dirname "$dest")/$sidename"
  else
    copy "$src" "$dest"
  fi
}

plugin_supplied() {   # true for files a plugin provides, which --plugins leaves out
  [ "$PLUGINS" -eq 1 ] || return 1
  case "$1" in .claude/skills/*|.claude/agents/*|agents/*|.mcp.json) return 0 ;; esac
  return 1
}

while IFS= read -r -d '' f; do
  rel="${f#$KIT/}"
  plugin_supplied "$rel" && continue
  if [ "$rel" = "CLAUDE.md" ]; then side_copy "$f" "$TARGET/CLAUDE.md" CLAUDE.learning.md; continue; fi
  copy "$f" "$TARGET/$rel"
done < <(find "$KIT" -type f ! -name '.DS_Store' -print0 | sort -z)

# Copy installs also get the stack-neutral agents and core skills, which live in kit-pipeline/.
if [ "$PLUGINS" -eq 0 ]; then
  for f in "$KIT_PIPELINE"/agents/*.md; do copy "$f" "$TARGET/.claude/agents/$(basename "$f")"; done
  for s in $CORE_SKILLS; do
    while IFS= read -r -d '' f; do
      copy "$f" "$TARGET/.claude/skills/${f#$KIT_PIPELINE/skills/}"
    done < <(find "$KIT_PIPELINE/skills/$s" -type f ! -name '.DS_Store' -print0 | sort -z)
  done
fi

if [ "$E2E" -eq 1 ]; then
  while IFS= read -r -d '' f; do
    rel="${f#$KIT_E2E/}"
    plugin_supplied "$rel" && continue
    if [ "$rel" = ".mcp.json" ]; then side_copy "$f" "$TARGET/.mcp.json" .mcp.e2e.json; continue; fi
    case "$rel" in agents/*) rel=".claude/$rel" ;; esac   # the e2e plugin's agents/ folder → .claude/agents/
    copy "$f" "$TARGET/$rel" 1
  done < <(find "$KIT_E2E" -type f ! -name '.DS_Store' ! -path '*/node_modules/*' -print0 | sort -z)
  # The e2e stack runs the app's image, so it needs a Dockerfile: the verified one from build-templates.
  T="$KIT/.claude/skills/build-templates"
  [ -e "$TARGET/Dockerfile" ] || copy "$T/Dockerfile" "$TARGET/Dockerfile" 1
  [ -e "$TARGET/.dockerignore" ] || copy "$T/.dockerignore" "$TARGET/.dockerignore"
fi

if [ "$AI" -eq 1 ]; then
  while IFS= read -r -d '' f; do
    rel="${f#$KIT_AI/}"
    plugin_supplied "$rel" && continue
    case "$rel" in
      CLAUDE.ai.md) copy "$f" "$TARGET/CLAUDE.ai.md"; side+=(CLAUDE.ai.md) ;;   # always a side file: rules to merge
      e2e/*) if [ "$E2E" -eq 1 ] || [ -d "$TARGET/e2e" ]; then copy "$f" "$TARGET/$rel"; fi ;;
      *) copy "$f" "$TARGET/$rel" ;;
    esac
  done < <(find "$KIT_AI" -type f ! -name '.DS_Store' -print0 | sort -z)
fi

if [ "$WEB" -eq 1 ]; then
  while IFS= read -r -d '' f; do
    plugin_supplied "${f#$KIT_WEB/}" && continue
    copy "$f" "$TARGET/${f#$KIT_WEB/}" 1
  done < <(find "$KIT_WEB" -type f ! -name '.DS_Store' ! -path '*/node_modules/*' ! -path '*/dist/*' -print0 | sort -z)
fi

[ "$DRY" -eq 1 ] && echo "DRY RUN: nothing written."
echo "Target: $TARGET (app: $APP)"
echo "Added (${#added[@]}):";   for x in "${added[@]+"${added[@]}"}"; do echo "  + $x"; done
if [ ${#skipped[@]} -gt 0 ]; then
  echo "Skipped, already there (${#skipped[@]}; use --force to overwrite):"; for x in "${skipped[@]}"; do echo "  = $x"; done
fi
for s in "${side[@]+"${side[@]}"}"; do
  echo
  case "$s" in
    CLAUDE.learning.md) echo "Your project already has a CLAUDE.md, so the kit's rules went to CLAUDE.learning.md."
      echo "Merge the parts you want into CLAUDE.md (or ask Claude: \"merge CLAUDE.learning.md into CLAUDE.md\"), then delete it." ;;
    .mcp.e2e.json) echo "Your project already has a .mcp.json, so the Playwright MCP entry went to .mcp.e2e.json."
      echo "Copy its \"playwright\" server into .mcp.json, then delete .mcp.e2e.json." ;;
    CLAUDE.ai.md) echo "The rules for working with the model are in CLAUDE.ai.md: merge them into CLAUDE.md, then delete it." ;;
  esac
done
cat <<'EOF'

Next:
  1. Fill in the "This project" section at the end of CLAUDE.md.
  2. Start Claude Code in the project and run /learning-loop.
  3. Commit .claude/ , CLAUDE.md and docs/learning/ if you want them versioned with the project.
EOF
if [ "$E2E" -eq 1 ]; then
cat <<'EOF'
  4. End-to-end tests (Docker + Node 22 needed):
       cd e2e && npm install && npx playwright install chromium && npm run stack:build && npx playwright test
     Then commit e2e/ (with package-lock.json). Claude Code asks you to approve the playwright MCP server once.
EOF
fi
if [ "$AI" -eq 1 ]; then
cat <<'EOF'
  LLM layer: read .claude/skills/llm-engineering/SKILL.md. The API key goes in the environment (ANTHROPIC_API_KEY),
     never in the repo; set a monthly spend limit on it in the Claude Console. The CI eval job is
     .claude/skills/llm-engineering/ci-evals.yml (copy it to .github/workflows/evals.yml when you have evals).
EOF
fi
if [ "$WEB" -eq 1 ]; then
cat <<'EOF'
  Front end: see web/README.md (npm install, npm run dev with the API on :8080, npm run build).
EOF
fi
