#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTRUQT_DIR="$(dirname "$SCRIPT_DIR")"

export ELASTIC_PASSWORD="workshopAdmin1!"
export ES_URL="http://localhost:9200"
export ES_USER="elastic"
export ES_PASS="$ELASTIC_PASSWORD"
export KIBANA_URL="http://localhost:5601"

echo "=== Step 1: Install Docker ==="
apt-get update -qq
apt-get install -y -qq docker.io docker-compose python3-pip curl jq > /dev/null 2>&1
systemctl enable docker
systemctl start docker

echo "=== Step 2: Start Elasticsearch + Kibana ==="
cd "$INSTRUQT_DIR"
ELASTIC_PASSWORD="$ELASTIC_PASSWORD" docker compose up -d

echo "=== Step 3: Wait for Elasticsearch ==="
for i in $(seq 1 60); do
  if curl -s -u "$ES_USER:$ES_PASS" "$ES_URL/_cluster/health" | grep -q '"status"'; then
    echo "  Elasticsearch ready after ${i}0 seconds"
    break
  fi
  sleep 10
done

curl -s -u "$ES_USER:$ES_PASS" "$ES_URL/_cluster/health?pretty"

echo "=== Step 4: Wait for Kibana ==="
for i in $(seq 1 60); do
  if curl -s "$KIBANA_URL/api/status" 2>/dev/null | grep -q '"available"'; then
    echo "  Kibana ready after ${i}0 seconds"
    break
  fi
  sleep 10
done

echo "=== Step 5: Activate trial license ==="
curl -s -X POST -u "$ES_USER:$ES_PASS" "$ES_URL/_license/start_trial?acknowledge=true" || true

echo "=== Step 6: Load workshop data ==="
pip3 install -q "elasticsearch>=8.0" 2>/dev/null
python3 "$INSTRUQT_DIR/data/generate-workshop-data.py"

echo "=== Step 7: Create Agent Builder tools ==="
bash "$INSTRUQT_DIR/data/create-tools.sh"

echo "=== Step 8: Create data views ==="
bash "$INSTRUQT_DIR/data/create-data-views.sh"

echo "=== Step 9: Create Kafeju agent ==="
bash "$INSTRUQT_DIR/data/create-kafeju-agent.sh"

echo "=== Setup complete ==="
echo "  Elasticsearch: $ES_URL"
echo "  Kibana:        $KIBANA_URL"
echo "  User:          elastic / $ELASTIC_PASSWORD"
