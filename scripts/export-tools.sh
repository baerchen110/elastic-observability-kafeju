#!/usr/bin/env bash
set -euo pipefail
#
# Exports Agent Builder tool definitions from the source Serverless project.
# Since the Agent Builder tools API is not publicly exposed for bulk export,
# this script documents the tool definitions in tool-definitions.json
# (already created from MCP descriptors + index mapping analysis).
#
# Usage: bash scripts/export-tools.sh
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Agent Builder Tool Export ==="
echo ""
echo "Tool definitions file: $SCRIPT_DIR/tool-definitions.json"
echo ""

TOOL_COUNT=$(python3 -c "import json; d=json.load(open('$SCRIPT_DIR/tool-definitions.json')); print(len(d['tools']))")
echo "Total tools exported: $TOOL_COUNT"
echo ""

python3 -c "
import json
tools = json.load(open('$SCRIPT_DIR/tool-definitions.json'))['tools']
for t in tools:
    print(f'  {t[\"id\"]}: {t[\"name\"]}')
"
echo ""
echo "Each tool contains: id, name, description, esql_query"
echo "Use import-tools.sh to recreate these on the target deployment."
