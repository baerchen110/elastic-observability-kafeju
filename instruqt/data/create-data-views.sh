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

any_failed=0

for entry in "${DATA_VIEW_LINES[@]}"; do
  ID="${entry%%:*}"
  rest="${entry#*:}"
  IFS='|' read -r TITLE TIME_FIELD NAME <<< "$rest"

  # Build payload via env vars (not shell interpolation) so values with
  # special characters cannot break the JSON.
  PAYLOAD=$(DV_ID="$ID" DV_TITLE="$TITLE" DV_TIME="$TIME_FIELD" DV_NAME="$NAME" \
    python3 -c "
import json, os
print(json.dumps({'data_view': {
    'id': os.environ['DV_ID'],
    'title': os.environ['DV_TITLE'],
    'timeFieldName': os.environ['DV_TIME'],
    'name': os.environ['DV_NAME'],
}, 'override': True}))
")

  HTTP_CODE=$(curl -sS -o /tmp/kafeju-dv-resp.json -w "%{http_code}" \
    -X POST "$KIBANA_URL/api/data_views/data_view" \
    -u "$ES_USER:$ES_PASS" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "  OK   $NAME ($TITLE)"
  else
    echo "  FAIL $NAME ($TITLE) - HTTP $HTTP_CODE" >&2
    cat /tmp/kafeju-dv-resp.json >&2 || true
    echo >&2
    any_failed=1
  fi
done

if [ "$any_failed" -ne 0 ]; then
  echo "One or more data views failed to create." >&2
  exit 1
fi

echo "Data views created."
