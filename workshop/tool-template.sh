#!/usr/bin/env bash
#
# Tool Registration Template
# Fill in the placeholders and run this to register your custom tool.
#
# Usage:
#   1. Edit the variables below
#   2. Run: bash tool-template.sh
#

KIBANA_URL="http://localhost:5601"
ES_USER="elastic"
ES_PASS="workshopAdmin1!"

# ═══════════════════════════════════════════════════════════════════════
# FILL THESE IN:
# ═══════════════════════════════════════════════════════════════════════

TOOL_ID="participant.my_tool_name"
# Must be unique. Convention: participant.<descriptive_name>

TOOL_DESCRIPTION="Describe what this tool does and WHEN the AI should use it. Be specific about the keywords or questions that should trigger it."
# Good: "Finds zombie VMs with <15% CPU usage wasting money. Use for zombie, idle, wasted resources."
# Bad:  "Analyzes VMs"

TOOL_QUERY='FROM gcp-resource-executions-*
| WHERE resource_usage.cpu.avg_percent < 15
| STATS
    avg_cpu = AVG(resource_usage.cpu.avg_percent),
    total_cost = SUM(cost_actual.total_cost_usd),
    count = COUNT(*)
  BY metadata.team
| SORT total_cost DESC
| LIMIT 10'
# Write your ES|QL query here. Test it in Discover first!

# ═══════════════════════════════════════════════════════════════════════
# DO NOT EDIT BELOW THIS LINE
# ═══════════════════════════════════════════════════════════════════════

ESCAPED_QUERY=$(echo "$TOOL_QUERY" | python3 -c "
import sys, json
query = sys.stdin.read().strip()
print(json.dumps(query)[1:-1])
")

echo "Creating tool: $TOOL_ID"
echo ""

RESPONSE=$(curl -s -X POST "$KIBANA_URL/api/agent_builder/tools" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json
print(json.dumps({
    'id': '$TOOL_ID',
    'description': '''$TOOL_DESCRIPTION''',
    'tags': ['participant'],
    'configuration': {
        'query': '''$TOOL_QUERY''',
        'params': {}
    }
}))
")")

echo "$RESPONSE" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    if r.get('id'):
        print(f'SUCCESS: Tool {r[\"id\"]} created')
    else:
        print(f'ERROR: {r.get(\"message\", r)}')
except:
    print('ERROR: Could not parse response')
" 2>/dev/null

echo ""
echo "Next step: wire it into the Kafeju agent with:"
echo ""
echo "  curl -s -u $ES_USER:$ES_PASS \\"
echo "    $KIBANA_URL/api/agent_builder/agents \\"
echo "    -H 'kbn-xsrf: true' | python3 -c \""
echo "import json, sys"
echo "agents = json.load(sys.stdin)['results']"
echo "kafeju = next(a for a in agents if a['id'] == 'kafuju')"
echo "tools = kafeju['configuration']['tools'][0]['tool_ids']"
echo "if '$TOOL_ID' not in tools:"
echo "    tools.append('$TOOL_ID')"
echo "kafeju.pop('readonly', None)"
echo "kafeju.pop('type', None)"
echo "print(json.dumps(kafeju))"
echo "\" > /tmp/agent-update.json"
echo ""
echo "  curl -s -X PUT $KIBANA_URL/api/agent_builder/agents/kafuju \\"
echo "    -u $ES_USER:$ES_PASS \\"
echo "    -H 'kbn-xsrf: true' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d @/tmp/agent-update.json"
