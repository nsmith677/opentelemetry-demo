#!/usr/bin/env bash
# Follows the aggregated logs of the running OpenTelemetry Demo stack.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

exec sudo docker compose \
  --env-file .env --env-file .env.override \
  -f compose.yaml -f compose.full.yaml -f compose.observability.yaml -f compose.extras.yaml \
  logs -f --tail=50
