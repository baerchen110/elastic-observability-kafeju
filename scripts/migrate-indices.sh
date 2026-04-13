#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load env vars
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

INGEST_DIR="/Users/huagechen/.claude/skills/elasticsearch-file-ingest"

INDICES=(
  gcp-billing-actual
  gcp-instance-inventory-2025.11.07
  gcp-instance-lifecycle
  gcp-pricing-catalog
  gcp-requested-resources
  gcp-resource-executions-2025.11
  gcp-vm-pricing
  gcp-workload-requirements
  ml-predictions-anomalies
  ml-predictions-cost-forecast
  ml-predictions-growth
  ml-predictions-growth-summary
)

echo "=== Kafeju Cross-Cluster Migration ==="
echo "Source: $SOURCE_URL"
echo "Target: $TARGET_URL"
echo ""

SKIPPED=0
MIGRATED=0
FAILED=0

for INDEX in "${INDICES[@]}"; do
  SRC_COUNT=$(curl -s -H "Authorization: ApiKey $SOURCE_API_KEY" \
    "$SOURCE_URL/$INDEX/_count" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null || echo "0")

  if [ "$SRC_COUNT" -eq 0 ] 2>/dev/null; then
    echo "[$INDEX] SKIP (0 docs in source)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "[$INDEX] Migrating $SRC_COUNT docs..."
  if node "$INGEST_DIR/scripts/ingest.js" \
    --source-index "$INDEX" \
    --node "$SOURCE_URL" --api-key "$SOURCE_API_KEY" \
    --target "$INDEX" \
    --target-node "$TARGET_URL" --target-api-key "$TARGET_API_KEY" \
    --quiet 2>&1; then
    MIGRATED=$((MIGRATED + 1))
    echo "[$INDEX] OK"
  else
    FAILED=$((FAILED + 1))
    echo "[$INDEX] FAILED"
  fi
done

echo ""
echo "=== Migration Summary ==="
echo "Migrated: $MIGRATED"
echo "Skipped:  $SKIPPED"
echo "Failed:   $FAILED"
