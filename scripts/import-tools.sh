#!/usr/bin/env bash
set -euo pipefail
#
# Recreates Agent Builder tools on the target Hosted deployment.
#
# This script outputs step-by-step instructions since Agent Builder tool
# creation requires the Kibana UI or internal API. It validates that the
# target indices exist and generates the configuration for each tool.
#
# Usage: bash scripts/import-tools.sh
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

TOOL_FILE="$SCRIPT_DIR/tool-definitions.json"

echo "=== Agent Builder Tool Import ==="
echo "Target: $TARGET_URL"
echo ""

echo "Step 1: Verifying target indices exist..."
INDICES=$(python3 -c "
import json
tools = json.load(open('$TOOL_FILE'))['tools']
indices = set()
for t in tools:
    q = t['esql_query']
    for part in q.split():
        if part.startswith('gcp-') or part.startswith('ml-'):
            indices.add(part.rstrip(','))
for i in sorted(indices):
    print(i)
")

ALL_OK=true
for IDX_PATTERN in $INDICES; do
  COUNT=$(curl -s -H "Authorization: ApiKey $TARGET_API_KEY" \
    "$TARGET_URL/_cat/indices/$IDX_PATTERN?h=docs.count" 2>/dev/null | head -1 | tr -d ' ')
  if [ -z "$COUNT" ] || [ "$COUNT" = "" ]; then
    echo "  MISSING: $IDX_PATTERN"
    ALL_OK=false
  else
    echo "  OK: $IDX_PATTERN ($COUNT docs)"
  fi
done

echo ""
if [ "$ALL_OK" = false ]; then
  echo "WARNING: Some indices are missing. Run migrate-indices.sh first."
fi

echo "Step 2: Tool definitions to recreate in Agent Builder UI"
echo ""
echo "Navigate to Kibana > AI Assistant > Agent Builder on the target deployment."
echo "Create each tool with the following configurations:"
echo ""

python3 -c "
import json
tools = json.load(open('$TOOL_FILE'))['tools']
for i, t in enumerate(tools, 1):
    print(f'--- Tool {i}/{len(tools)}: {t[\"id\"]} ---')
    print(f'Name: {t[\"name\"]}')
    print(f'Description: {t[\"description\"]}')
    print(f'ES|QL Query:')
    for line in t['esql_query'].split(chr(10)):
        print(f'  {line}')
    print()
"

echo "Step 3: After creating all tools, update the MCP configuration"
echo "to point to the new hosted deployment's Agent Builder endpoint."
