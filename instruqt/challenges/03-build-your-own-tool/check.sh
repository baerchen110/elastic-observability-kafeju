#!/usr/bin/env bash
set -euo pipefail

ES_USER="elastic"
ES_PASS="workshopAdmin1!"
KIBANA_URL="http://localhost:5601"

TOOL_EXISTS=$(curl -s -u "$ES_USER:$ES_PASS" "$KIBANA_URL/api/agent_builder/tools" \
  -H "kbn-xsrf: true" | python3 -c "
import sys, json
tools = json.load(sys.stdin)
participant = [t for t in tools if 'participant' in t.get('id','')]
print('yes' if participant else 'no')
" 2>/dev/null || echo "no")

if [ "$TOOL_EXISTS" != "yes" ]; then
  fail-message "No participant tool found. Create a tool with 'participant' in its ID using Agent Builder > Tools (Step 3)."
  exit 1
fi

AGENT_HAS_TOOL=$(curl -s -u "$ES_USER:$ES_PASS" "$KIBANA_URL/api/agent_builder/agents" \
  -H "kbn-xsrf: true" | python3 -c "
import sys, json
agents = json.load(sys.stdin)['results']
kafeju = next((a for a in agents if a['id'] in ('kafeju', 'kafuju')), None)
if not kafeju:
    print('no')
else:
    tools = kafeju.get('configuration',{}).get('tools',[{}])[0].get('tool_ids',[])
    has_participant = any('participant' in t for t in tools)
    print('yes' if has_participant else 'no')
" 2>/dev/null || echo "no")

if [ "$AGENT_HAS_TOOL" != "yes" ]; then
  fail-message "Your tool exists but is not wired into the Kafeju agent. Attach it on the Kafeju agent's Tools tab (Step 4)."
  exit 1
fi

exit 0
