#!/usr/bin/env bash
set -euo pipefail

KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-workshopAdmin1!}"

echo "Creating data views on $KIBANA_URL..."

# Portable across Bash 3 (macOS) and Bash 4+: id:title|timeField|name
DATA_VIEW_LINES=(
  'workshop-executions:gcp-resource-executions-workshop|execution_time.started_at|GCP Resource Executions'
  'workshop-anomalies:ml-predictions-anomalies-workshop|@timestamp|ML Anomalies'
  'workshop-growth:ml-predictions-growth-workshop|@timestamp|ML Growth Predictions'
  'workshop-pricing:gcp-pricing-catalog|last_updated|GCP Pricing Catalog'
  'workshop-lifecycle:gcp-instance-lifecycle-workshop|@timestamp|GCP Instance Lifecycle'
  'workshop-billing:gcp-billing-workshop|@timestamp|GCP Billing'
  'workshop-all-gcp:gcp-*|@timestamp|All GCP Data'
  'workshop-all-ml:ml-predictions-*|@timestamp|All ML Predictions'
)

for entry in "${DATA_VIEW_LINES[@]}"; do
  ID="${entry%%:*}"
  rest="${entry#*:}"
  IFS='|' read -r TITLE TIME_FIELD NAME <<< "$rest"

  PAYLOAD=$(python3 -c "
import json
print(json.dumps({'data_view': {
    'id': '$ID',
    'title': '$TITLE',
    'timeFieldName': '$TIME_FIELD',
    'name': '$NAME'
}, 'override': True}))
")

  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KIBANA_URL/api/data_views/data_view" \
    -u "$ES_USER:$ES_PASS" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null)

  if [ "$CODE" = "200" ]; then
    echo "  OK   $NAME ($TITLE)"
  else
    echo "  FAIL $NAME ($TITLE) - HTTP $CODE"
  fi
done

echo "Data views created."
