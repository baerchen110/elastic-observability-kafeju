#!/usr/bin/env bash
set -euo pipefail

ES_USER="elastic"
ES_PASS="workshopAdmin1!"
KIBANA_URL="http://localhost:5601"

TOOL_COUNT=$(curl -s -u "$ES_USER:$ES_PASS" "$KIBANA_URL/api/agent_builder/tools" \
  -H "kbn-xsrf: true" | python3 -c "
import sys, json
tools = json.load(sys.stdin)
participant = [t for t in tools if 'participant' in t.get('id','')]
print(len(participant))
" 2>/dev/null || echo "0")

if [ "$TOOL_COUNT" -lt 2 ]; then
  fail-message "Found $TOOL_COUNT participant tool(s), but at least 2 are required (zombie detector + your custom tool). Create another tool with 'participant' in the ID."
  exit 1
fi

exit 0
