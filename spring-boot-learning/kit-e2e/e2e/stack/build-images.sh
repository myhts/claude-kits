#!/usr/bin/env bash
# Builds the images the e2e stack runs (the app, and web/ if it has a Dockerfile), from the current working tree, tagged :e2e (never :latest).
#   npm run stack:build
set -euo pipefail
cd "$(dirname "$0")/../.."
[ -f Dockerfile ] || { echo "no Dockerfile in $(pwd): ask \"use the implementer to add the Dockerfile from build-templates\"" >&2; exit 1; }
DOCKER_BUILDKIT=1 docker build -q -t __APP__:e2e .
echo "built __APP__:e2e"
# The front end, when there is one (the kit's web/ template, or your own with a Dockerfile in web/)
if [ -f web/Dockerfile ]; then
  DOCKER_BUILDKIT=1 docker build -q -t __APP__-web:e2e web
  echo "built __APP__-web:e2e"
fi
