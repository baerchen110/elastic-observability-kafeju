#!/usr/bin/env bash
#
# Clean up the local workshop environment.
#
# Usage:
#   ./scripts/cleanup-local.sh          # Stop containers, keep data volume
#   ./scripts/cleanup-local.sh --full   # Stop containers, delete volume + .env
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$REPO_ROOT/resources/docker"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

FULL=false
[ "${1:-}" = "--full" ] && FULL=true

if ! docker compose -f "$COMPOSE_FILE" ps --quiet 2>/dev/null | grep -q .; then
  info "No running containers found"
else
  info "Stopping containers..."
  docker compose -f "$COMPOSE_FILE" down 2>&1 | sed 's/^/  /'
  info "Containers stopped"
fi

if [ "$FULL" = true ]; then
  info "Removing data volume..."
  docker volume rm docker_esdata 2>/dev/null && info "Volume docker_esdata removed" || true

  if [ -f "$DOCKER_DIR/.env" ]; then
    rm -f "$DOCKER_DIR/.env"
    info "Removed $DOCKER_DIR/.env"
  fi

  info "Full cleanup complete. Run ./scripts/bootstrap-local.sh to start fresh."
else
  info "Containers stopped. Data volume preserved (restart with docker compose up -d)."
  info "Use --full to also delete the data volume and .env."
fi

LOGDIR="$REPO_ROOT/logs"
if [ -d "$LOGDIR" ]; then
  LOG_COUNT=$(find "$LOGDIR" -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$LOG_COUNT" -gt 0 ]; then
    info "Found $LOG_COUNT log file(s) in logs/. To delete: rm -rf logs/"
  fi
fi
