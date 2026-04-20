#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES="$REPO_ROOT/resources"
DOCKER_DIR="$RESOURCES/docker"

ES_PORT="${ES_PORT:-9200}"
KIBANA_PORT="${KIBANA_PORT:-5601}"
ES_URL="http://localhost:$ES_PORT"
KIBANA_URL="http://localhost:$KIBANA_PORT"
ES_PASSWORD="${ELASTIC_PASSWORD:-workshopAdmin1!}"
ES_AUTH="elastic:$ES_PASSWORD"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ── Pre-flight checks ─────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || fail "docker is not installed"
command -v curl   >/dev/null 2>&1 || fail "curl is not installed"
command -v python3 >/dev/null 2>&1 || fail "python3 is not installed"

if [ ! -f "$DOCKER_DIR/.env" ]; then
  info "Creating $DOCKER_DIR/.env from .env.example"
  cp "$DOCKER_DIR/.env.example" "$DOCKER_DIR/.env"
fi

# Source the docker .env for variable defaults
set -a; source "$DOCKER_DIR/.env"; set +a

# ── 1. Start Docker Compose ───────────────────────────────────────────
info "Starting Elasticsearch and Kibana..."
docker compose -f "$DOCKER_DIR/docker-compose.yml" --env-file "$DOCKER_DIR/.env" up -d

# ── 2. Wait for Elasticsearch ─────────────────────────────────────────
info "Waiting for Elasticsearch at $ES_URL..."
for i in $(seq 1 60); do
  if curl -sf -u "$ES_AUTH" "$ES_URL/_cluster/health" >/dev/null 2>&1; then
    info "Elasticsearch is ready"
    break
  fi
  [ "$i" -eq 60 ] && fail "Elasticsearch did not start within 5 minutes"
  sleep 5
done

# Start trial license
curl -sf -X POST -u "$ES_AUTH" "$ES_URL/_license/start_trial?acknowledge=true" \
  -H "Content-Type: application/json" >/dev/null 2>&1 || true

# ── 3. Wait for Kibana ────────────────────────────────────────────────
info "Waiting for Kibana at $KIBANA_URL..."
for i in $(seq 1 60); do
  if curl -sf "$KIBANA_URL/api/status" 2>/dev/null | grep -q '"level":"available"'; then
    info "Kibana is ready"
    break
  fi
  [ "$i" -eq 60 ] && fail "Kibana did not start within 5 minutes"
  sleep 5
done

# ── 4. Create indices with explicit mappings ──────────────────────────
info "Creating indices with mappings..."
for mapping_file in "$RESOURCES/elasticsearch/mappings"/*.json; do
  idx=$(basename "$mapping_file" .json)
  BODY=$(python3 -c "
import json, sys
with open('$mapping_file') as f:
    m = json.load(f)
json.dump({'mappings': m, 'settings': {'number_of_shards': 1, 'number_of_replicas': 0}}, sys.stdout)
")
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT -u "$ES_AUTH" \
    "$ES_URL/$idx" -H "Content-Type: application/json" -d "$BODY")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "  $idx: created"
  elif [ "$HTTP_CODE" = "400" ]; then
    echo "  $idx: already exists (skipped)"
  else
    warn "$idx: HTTP $HTTP_CODE"
  fi
done

# ── 5. Bulk-load seed data ────────────────────────────────────────────
info "Loading seed data..."
TOTAL_LOADED=0
for data_file in "$RESOURCES/elasticsearch/seed-data"/*.ndjson; do
  idx=$(basename "$data_file" .ndjson)
  DOC_COUNT=$(( $(wc -l < "$data_file" | tr -d ' ') / 2 ))

  RESP=$(curl -s -X POST -u "$ES_AUTH" "$ES_URL/_bulk" \
    -H "Content-Type: application/x-ndjson" \
    --data-binary "@$data_file")
  ERRORS=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('errors',True))" 2>/dev/null)
  if [ "$ERRORS" = "False" ]; then
    echo "  $idx: $DOC_COUNT docs loaded"
    TOTAL_LOADED=$((TOTAL_LOADED + DOC_COUNT))
  else
    ERROR_COUNT=$(echo "$RESP" | python3 -c "
import sys,json
d=json.load(sys.stdin)
errs=sum(1 for i in d.get('items',[]) if 'error' in i.get('index',i.get('create',{})))
print(errs)" 2>/dev/null)
    warn "$idx: $DOC_COUNT docs, $ERROR_COUNT errors"
    TOTAL_LOADED=$((TOTAL_LOADED + DOC_COUNT))
  fi
done
info "Loaded $TOTAL_LOADED total documents"

# Refresh all indices
curl -s -X POST -u "$ES_AUTH" "$ES_URL/_refresh" >/dev/null

# ── 6. Import Kibana saved objects ────────────────────────────────────
info "Importing Kibana saved objects (dashboards, visualizations)..."
IMPORT_RESP=$(curl -s -X POST -u "$ES_AUTH" \
  "$KIBANA_URL/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -F file=@"$RESOURCES/kibana/saved-objects.ndjson")
SUCCESS=$(echo "$IMPORT_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('successCount',0))" 2>/dev/null)
info "Imported $SUCCESS saved objects"

# ── 7. Create data views ─────────────────────────────────────────────
info "Creating data views..."
python3 - "$KIBANA_URL" "$ES_AUTH" "$RESOURCES/kibana/data-views.json" << 'PYEOF'
import sys, json, subprocess

kibana, auth, dvpath = sys.argv[1], sys.argv[2], sys.argv[3]

with open(dvpath) as f:
    views = json.load(f)

created = 0
for v in views:
    body = {
        "data_view": {
            "id": v["id"],
            "title": v["title"],
            "name": v.get("name", v["title"]),
            "timeFieldName": v.get("timeFieldName", ""),
            "allowNoIndex": v.get("allowNoIndex", True),
        },
        "override": True
    }
    if not body["data_view"]["timeFieldName"]:
        del body["data_view"]["timeFieldName"]

    r = subprocess.run(["curl", "-s", "-X", "POST", f"{kibana}/api/data_views/data_view",
        "-u", auth, "-H", "kbn-xsrf: true", "-H", "Content-Type: application/json",
        "-d", json.dumps(body)], capture_output=True, text=True)
    try:
        resp = json.loads(r.stdout)
        if "data_view" in resp:
            created += 1
        else:
            msg = resp.get("message", resp.get("error", ""))[:60]
            print(f"  WARN {v['id']}: {msg}")
    except:
        pass

print(f"  Created {created}/{len(views)} data views")
PYEOF

# ── 8. Create Agent Builder tools ─────────────────────────────────────
info "Creating Agent Builder tools..."
python3 - "$KIBANA_URL" "$ES_AUTH" "$RESOURCES/kibana/agent-tools.json" << 'PYEOF'
import sys, json, subprocess

kibana, auth, toolpath = sys.argv[1], sys.argv[2], sys.argv[3]

with open(toolpath) as f:
    tools = json.load(f)

created = 0
for t in tools:
    t.pop("readonly", None)
    r = subprocess.run(["curl", "-s", "-X", "POST", f"{kibana}/api/agent_builder/tools",
        "-u", auth, "-H", "kbn-xsrf: true", "-H", "Content-Type: application/json",
        "-d", json.dumps(t)], capture_output=True, text=True)
    try:
        resp = json.loads(r.stdout)
        if resp.get("id") or "id" in resp:
            created += 1
        else:
            msg = resp.get("message", resp.get("error", ""))
            if isinstance(msg, str):
                msg = msg[:60]
            print(f"  WARN {t.get('id','?')}: {msg}")
    except:
        print(f"  WARN {t.get('id','?')}: {r.stdout[:80]}")

print(f"  Created {created}/{len(tools)} tools")
PYEOF

# ── 9. Create ML jobs + datafeeds ─────────────────────────────────────
info "Creating ML jobs and datafeeds..."
python3 - "$ES_URL" "$ES_AUTH" "$RESOURCES/ml/jobs.json" << 'PYEOF'
import sys, json, subprocess

es, auth, jobpath = sys.argv[1], sys.argv[2], sys.argv[3]

with open(jobpath) as f:
    entries = json.load(f)

def api(method, path, body=None):
    cmd = ["curl", "-s", "-X", method, f"{es}{path}",
           "-u", auth, "-H", "Content-Type: application/json"]
    if body:
        cmd += ["-d", json.dumps(body)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except:
        return {"raw": r.stdout}

for entry in entries:
    job = entry["job"]
    feed = entry.get("datafeed")
    jid = job["job_id"]

    job_body = {k: v for k, v in job.items()
                if k not in ("job_id", "job_type", "job_version", "create_time",
                             "model_snapshot_id", "model_snapshot_min_version",
                             "datafeed_config", "finished_time", "node", "open_time")}
    job_body["allow_lazy_open"] = True
    job_body.setdefault("analysis_limits", {})["model_memory_limit"] = "256mb"

    r = api("PUT", f"/_ml/anomaly_detectors/{jid}", job_body)
    if r.get("job_id"):
        print(f"  job {jid}: created")
    else:
        msg = r.get("error", {})
        if isinstance(msg, dict):
            msg = msg.get("reason", "")[:80]
        print(f"  job {jid}: {msg}")

    if feed:
        fid = feed.get("datafeed_id", f"datafeed-{jid}")
        feed_body = {k: v for k, v in feed.items()
                     if k not in ("datafeed_id", "authorization", "query_delay")}
        r = api("PUT", f"/_ml/datafeeds/{fid}", feed_body)
        if r.get("datafeed_id"):
            print(f"  datafeed {fid}: created")
        else:
            msg = r.get("error", {})
            if isinstance(msg, dict):
                msg = msg.get("reason", "")[:80]
            print(f"  datafeed {fid}: {msg}")

    r = api("POST", f"/_ml/anomaly_detectors/{jid}/_open", {})
    r = api("POST", f"/_ml/datafeeds/datafeed-{jid}/_start", {})

print("  ML jobs opened and datafeeds started")
PYEOF

# ── Done ──────────────────────────────────────────────────────────────
echo ""
info "=========================================="
info " Workshop bootstrap complete!"
info "=========================================="
info " Elasticsearch: $ES_URL  (user: elastic / $ES_PASSWORD)"
info " Kibana:        $KIBANA_URL"
info ""
info " Loaded:"

curl -s -u "$ES_AUTH" "$ES_URL/_cat/count" 2>/dev/null | while read -r _ _ count; do
  echo "   - $count total documents"
done

SO_COUNT=$(curl -s -u "$ES_AUTH" "$KIBANA_URL/api/saved_objects/_find?type=dashboard&per_page=1" \
  -H "kbn-xsrf: true" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))" 2>/dev/null)
echo "   - $SO_COUNT dashboards"

ML_COUNT=$(curl -s -u "$ES_AUTH" "$ES_URL/_ml/anomaly_detectors/_stats" 2>/dev/null \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('jobs',[])))" 2>/dev/null)
echo "   - $ML_COUNT ML jobs"

echo ""
info "Open Kibana at $KIBANA_URL to start the workshop"
