#!/usr/bin/env bash
set -euo pipefail

KIBANA_URL="http://localhost:5601"
ES_USER="elastic"
ES_PASS="workshopAdmin1!"

echo "Creating the zombie VM detector tool..."

curl -s -X POST "$KIBANA_URL/api/agent_builder/tools" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "participant.find_zombie_vms",
    "type": "esql",
    "description": "Finds zombie VMs: machines with very low CPU usage (<15%) running on expensive instance types. Shows which teams are wasting money on idle resources.",
    "tags": ["participant", "infrastructure", "cost"],
    "configuration": {
      "query": "FROM gcp-resource-executions-workshop\n| WHERE resource_usage.cpu.avg_percent < 15\n  AND vm_info.vm_type_actual.keyword IN (\"n2-standard-16\", \"n2-standard-32\", \"c2-standard-8\")\n| STATS\n    avg_cpu = AVG(resource_usage.cpu.avg_percent),\n    avg_drift = AVG(drift_metrics.combined_drift_score),\n    total_cost = SUM(cost_actual.total_cost_usd),\n    occurrences = COUNT(*)\n  BY metadata.team.keyword,\n     vm_info.vm_type_actual.keyword,\n     resource_name.keyword\n| SORT total_cost DESC\n| LIMIT 15",
      "params": {}
    }
  }' 2>/dev/null | python3 -m json.tool

echo ""
echo "Tool created. Test it by asking the AI Assistant: 'Find zombie VMs'"
