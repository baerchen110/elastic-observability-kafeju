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
  fail-message "Expected at least 2 participant tools for the wow moment. Found $TOOL_COUNT."
  exit 1
fi

AGENT_CHECK=$(curl -s -u "$ES_USER:$ES_PASS" "$KIBANA_URL/api/agent_builder/agents" \
  -H "kbn-xsrf: true" | python3 -c "
import sys, json
agents = json.load(sys.stdin)['results']
kafeju = next((a for a in agents if a['id'] == 'kafuju'), None)
if not kafeju:
    print('no_agent')
else:
    tools = kafeju.get('configuration',{}).get('tools',[{}])[0].get('tool_ids',[])
    participant_wired = [t for t in tools if 'participant' in t]
    print(f'{len(participant_wired)}')
" 2>/dev/null || echo "0")

if [ "$AGENT_CHECK" -lt 2 ]; then
  fail-message "At least 2 participant tools should be wired into the Kafeju agent for multi-tool chaining. Found $AGENT_CHECK."
  exit 1
fi

exit 0
