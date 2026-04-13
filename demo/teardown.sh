#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

echo "=== Demo Teardown ==="
echo ""
echo "This will delete ONLY synthetic indices (not migrated data)."
echo "Synthetic indices to delete:"
echo "  - gcp-resource-executions-synthetic"
echo "  - gcp-instance-lifecycle-synthetic"
echo "  - ml-predictions-anomalies-synthetic"
echo ""

read -p "Proceed? (y/N) " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Aborted."
  exit 0
fi

for IDX in gcp-resource-executions-synthetic gcp-instance-lifecycle-synthetic ml-predictions-anomalies-synthetic; do
  echo "Deleting $IDX..."
  curl -s -X DELETE -H "Authorization: ApiKey $TARGET_API_KEY" "$TARGET_URL/$IDX" | python3 -c "import sys,json; print(json.load(sys.stdin))"
done

echo ""
echo "Teardown complete. Migrated data indices are preserved."
echo "To regenerate synthetic data, run: python3 scripts/generate_synthetic_data.py"
