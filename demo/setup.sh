#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

echo "=== Demo Environment Setup Check ==="
echo ""

echo "1. Checking target cluster connectivity..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: ApiKey $TARGET_API_KEY" "$TARGET_URL")
if [ "$RESP" = "200" ]; then
  echo "   OK: Target cluster reachable ($TARGET_URL)"
else
  echo "   FAIL: Target cluster returned $RESP"
  exit 1
fi

echo ""
echo "2. Checking required indices..."
REQUIRED_INDICES=(
  gcp-resource-executions-2025.11
  gcp-resource-executions-synthetic
  gcp-billing-actual
  gcp-instance-lifecycle
  gcp-instance-lifecycle-synthetic
  gcp-pricing-catalog
  gcp-vm-pricing
  gcp-workload-requirements
  ml-predictions-anomalies
  ml-predictions-anomalies-synthetic
  ml-predictions-cost-forecast
  ml-predictions-growth
)

ALL_OK=true
for IDX in "${REQUIRED_INDICES[@]}"; do
  COUNT=$(curl -s -H "Authorization: ApiKey $TARGET_API_KEY" "$TARGET_URL/$IDX/_count" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('count','ERR'))" 2>/dev/null || echo "ERR")
  if [ "$COUNT" = "ERR" ] || [ "$COUNT" = "0" ]; then
    echo "   WARN: $IDX ($COUNT docs)"
    ALL_OK=false
  else
    echo "   OK: $IDX ($COUNT docs)"
  fi
done

echo ""
echo "3. Dashboard NDJSON files..."
for F in "$SCRIPT_DIR/dashboards/"*.ndjson; do
  echo "   OK: $(basename "$F")"
done

echo ""
if [ "$ALL_OK" = true ]; then
  echo "=== All checks passed. Demo environment is ready. ==="
else
  echo "=== WARNING: Some indices are empty or missing. Run migration and synthetic data scripts first. ==="
fi

echo ""
echo "Kibana URL: https://b876e3d13d5d4df3b39607a684e710c4.kb.europe-west1.gcp.cloud.es.io:9243"
echo ""
echo "To import dashboards:"
echo "  1. Open Kibana > Stack Management > Saved Objects"
echo "  2. Click Import"
echo "  3. Upload each NDJSON file from demo/dashboards/"
