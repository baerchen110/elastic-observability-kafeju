#!/usr/bin/env bash
set -euo pipefail

ES_URL="http://localhost:9200"
ES_USER="elastic"
ES_PASS="workshopAdmin1!"

echo "=== Answer Key: Resource Drift Detection ==="
echo ""
echo "--- Top 5 teams by combined drift (analyze_vm_usage_patterns) ---"
curl -s -u "$ES_USER:$ES_PASS" "$ES_URL/gcp-resource-executions-workshop/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 0,
    "aggs": {
      "by_team": {
        "terms": {"field": "metadata.team.keyword", "size": 10, "order": {"drift": "desc"}},
        "aggs": {
          "drift": {"avg": {"field": "drift_metrics.combined_drift_score"}},
          "cpu_used": {"avg": {"field": "resource_usage.cpu.avg_percent"}},
          "cost": {"sum": {"field": "cost_actual.total_cost_usd"}}
        }
      }
    }
  }' 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for b in d['aggregations']['by_team']['buckets']:
    print(f'  {b[\"key\"]:25s} drift={b[\"drift\"][\"value\"]:.1f}%  cpu_used={b[\"cpu_used\"][\"value\"]:.1f}%  cost=\${b[\"cost\"][\"value\"]:.2f}')
"

echo ""
echo "--- Answer: devops-infra has the highest drift (running n2-standard-32 at ~8% CPU) ---"
echo "--- The cost-optimized team has the lowest drift (recently rightsized) ---"
