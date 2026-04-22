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

# Build a whitelist of canonical IDs so the cleanup pass below can skip them.
KEEP_IDS=()
for entry in "${DATA_VIEW_LINES[@]}"; do
  KEEP_IDS+=("${entry%%:*}")
done

echo "Pruning non-workshop data views (keeping ${#KEEP_IDS[@]} canonical)..."
KEEP_IDS_CSV="$(IFS=,; echo "${KEEP_IDS[*]}")" \
  KIBANA_URL="$KIBANA_URL" ES_USER="$ES_USER" ES_PASS="$ES_PASS" \
  python3 - <<'PYEOF'
import json
import os
import subprocess

kibana = os.environ["KIBANA_URL"]
auth = f'{os.environ["ES_USER"]}:{os.environ["ES_PASS"]}'
keep = set(os.environ["KEEP_IDS_CSV"].split(","))

# List all data views.
r = subprocess.run(
    ["curl", "-sS", "-u", auth, "-H", "kbn-xsrf: true",
     f"{kibana}/api/data_views"],
    capture_output=True, text=True,
)
try:
    views = json.loads(r.stdout).get("data_view", [])
except Exception:
    print(f"  WARN: could not list data views ({r.stdout[:120]})")
    views = []

deleted = 0
skipped = 0
for v in views:
    vid = v.get("id", "")
    if vid in keep:
        skipped += 1
        continue
    d = subprocess.run(
        ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}",
         "-X", "DELETE", "-u", auth, "-H", "kbn-xsrf: true",
         f"{kibana}/api/data_views/data_view/{vid}"],
        capture_output=True, text=True,
    )
    if d.stdout.strip() in ("200", "204", "404"):
        deleted += 1
    else:
        print(f"  WARN: failed to delete {vid} (HTTP {d.stdout.strip()})")

print(f"  Kept {skipped}, deleted {deleted}.")
PYEOF

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
