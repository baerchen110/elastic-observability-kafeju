#!/usr/bin/env bash
set -euo pipefail
#
# Provision workshop participant API keys with read-only access.
# Usage: bash workshop/setup/provision.sh <number_of_participants>
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

if [ -f "$PROJECT_DIR/.env" ]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

NUM_PARTICIPANTS=${1:-5}
EXPIRY=${2:-8h}

echo "=== Workshop Participant Provisioning ==="
echo "Creating $NUM_PARTICIPANTS API keys with $EXPIRY expiration"
echo ""

OUTPUT_FILE="$SCRIPT_DIR/participant-credentials.txt"
echo "# Workshop Participant Credentials" > "$OUTPUT_FILE"
echo "# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$OUTPUT_FILE"
echo "# Expiration: $EXPIRY" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

for i in $(seq 1 "$NUM_PARTICIPANTS"); do
  PADDED=$(printf "%02d" "$i")
  RESP=$(curl -s -X POST "$TARGET_URL/_security/api_key" \
    -H "Authorization: ApiKey $TARGET_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"workshop-participant-$PADDED\",
      \"role_descriptors\": {
        \"workshop_reader\": {
          \"cluster\": [\"monitor\"],
          \"indices\": [{
            \"names\": [\"gcp-*\", \"ml-predictions-*\"],
            \"privileges\": [\"read\", \"view_index_metadata\"]
          }]
        }
      },
      \"expiration\": \"$EXPIRY\"
    }")

  API_KEY=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('encoded','ERROR'))" 2>/dev/null)

  if [ "$API_KEY" = "ERROR" ]; then
    echo "  FAIL: Participant $PADDED"
    echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
  else
    echo "  OK: Participant $PADDED"
    echo "Participant $PADDED: $API_KEY" >> "$OUTPUT_FILE"
  fi
done

echo ""
echo "Credentials saved to: $OUTPUT_FILE"
echo ""
echo "Kibana URL: https://b876e3d13d5d4df3b39607a684e710c4.kb.europe-west1.gcp.cloud.es.io:9243"
echo ""
echo "Distribute the API key and Kibana URL to each participant."
echo "Keys expire after $EXPIRY."
