#!/usr/bin/env bash
set -euo pipefail

ES_URL="http://localhost:9200"
ES_USER="elastic"
ES_PASS="workshopAdmin1!"

ANOMALY_COUNT=$(curl -s -u "$ES_USER:$ES_PASS" "$ES_URL/ml-predictions-anomalies-workshop/_count" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))")

if [ "$ANOMALY_COUNT" -lt 50 ]; then
  fail-message "Anomaly data not loaded. The environment may still be starting up."
  exit 1
fi

GROWTH_COUNT=$(curl -s -u "$ES_USER:$ES_PASS" "$ES_URL/ml-predictions-growth-workshop/_count" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))")

if [ "$GROWTH_COUNT" -lt 10 ]; then
  fail-message "Growth prediction data not loaded."
  exit 1
fi

exit 0
