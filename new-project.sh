#!/usr/bin/env bash
# Creates a new Spring Boot 4 learning project in this folder and installs the learning kit into it.
#   ./new-project.sh <name> [--e2e] [--java 21] [--boot 4.1.1] [--group com.example] [--deps "web,validation,..."]
#   --e2e adds end-to-end tests (Playwright + Testcontainers), the e2e-tester agent, the Playwright MCP and a Dockerfile.
# Uses start.spring.io (needs internet). Never overwrites an existing folder.
set -euo pipefail
cd "$(dirname "$0")"
KIT="$PWD/spring-boot-learning/install.sh"   # the kit lives in this repo
NAME="" JAVA=21 BOOT=4.1.1 GROUP=com.example E2E=""
DEPS="web,validation,data-jpa,postgresql,flyway,actuator,testcontainers"
while [ $# -gt 0 ]; do
  case "$1" in
    --java) JAVA="$2"; shift 2 ;;
    --boot) BOOT="$2"; shift 2 ;;
    --group) GROUP="$2"; shift 2 ;;
    --deps) DEPS="$2"; shift 2 ;;
    --e2e) E2E=--e2e; shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) NAME="$1"; shift ;;
  esac
done
[ -n "$NAME" ] || { echo "usage: $0 <name> [--e2e] [--java 21] [--boot 4.1.1] [--group com.example] [--deps list]" >&2; exit 2; }
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
"$KIT" "$NAME" ${E2E:+"$E2E"} | grep -E "^Added" | sed -E "s/Added \(([0-9]+)\):/Learning kit installed: \1 files/"
cat <<NEXT

Next:
  cd "$PWD/$NAME"
  1. Open CLAUDE.md and fill in "This project" (what it is, architecture, what you want to learn).
  2. claude          then:  /learning-loop
  3. git init        when you want version control (commit .claude/, CLAUDE.md, docs/learning/ too)
NEXT
if [ -n "$E2E" ]; then
cat <<NEXT
  4. End-to-end tests (Docker + Node 22):
       cd "$PWD/$NAME/e2e" && npm install && npx playwright install chromium
       npm run stack:build && npx playwright test        # the app + Postgres in Testcontainers, then the tests
NEXT
fi
