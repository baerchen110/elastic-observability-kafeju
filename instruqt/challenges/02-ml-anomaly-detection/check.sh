#!/usr/bin/env bash
set -euo pipefail

ES_URL="http://localhost:9200"
ES_USER="elastic"
ES_PASS="workshopAdmin1!"
KIBANA_URL="http://localhost:5601"

KIBANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KIBANA_URL/api/status" 2>/dev/null || echo "000")
if [ "$KIBANA_STATUS" != "200" ]; then
  fail-message "Kibana is not responding."
  exit 1
fi

TOOL_CHECK=$(curl -s -u "$ES_USER:$ES_PASS" "$KIBANA_URL/api/agent_builder/tools" \
  -H "kbn-xsrf: true" | python3 -c "
import sys, json
tools = json.load(sys.stdin)
kafeju_tools = [t for t in tools if t.get('id','').startswith('kafeju.')]
print(len(kafeju_tools))
" 2>/dev/null || echo "0")

if [ "$TOOL_CHECK" -lt 10 ]; then
  fail-message "Kafeju tools not found (expected at least 10, found $TOOL_CHECK). Please wait for setup."
  exit 1
fi

exit 0
