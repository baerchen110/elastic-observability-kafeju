#!/usr/bin/env bash
set -euo pipefail

KIBANA_URL="http://localhost:5601"
ES_USER="elastic"
ES_PASS="workshopAdmin1!"

TOOLS=$(curl -s -u "$ES_USER:$ES_PASS" -H "kbn-xsrf: true" \
  "$KIBANA_URL/api/agent_builder/tools" 2>/dev/null)

HAS_PARTICIPANT_TOOL=$(echo "$TOOLS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
results = d.get('results', d) if isinstance(d, dict) else d
found = any(t.get('id','').startswith('participant.') for t in results if isinstance(t, dict))
print('yes' if found else 'no')
" 2>/dev/null || echo "no")

if [ "$HAS_PARTICIPANT_TOOL" != "yes" ]; then
  fail-message "No custom tool found. Create a tool with an ID starting with 'participant.' (e.g., participant.find_zombie_vms). Follow the instructions in Step 3."
  exit 1
fi

echo "Custom participant tool found!"
exit 0
