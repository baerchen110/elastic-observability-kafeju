#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-workshopAdmin1!}"
AGENT_FILE="$SCRIPT_DIR/kafeju-agent.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (brew install jq / apt-get install -y jq)" >&2
  exit 1
fi

echo "Creating Kafeju agent(s) on $KIBANA_URL..."

# Emit each top-level object as a single compact JSON line so password/value
# special characters can never collide with shell quoting.
jq -c '.[]' "$AGENT_FILE" | while IFS= read -r agent_json; do
  AGENT_ID="$(printf '%s' "$agent_json" | jq -r '.id')"

  HTTP_CODE=$(curl -sS -o /tmp/kafeju-agent-resp.json -w "%{http_code}" \
    -u "$ES_USER:$ES_PASS" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -X POST "$KIBANA_URL/api/agent_builder/agents" \
    -d "$agent_json")

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "  OK   agent '$AGENT_ID' (HTTP $HTTP_CODE)"
  else
    echo "  FAIL agent '$AGENT_ID' (HTTP $HTTP_CODE)" >&2
    cat /tmp/kafeju-agent-resp.json >&2 || true
    echo >&2
    exit 1
  fi
done

echo "Kafeju agent(s) created."
