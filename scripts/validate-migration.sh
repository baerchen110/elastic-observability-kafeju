#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

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

echo "=== Migration Validation ==="
printf "%-45s %8s %8s %s\n" "INDEX" "SOURCE" "TARGET" "MATCH"
printf "%-45s %8s %8s %s\n" "-----" "------" "------" "-----"

PASS=0
FAIL=0

for INDEX in "${INDICES[@]}"; do
  SRC=$(curl -s -H "Authorization: ApiKey $SOURCE_API_KEY" \
    "$SOURCE_URL/$INDEX/_count" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('count','ERR'))" 2>/dev/null || echo "ERR")

  TGT=$(curl -s -H "Authorization: ApiKey $TARGET_API_KEY" \
    "$TARGET_URL/$INDEX/_count" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('count','ERR'))" 2>/dev/null || echo "ERR")

  if [ "$SRC" = "$TGT" ]; then
    STATUS="YES"
    PASS=$((PASS + 1))
  else
    STATUS="NO"
    FAIL=$((FAIL + 1))
  fi
  printf "%-45s %8s %8s %s\n" "$INDEX" "$SRC" "$TGT" "$STATUS"
done

echo ""
echo "Pass: $PASS / $((PASS + FAIL))"
[ "$FAIL" -eq 0 ] && echo "All indices validated successfully." || echo "WARNING: $FAIL indices have mismatched counts."
