#!/usr/bin/env bash
set -euo pipefail

ES_URL="http://localhost:9200"
ES_USER="elastic"
ES_PASS="workshopAdmin1!"

echo "=== Answer Key: ML Anomaly Detection ==="
echo ""
echo "--- CRITICAL anomalies ---"
curl -s -u "$ES_USER:$ES_PASS" "$ES_URL/ml-predictions-anomalies-workshop/_search" \
  -H "Content-Type: application/json" \
  -d '{"size": 5, "query": {"term": {"severity": "CRITICAL"}}, "sort": [{"record_score": "desc"}]}' \
  2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for h in d['hits']['hits']:
    s = h['_source']
    print(f'  {s[\"team\"]:20s} {s[\"vm_type\"]:18s} {s[\"function_description\"]:30s} score={s[\"record_score\"]}  actual={s[\"actual\"]}')
"

echo ""
echo "--- Zombie VMs ---"
echo "  devops-infra: n2-standard-32 at ~3% CPU (typical: 45%) - score ~92"
echo "  devops-infra: e2-standard-8 at ~5% CPU (typical: 40%) - score ~85"

echo ""
echo "--- Teams needing resize (predict_resize_needs) ---"
curl -s -u "$ES_USER:$ES_PASS" "$ES_URL/ml-predictions-growth-workshop/_search" \
  -H "Content-Type: application/json" \
  -d '{"size": 9, "collapse": {"field": "team.keyword"}, "sort": [{"predicted_days_to_90pct": "asc"}]}' \
  2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for h in d['hits']['hits']:
    s = h['_source']
    print(f'  {s[\"team\"]:20s} days_to_90={s[\"predicted_days_to_90pct\"]:4d}  growth={s[\"growth_rate_daily\"]}  rec={s[\"recommendation\"]}')
"

echo ""
echo "--- Answer: analytics (12 days to 90%) needs URGENT_RESIZE ---"
