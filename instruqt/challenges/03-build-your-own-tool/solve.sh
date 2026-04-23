#!/usr/bin/env bash
set -euo pipefail

ES_USER="elastic"
ES_PASS="workshopAdmin1!"
KIBANA_URL="http://localhost:5601"

curl -s -X POST "$KIBANA_URL/api/agent_builder/tools" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "participant.find_zombie_vms",
    "description": "Finds zombie VMs: machines with very low CPU usage (under 15%) that are wasting money. Shows which teams have idle resources ranked by total cost waste. Use when asked about zombie VMs, idle instances, or wasted resources.",
    "tags": ["participant", "infrastructure", "cost"],
    "configuration": {
      "query": "FROM gcp-resource-executions-*\n| WHERE resource_usage.cpu.avg_percent < 15\n  AND vm_info.vm_type_actual IS NOT NULL\n| STATS\n    avg_cpu = AVG(resource_usage.cpu.avg_percent),\n    avg_drift = AVG(drift_metrics.combined_drift_score),\n    total_cost = SUM(cost_actual.total_cost_usd),\n    occurrences = COUNT(*)\n  BY metadata.team, vm_info.vm_type_actual, resource_name\n| SORT total_cost DESC\n| LIMIT 15",
      "params": {}
    }
  }' > /dev/null 2>&1

curl -s -u "$ES_USER:$ES_PASS" "$KIBANA_URL/api/agent_builder/agents" \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys, subprocess
agents = json.load(sys.stdin)['results']
kafeju = next((a for a in agents if a['id'] in ('kafeju', 'kafuju')), None)
if not kafeju:
    raise SystemExit('Kafeju agent not found')
agent_id = kafeju['id']
tools = kafeju['configuration']['tools'][0]['tool_ids']
if 'participant.find_zombie_vms' not in tools:
    tools.append('participant.find_zombie_vms')
kafeju.pop('readonly', None)
kafeju.pop('type', None)
with open('/tmp/agent-update.json', 'w') as f:
    json.dump(kafeju, f)
"

curl -s -X PUT "$KIBANA_URL/api/agent_builder/agents/$(python3 -c "import json; print(json.load(open('/tmp/agent-update.json'))['id'])")" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d @/tmp/agent-update.json > /dev/null 2>&1

echo "Zombie VM detector tool created and wired into Kafeju agent."
