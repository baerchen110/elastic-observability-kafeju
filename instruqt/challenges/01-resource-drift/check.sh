#!/usr/bin/env bash
set -euo pipefail

ES_URL="http://localhost:9200"
ES_USER="elastic"
ES_PASS="workshopAdmin1!"

EXEC_COUNT=$(curl -s -u "$ES_USER:$ES_PASS" "$ES_URL/gcp-resource-executions-workshop/_count" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))")

if [ "$EXEC_COUNT" -lt 100 ]; then
  fail-message "Workshop data not found. Please wait for setup to complete and refresh Kibana."
  exit 1
fi

KIBANA_URL="http://localhost:5601"
KIBANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KIBANA_URL/api/status" 2>/dev/null || echo "000")

if [ "$KIBANA_STATUS" != "200" ]; then
  fail-message "Kibana is not responding. Please check that the environment is running."
  exit 1
fi

exit 0
