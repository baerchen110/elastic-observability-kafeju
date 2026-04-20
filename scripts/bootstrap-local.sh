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

# ── Logging ───────────────────────────────────────────────────────────
LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"
exec > >(stdbuf -oL tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ts()    { date +"%H:%M:%S"; }
info()  { echo -e "$(ts) ${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "$(ts) ${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "$(ts) ${RED}[FAIL]${NC}  $*"; echo ""; echo "Full log: $LOG_FILE"; exit 1; }

info "Log file: $LOG_FILE"

# ── Pre-flight ────────────────────────────────────────────────────────
command -v docker  >/dev/null 2>&1 || fail "docker is not installed"
command -v curl    >/dev/null 2>&1 || fail "curl is not installed"
command -v python3 >/dev/null 2>&1 || fail "python3 is not installed"

if [ ! -f "$DOCKER_DIR/.env" ]; then
  cp "$DOCKER_DIR/.env.example" "$DOCKER_DIR/.env"
fi
set -a; source "$DOCKER_DIR/.env"; set +a

# ── 1. Start Elasticsearch only ───────────────────────────────────────
info "Starting Elasticsearch..."
docker compose -f "$DOCKER_DIR/docker-compose.yml" --env-file "$DOCKER_DIR/.env" up -d elasticsearch

info "Waiting for Elasticsearch at $ES_URL..."
for i in $(seq 1 60); do
  if curl -sf -u "$ES_AUTH" "$ES_URL/_cluster/health" >/dev/null 2>&1; then
    ES_VER=$(curl -s -u "$ES_AUTH" "$ES_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['version']['number'])" 2>/dev/null || echo "?")
    info "Elasticsearch $ES_VER is ready"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo ""
    warn "Elasticsearch did not respond. Docker logs:"
    docker logs kafeju-es --tail 30 2>&1 | sed 's/^/  | /'
    fail "Elasticsearch did not start within 5 minutes"
  fi
  sleep 5
done

curl -sf -X POST -u "$ES_AUTH" "$ES_URL/_license/start_trial?acknowledge=true" \
  -H "Content-Type: application/json" >/dev/null 2>&1 || true

# ── 2. Generate Kibana service account token ──────────────────────────
info "Generating Kibana service account token..."
curl -s -X DELETE -u "$ES_AUTH" \
  "$ES_URL/_security/service/elastic/kibana/credential/token/bootstrap-token" \
  -H "Content-Type: application/json" >/dev/null 2>&1 || true
TOKEN_RESP=$(curl -s -X POST -u "$ES_AUTH" \
  "$ES_URL/_security/service/elastic/kibana/credential/token/bootstrap-token" \
  -H "Content-Type: application/json")
SERVICE_TOKEN=$(echo "$TOKEN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['token']['value'])" 2>/dev/null || true)

if [ -z "$SERVICE_TOKEN" ]; then
  warn "Token creation response: $TOKEN_RESP"
  fail "Could not generate Kibana service account token"
fi
info "Service token generated"

if grep -q "^KIBANA_SERVICE_TOKEN=" "$DOCKER_DIR/.env" 2>/dev/null; then
  python3 -c "
import re
with open('$DOCKER_DIR/.env') as f: content = f.read()
content = re.sub(r'^KIBANA_SERVICE_TOKEN=.*$', 'KIBANA_SERVICE_TOKEN=$SERVICE_TOKEN', content, flags=re.MULTILINE)
with open('$DOCKER_DIR/.env', 'w') as f: f.write(content)
"
else
  echo "KIBANA_SERVICE_TOKEN=$SERVICE_TOKEN" >> "$DOCKER_DIR/.env"
fi

# ── 3. Start Kibana ──────────────────────────────────────────────────
info "Starting Kibana..."
docker compose -f "$DOCKER_DIR/docker-compose.yml" --env-file "$DOCKER_DIR/.env" up -d kibana

info "Waiting for Kibana at $KIBANA_URL..."
for i in $(seq 1 90); do
  if curl -sf "$KIBANA_URL/api/status" 2>/dev/null | grep -q '"level":"available"'; then
    info "Kibana is ready"
    break
  fi
  if [ "$i" -eq 90 ]; then
    echo ""
    warn "Kibana did not respond. Docker logs:"
    docker logs kafeju-kibana --tail 30 2>&1 | sed 's/^/  | /'
    fail "Kibana did not start within 7.5 minutes"
  fi
  sleep 5
done

# ── 4. Create indices with explicit mappings ──────────────────────────
info "Creating indices with mappings..."
IDX_CREATED=0; IDX_SKIPPED=0; IDX_FAILED=0
for mapping_file in "$RESOURCES/elasticsearch/mappings"/*.json; do
  idx=$(basename "$mapping_file" .json)
  BODY=$(python3 -c "
import json, sys
with open('$mapping_file') as f: m = json.load(f)
json.dump({'mappings': m, 'settings': {'number_of_shards': 1, 'number_of_replicas': 0}}, sys.stdout)
")
  RESP_FILE=$(mktemp)
  HTTP_CODE=$(curl -s -o "$RESP_FILE" -w "%{http_code}" -X PUT -u "$ES_AUTH" \
    "$ES_URL/$idx" -H "Content-Type: application/json" -d "$BODY")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "  $idx: created"
    IDX_CREATED=$((IDX_CREATED + 1))
  elif [ "$HTTP_CODE" = "400" ]; then
    echo "  $idx: already exists (skipped)"
    IDX_SKIPPED=$((IDX_SKIPPED + 1))
  else
    REASON=$(python3 -c "import sys,json; print(json.load(open('$RESP_FILE')).get('error',{}).get('reason','unknown')[:100])" 2>/dev/null || cat "$RESP_FILE" | head -c 100)
    warn "$idx: HTTP $HTTP_CODE — $REASON"
    IDX_FAILED=$((IDX_FAILED + 1))
  fi
  rm -f "$RESP_FILE"
done
info "Indices: $IDX_CREATED created, $IDX_SKIPPED skipped, $IDX_FAILED failed"

# ── 5. Bulk-load seed data (chunked to stay under body size limits) ───
CHUNK_DOCS=200
CHUNK_LINES=$((CHUNK_DOCS * 2))
info "Loading seed data (${CHUNK_DOCS} docs per request)..."
TOTAL_LOADED=0; TOTAL_ERRORS=0
BULK_RESP=$(mktemp)
CHUNK_DIR=$(mktemp -d)
for data_file in "$RESOURCES/elasticsearch/seed-data"/*.ndjson; do
  idx=$(basename "$data_file" .ndjson)
  DOC_COUNT=$(( $(wc -l < "$data_file" | tr -d ' ') / 2 ))
  IDX_LOADED=0; IDX_ERRORS=0

  split -l "$CHUNK_LINES" -a 4 "$data_file" "$CHUNK_DIR/chunk_"
  CHUNKS=("$CHUNK_DIR"/chunk_*)
  NUM_CHUNKS=${#CHUNKS[@]}
  CHUNK_I=0

  for chunk in "${CHUNKS[@]}"; do
    CHUNK_I=$((CHUNK_I + 1))
    DOCS_IN_CHUNK=$(( $(wc -l < "$chunk" | tr -d ' ') / 2 ))

    HTTP_CODE=$(curl -s -o "$BULK_RESP" -w "%{http_code}" --max-time 120 \
      -X POST -u "$ES_AUTH" "$ES_URL/_bulk" \
      -H "Content-Type: application/x-ndjson" \
      --data-binary "@$chunk")

    if [ "$HTTP_CODE" != "200" ]; then
      warn "$idx [$CHUNK_I/$NUM_CHUNKS]: HTTP $HTTP_CODE ($(head -c 150 "$BULK_RESP"))"
      IDX_ERRORS=$((IDX_ERRORS + DOCS_IN_CHUNK))
    else
      CHUNK_ERRS=$(python3 -c "
import json
with open('$BULK_RESP') as f: d = json.load(f)
errs = [i for i in d.get('items',[]) if 'error' in i.get('index',i.get('create',{}))]
print(len(errs))
" 2>/dev/null || echo "0")
      IDX_LOADED=$((IDX_LOADED + DOCS_IN_CHUNK - CHUNK_ERRS))
      IDX_ERRORS=$((IDX_ERRORS + CHUNK_ERRS))
    fi

    if [ "$NUM_CHUNKS" -gt 1 ]; then
      echo -ne "  $idx: chunk $CHUNK_I/$NUM_CHUNKS ($IDX_LOADED docs so far)\r"
    fi
  done
  rm -f "$CHUNK_DIR"/chunk_*

  if [ "$NUM_CHUNKS" -gt 1 ]; then
    echo -ne "\033[2K"
  fi
  if [ "$IDX_ERRORS" -eq 0 ]; then
    echo "  $idx: $DOC_COUNT docs OK"
  else
    warn "$idx: $IDX_LOADED/$DOC_COUNT docs loaded, $IDX_ERRORS errors"
  fi
  TOTAL_LOADED=$((TOTAL_LOADED + IDX_LOADED))
  TOTAL_ERRORS=$((TOTAL_ERRORS + IDX_ERRORS))
done
rm -f "$BULK_RESP"
rm -rf "$CHUNK_DIR"
info "Loaded $TOTAL_LOADED total documents ($TOTAL_ERRORS errors)"

curl -s --max-time 30 -X POST -u "$ES_AUTH" "$ES_URL/_refresh" >/dev/null

# ── 6. Import Kibana saved objects ────────────────────────────────────
info "Importing Kibana saved objects (dashboards, visualizations)..."
IMPORT_RESP=$(curl -s -X POST -u "$ES_AUTH" \
  "$KIBANA_URL/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -F file=@"$RESOURCES/kibana/saved-objects.ndjson")
SUCCESS=$(echo "$IMPORT_RESP" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('successCount',0))
errs = d.get('errors',[])
if errs:
    for e in errs[:5]:
        print(f'  ERROR: {e.get(\"id\",\"?\")} ({e.get(\"type\",\"?\")}): {e.get(\"error\",{}).get(\"message\",\"?\")[:80]}')
" 2>/dev/null)
SO_OK=$(echo "$SUCCESS" | head -1)
SO_ERRS=$(echo "$SUCCESS" | tail -n +2)
info "Imported $SO_OK saved objects"
[ -n "$SO_ERRS" ] && echo "$SO_ERRS"

# ── 7. Create data views ─────────────────────────────────────────────
info "Creating data views..."
python3 - "$KIBANA_URL" "$ES_AUTH" "$RESOURCES/kibana/data-views.json" << 'PYEOF'
import sys, json, subprocess

kibana, auth, dvpath = sys.argv[1], sys.argv[2], sys.argv[3]

with open(dvpath) as f:
    views = json.load(f)

created = 0; errors = []
for v in views:
    body = {
        "data_view": {
            "id": v["id"],
            "title": v["title"],
            "name": v.get("name", v["title"]),
            "allowNoIndex": v.get("allowNoIndex", True),
        },
        "override": True
    }
    if v.get("timeFieldName"):
        body["data_view"]["timeFieldName"] = v["timeFieldName"]

    r = subprocess.run(["curl", "-s", "-X", "POST", f"{kibana}/api/data_views/data_view",
        "-u", auth, "-H", "kbn-xsrf: true", "-H", "Content-Type: application/json",
        "-d", json.dumps(body)], capture_output=True, text=True)
    try:
        resp = json.loads(r.stdout)
        if "data_view" in resp:
            created += 1
        else:
            errors.append(f"{v['id']}: {resp.get('message', resp.get('error','?'))[:80]}")
    except Exception as e:
        errors.append(f"{v['id']}: {r.stdout[:80]}")

print(f"  Created {created}/{len(views)} data views")
for e in errors:
    print(f"  ERROR: {e}")
PYEOF

# ── 8. Create Agent Builder tools ─────────────────────────────────────
info "Creating Agent Builder tools..."
python3 - "$KIBANA_URL" "$ES_AUTH" "$RESOURCES/kibana/agent-tools.json" << 'PYEOF'
import sys, json, subprocess

kibana, auth, toolpath = sys.argv[1], sys.argv[2], sys.argv[3]

with open(toolpath) as f:
    tools = json.load(f)

created = 0; errors = []
for t in tools:
    tid = t.get("id", "?")
    t.pop("readonly", None)
    r = subprocess.run(["curl", "-s", "-X", "POST", f"{kibana}/api/agent_builder/tools",
        "-u", auth, "-H", "kbn-xsrf: true", "-H", "Content-Type: application/json",
        "-d", json.dumps(t)], capture_output=True, text=True)
    try:
        resp = json.loads(r.stdout)
        if resp.get("id") or "id" in resp:
            created += 1
        else:
            errors.append(f"{tid}: {resp.get('message', resp.get('error','?'))[:80]}")
    except:
        errors.append(f"{tid}: {r.stdout[:80]}")

print(f"  Created {created}/{len(tools)} tools")
for e in errors:
    print(f"  ERROR: {e}")
PYEOF

# ── 9. Create ML jobs + datafeeds ─────────────────────────────────────
info "Creating ML jobs and datafeeds..."
python3 - "$ES_URL" "$ES_AUTH" "$RESOURCES/ml/jobs.json" << 'PYEOF'
import sys, json, subprocess

es, auth, jobpath = sys.argv[1], sys.argv[2], sys.argv[3]

with open(jobpath) as f:
    entries = json.load(f)

STRIP = {"job_id", "job_type", "job_version", "create_time", "model_snapshot_id",
         "model_snapshot_min_version", "datafeed_config", "finished_time",
         "node", "open_time"}

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

    job_body = {k: v for k, v in job.items() if k not in STRIP}
    job_body["allow_lazy_open"] = True
    job_body.setdefault("analysis_limits", {})["model_memory_limit"] = "256mb"

    r = api("PUT", f"/_ml/anomaly_detectors/{jid}", job_body)
    if r.get("job_id"):
        print(f"  job {jid}: created")
    else:
        reason = r.get("error",{})
        if isinstance(reason, dict): reason = reason.get("reason","failed")
        print(f"  job {jid}: ERROR — {str(reason)[:80]}")

    if feed:
        fid = feed.get("datafeed_id", f"datafeed-{jid}")
        feed_body = {k: v for k, v in feed.items()
                     if k not in ("datafeed_id", "authorization", "query_delay")}
        r = api("PUT", f"/_ml/datafeeds/{fid}", feed_body)
        if r.get("datafeed_id"):
            print(f"  datafeed {fid}: created")
        else:
            reason = r.get("error",{})
            if isinstance(reason, dict): reason = reason.get("reason","failed")
            print(f"  datafeed {fid}: ERROR — {str(reason)[:80]}")

    r = api("POST", f"/_ml/anomaly_detectors/{jid}/_open", {})
    if not r.get("opened"):
        reason = r.get("error",{})
        if isinstance(reason, dict): reason = reason.get("reason","failed")
        print(f"  open {jid}: ERROR — {str(reason)[:80]}")

    fid = f"datafeed-{jid}"
    r = api("POST", f"/_ml/datafeeds/{fid}/_start", {})
    if not r.get("started"):
        reason = r.get("error",{})
        if isinstance(reason, dict): reason = reason.get("reason","failed")
        print(f"  start {fid}: ERROR — {str(reason)[:80]}")

print("  ML setup complete")
PYEOF

# ── Summary ───────────────────────────────────────────────────────────
echo ""
info "=========================================="
info " Workshop bootstrap complete!"
info "=========================================="
info " Elasticsearch: $ES_URL  (user: elastic / $ES_PASSWORD)"
info " Kibana:        $KIBANA_URL"
info ""
info " Results:"

TOTAL=$(curl -s -u "$ES_AUTH" "$ES_URL/_cat/count" 2>/dev/null | awk '{print $3}')
echo "   - $TOTAL total documents (expected: 12243)"

SO_COUNT=$(curl -s -u "$ES_AUTH" "$KIBANA_URL/api/saved_objects/_find?type=dashboard&per_page=1" \
  -H "kbn-xsrf: true" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo "?")
echo "   - $SO_COUNT dashboards (expected: 3)"

DV_COUNT=$(curl -s -u "$ES_AUTH" "$KIBANA_URL/api/data_views" \
  -H "kbn-xsrf: true" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
dvs = d.get('data_view', d.get('data_views', []))
print(len(dvs) if isinstance(dvs, list) else '?')" 2>/dev/null || echo "?")
echo "   - $DV_COUNT data views (expected: 28)"

ML_COUNT=$(curl -s -u "$ES_AUTH" "$ES_URL/_ml/anomaly_detectors/_stats" 2>/dev/null \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('jobs',[])))" 2>/dev/null || echo "?")
echo "   - $ML_COUNT ML jobs (expected: 4)"

echo ""
info "Log file: $LOG_FILE"
info "Cleanup:  ./scripts/cleanup-local.sh [--full]"
info "Open Kibana at $KIBANA_URL to start the workshop"
