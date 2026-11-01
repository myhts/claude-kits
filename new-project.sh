#!/usr/bin/env bash
# Creates a new Spring Boot 4 learning project in this folder and installs the learning kit into it.
#   ./new-project.sh <name> [--e2e] [--ai] [--web] [--java 21] [--boot 4.1.1] [--group com.example] [--deps "web,validation,..."]
#   --e2e adds end-to-end tests (Playwright + Testcontainers), the e2e-tester agent, the Playwright MCP and a Dockerfile.
#   --ai adds the LLM layer (llm-engineering skill, CLAUDE.ai.md, the e2e model fake); --web a React + Vite front end.
#   --pipeline enables the plugins (pipeline@kits, spring@kits and the add-ons) for the project instead of copying the
#         agents and skills; then run /pipeline:setup-project in Claude Code. See PIPELINE.md.
# Uses start.spring.io (needs internet). Never overwrites an existing folder.
set -euo pipefail
cd "$(dirname "$0")"
KIT="$PWD/spring-boot-learning/install.sh"   # the kit lives in this repo
NAME="" JAVA=21 BOOT=4.1.1 GROUP=com.example E2E="" AI="" WEB="" PIPELINE=""
DEPS="web,validation,data-jpa,postgresql,flyway,actuator,testcontainers"
while [ $# -gt 0 ]; do
  case "$1" in
    --java) JAVA="$2"; shift 2 ;;
    --boot) BOOT="$2"; shift 2 ;;
    --group) GROUP="$2"; shift 2 ;;
    --deps) DEPS="$2"; shift 2 ;;
    --e2e) E2E=--e2e; shift ;;
    --ai) AI=--ai; shift ;;
    --web) WEB=--web; shift ;;
    --pipeline) PIPELINE=--plugins; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) NAME="$1"; shift ;;
  esac
done
[ -n "$NAME" ] || { echo "usage: $0 <name> [--e2e] [--ai] [--web] [--pipeline] [--java 21] [--boot 4.1.1] [--group com.example] [--deps list]" >&2; exit 2; }
[[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "name: lowercase letters, digits and dashes, starting with a letter" >&2; exit 2; }
[ ! -e "$NAME" ] || { echo "$NAME already exists here: pick another name" >&2; exit 2; }
[ -x "$KIT" ] || { echo "learning kit not found at $KIT" >&2; exit 2; }

PKG="$GROUP.$(echo "$NAME" | tr -d '-')"
echo "Creating $NAME (Spring Boot $BOOT, Java $JAVA, package $PKG)"
mkdir "$NAME"
if ! curl -fsS https://start.spring.io/starter.tgz \
    -d type=maven-project -d language=java -d bootVersion="$BOOT" -d javaVersion="$JAVA" \
    -d groupId="$GROUP" -d artifactId="$NAME" -d name="$NAME" -d packageName="$PKG" \
    -d dependencies="$DEPS" | tar -xzf - -C "$NAME"; then
  rmdir "$NAME" 2>/dev/null || rm -rf "$NAME"
  echo "start.spring.io refused the request (check --boot / --deps), nothing created" >&2; exit 1
fi
"$KIT" "$NAME" ${E2E:+"$E2E"} ${AI:+"$AI"} ${WEB:+"$WEB"} ${PIPELINE:+"$PIPELINE"} | grep -E "^Added" | sed -E "s/Added \(([0-9]+)\):/Learning kit installed: \1 files/"
if [ -n "$PIPELINE" ]; then
  plugins="pipeline spring${E2E:+ e2e}${AI:+ spring-ai}${WEB:+ spring-web}"
  if command -v claude >/dev/null 2>&1; then
    # project scope: the choice is recorded in the project's .claude/settings.json for every collaborator
    (cd "$NAME" && claude plugin marketplace add "$PWD/.." --scope project >/dev/null \
      && for p in $plugins; do claude plugin install "$p@kits" --scope project >/dev/null || exit 1; done) \
      && echo "Plugins enabled for $NAME: $plugins" \
      || echo "Could not enable the plugins; in $NAME run: claude plugin marketplace add $PWD --scope project, then claude plugin install <name>@kits --scope project for: $plugins" >&2
  else
    echo "claude not found: in $NAME run  claude plugin marketplace add $PWD --scope project  then install: $plugins" >&2
  fi
fi
cat <<NEXT

Next:
  cd "$PWD/$NAME"
  1. Open CLAUDE.md and fill in "This project" (what it is, architecture, what you want to learn).
  2. claude          then:  /learning-loop   (with --pipeline: /pipeline:setup-project, then see PIPELINE.md)
  3. git init        when you want version control (commit .claude/, CLAUDE.md, docs/learning/ too)
NEXT
if [ -n "$E2E" ]; then
cat <<NEXT
  4. End-to-end tests (Docker + Node 22):
       cd "$PWD/$NAME/e2e" && npm install && npx playwright install chromium
       npm run stack:build && npx playwright test        # the app + Postgres in Testcontainers, then the tests
NEXT
fi
