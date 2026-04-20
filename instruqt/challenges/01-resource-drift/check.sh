#!/usr/bin/env bash
set -euo pipefail

ES_URL="http://localhost:9200"
ES_USER="elastic"
ES_PASS="workshopAdmin1!"
KIBANA_URL="http://localhost:5601"

KIBANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KIBANA_URL/api/status" 2>/dev/null || echo "000")
if [ "$KIBANA_STATUS" != "200" ]; then
  fail-message "Kibana is not responding. Please check that the environment is running."
  exit 1
fi

AGENT_CHECK=$(curl -s -u "$ES_USER:$ES_PASS" "$KIBANA_URL/api/agent_builder/agents" \
  -H "kbn-xsrf: true" | python3 -c "
import sys, json
data = json.load(sys.stdin)
agents = data.get('results', [])
kafeju = [a for a in agents if a.get('id') == 'kafuju']
print('ok' if kafeju else 'missing')
" 2>/dev/null || echo "error")

if [ "$AGENT_CHECK" != "ok" ]; then
  fail-message "The Kafeju agent is not found. Please wait for setup to complete."
  exit 1
fi

exit 0
