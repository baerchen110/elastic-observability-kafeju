#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-workshopAdmin1!}"

TOOL_FILE="$SCRIPT_DIR/workshop-tools.json"

echo "Creating Agent Builder tools on $KIBANA_URL..."

TOOL_COUNT=$(python3 -c "import json; print(len(json.load(open('$TOOL_FILE'))))")
SUCCESS=0
FAILED=0

for i in $(seq 0 $((TOOL_COUNT - 1))); do
  TOOL=$(python3 -c "import json; print(json.dumps(json.load(open('$TOOL_FILE'))[$i]))")
  TOOL_ID=$(echo "$TOOL" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

  RESP=$(curl -s -X POST "$KIBANA_URL/api/agent_builder/tools" \
    -u "$ES_USER:$ES_PASS" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d "$TOOL" 2>/dev/null)

  if echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'id' in d else 1)" 2>/dev/null; then
    echo "  OK   $TOOL_ID"
    SUCCESS=$((SUCCESS + 1))
  else
    MSG=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','unknown'))" 2>/dev/null || echo "parse error")
    echo "  FAIL $TOOL_ID: $MSG"
    FAILED=$((FAILED + 1))
  fi
done

echo "Done: $SUCCESS created, $FAILED failed"
