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
    "id": "participant.regional_cost_comparison",
    "description": "Compares the average VM cost across GCP regions to identify the cheapest regions for deployment. Shows average hourly and monthly cost, plus machine type availability per region. Use when asked about cheapest regions, regional pricing, or where to deploy workloads.",
    "tags": ["participant", "cost", "regions"],
    "configuration": {
      "query": "FROM gcp-pricing-catalog\n| STATS\n    avg_hourly = AVG(cost_per_hour_usd),\n    avg_monthly = AVG(cost_per_month_usd),\n    types_available = COUNT(*),\n    max_cores = MAX(cpu_cores),\n    max_memory = MAX(memory_gb)\n  BY region\n| SORT avg_hourly ASC",
      "params": {}
    }
  }' > /dev/null 2>&1

curl -s -u "$ES_USER:$ES_PASS" "$KIBANA_URL/api/agent_builder/agents" \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
agents = json.load(sys.stdin)['results']
kafeju = next(a for a in agents if a['id'] == 'kafuju')
tools = kafeju['configuration']['tools'][0]['tool_ids']
if 'participant.regional_cost_comparison' not in tools:
    tools.append('participant.regional_cost_comparison')
kafeju.pop('readonly', None)
kafeju.pop('type', None)
with open('/tmp/agent-update.json', 'w') as f:
    json.dump(kafeju, f)
"

curl -s -X PUT "$KIBANA_URL/api/agent_builder/agents/kafuju" \
  -u "$ES_USER:$ES_PASS" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d @/tmp/agent-update.json > /dev/null 2>&1

echo "Regional cost comparison tool created and wired into Kafeju agent."
