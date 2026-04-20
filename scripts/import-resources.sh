#!/usr/bin/env bash
#
# Import workshop resources into a running Elasticsearch + Kibana deployment.
#
# Usage:
#   ./scripts/import-resources.sh <ES_URL> <KIBANA_URL> <USERNAME> <PASSWORD>
#
# Example (Elastic Cloud):
#   ./scripts/import-resources.sh \
#     https://my-cluster.es.europe-west1.gcp.cloud.es.io:443 \
#     https://my-cluster.kb.europe-west1.gcp.cloud.es.io \
#     elastic \
#     MySecretPassword
#
# Example (local):
#   ./scripts/import-resources.sh \
#     http://localhost:9200 \
#     http://localhost:5601 \
#     elastic \
#     workshopAdmin1!
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES="$REPO_ROOT/resources"

if [ $# -lt 4 ]; then
  echo "Usage: $0 <ES_URL> <KIBANA_URL> <USERNAME> <PASSWORD>"
  echo ""
  echo "  ES_URL      Elasticsearch endpoint  (e.g. https://host:9200)"
  echo "  KIBANA_URL  Kibana endpoint          (e.g. https://host:5601)"
  echo "  USERNAME    Elasticsearch username    (e.g. elastic)"
  echo "  PASSWORD    Elasticsearch password"
  exit 1
fi

ES_URL="${1%/}"
KIBANA_URL="${2%/}"
USERNAME="$3"
PASSWORD="$4"
AUTH="$USERNAME:$PASSWORD"

# ── Logging ───────────────────────────────────────────────────────────
LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/import-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ts()    { date +"%H:%M:%S"; }
info()  { echo -e "$(ts) ${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "$(ts) ${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "$(ts) ${RED}[FAIL]${NC}  $*"; echo ""; echo "Full log: $LOG_FILE"; exit 1; }

info "Log file: $LOG_FILE"

command -v curl    >/dev/null 2>&1 || fail "curl is not installed"
command -v python3 >/dev/null 2>&1 || fail "python3 is not installed"

# ── Pre-flight: verify connectivity ───────────────────────────────────
info "Verifying Elasticsearch at $ES_URL..."
ES_RESP=$(curl -s -u "$AUTH" "$ES_URL" 2>/dev/null)
ES_VERSION=$(echo "$ES_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['version']['number'])" 2>/dev/null || true)
if [ -z "$ES_VERSION" ]; then
  warn "Response was: $ES_RESP"
  fail "Cannot connect to Elasticsearch at $ES_URL"
fi
info "Connected to Elasticsearch $ES_VERSION"

info "Verifying Kibana at $KIBANA_URL..."
KB_RESP=$(curl -s -u "$AUTH" "$KIBANA_URL/api/status" 2>/dev/null)
KB_OK=$(echo "$KB_RESP" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('status',{}).get('overall',{}).get('level', d.get('version',{}).get('number','')))" 2>/dev/null || true)
if [ -z "$KB_OK" ]; then
  warn "Response was: $(echo "$KB_RESP" | head -c 200)"
  fail "Cannot connect to Kibana at $KIBANA_URL"
fi
info "Kibana is available ($KB_OK)"

# ── 1. Create indices with explicit mappings ──────────────────────────
info "Creating indices with mappings..."
IDX_CREATED=0; IDX_SKIPPED=0; IDX_FAILED=0
for mapping_file in "$RESOURCES/elasticsearch/mappings"/*.json; do
  idx=$(basename "$mapping_file" .json)
  BODY=$(python3 -c "
import json, sys
with open('$mapping_file') as f: m = json.load(f)
json.dump({'mappings': m, 'settings': {'number_of_shards': 1, 'number_of_replicas': 1}}, sys.stdout)
")
  RESP_FILE=$(mktemp)
  HTTP_CODE=$(curl -s -o "$RESP_FILE" -w "%{http_code}" -X PUT -u "$AUTH" \
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

# ── 2. Bulk-load seed data ────────────────────────────────────────────
info "Loading seed data..."
TOTAL_LOADED=0; TOTAL_ERRORS=0
for data_file in "$RESOURCES/elasticsearch/seed-data"/*.ndjson; do
  idx=$(basename "$data_file" .ndjson)
  DOC_COUNT=$(( $(wc -l < "$data_file" | tr -d ' ') / 2 ))

  RESP=$(curl -s -X POST -u "$AUTH" "$ES_URL/_bulk" \
    -H "Content-Type: application/x-ndjson" \
    --data-binary "@$data_file")
  ERRORS=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('errors',True))" 2>/dev/null)
  if [ "$ERRORS" = "False" ]; then
    echo "  $idx: $DOC_COUNT docs"
    TOTAL_LOADED=$((TOTAL_LOADED + DOC_COUNT))
  else
    ERROR_COUNT=$(echo "$RESP" | python3 -c "
import sys,json
d=json.load(sys.stdin)
items = d.get('items',[])
errs = [i for i in items if 'error' in i.get('index',i.get('create',{}))]
print(len(errs))
for e in errs[:3]:
    op = e.get('index', e.get('create',{}))
    print(f'    {op.get(\"_index\",\"?\")}: {op.get(\"error\",{}).get(\"reason\",\"?\")[:80]}')
" 2>/dev/null)
    warn "$idx: $DOC_COUNT docs, errors: $ERROR_COUNT"
    TOTAL_LOADED=$((TOTAL_LOADED + DOC_COUNT))
    TOTAL_ERRORS=$((TOTAL_ERRORS + $(echo "$ERROR_COUNT" | head -1)))
  fi
done
info "Loaded $TOTAL_LOADED total documents ($TOTAL_ERRORS errors)"

curl -s -X POST -u "$AUTH" "$ES_URL/_refresh" >/dev/null

# ── 3. Import Kibana saved objects ────────────────────────────────────
info "Importing Kibana saved objects (dashboards, visualizations)..."
IMPORT_RESP=$(curl -s -X POST -u "$AUTH" \
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

# ── 4. Create data views ─────────────────────────────────────────────
info "Creating data views..."
python3 - "$KIBANA_URL" "$AUTH" "$RESOURCES/kibana/data-views.json" << 'PYEOF'
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

# ── 5. Create Agent Builder tools ─────────────────────────────────────
info "Creating Agent Builder tools..."
python3 - "$KIBANA_URL" "$AUTH" "$RESOURCES/kibana/agent-tools.json" << 'PYEOF'
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

# ── 6. Create ML jobs + datafeeds ─────────────────────────────────────
info "Creating ML jobs and datafeeds..."
python3 - "$ES_URL" "$AUTH" "$RESOURCES/ml/jobs.json" << 'PYEOF'
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
info " Import complete!"
info "=========================================="
info " Elasticsearch: $ES_URL"
info " Kibana:        $KIBANA_URL"
info ""
info " Results:"

TOTAL=$(curl -s -u "$AUTH" "$ES_URL/_cat/count" 2>/dev/null | awk '{print $3}')
echo "   - $TOTAL total documents (expected: 12243)"

SO_COUNT=$(curl -s -u "$AUTH" "$KIBANA_URL/api/saved_objects/_find?type=dashboard&per_page=1" \
  -H "kbn-xsrf: true" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo "?")
echo "   - $SO_COUNT dashboards (expected: 3)"

DV_COUNT=$(curl -s -u "$AUTH" "$KIBANA_URL/api/data_views" \
  -H "kbn-xsrf: true" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
dvs = d.get('data_view', d.get('data_views', []))
print(len(dvs) if isinstance(dvs, list) else '?')" 2>/dev/null || echo "?")
echo "   - $DV_COUNT data views (expected: 28)"

ML_COUNT=$(curl -s -u "$AUTH" "$ES_URL/_ml/anomaly_detectors/_stats" 2>/dev/null \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('jobs',[])))" 2>/dev/null || echo "?")
echo "   - $ML_COUNT ML jobs (expected: 4)"

echo ""
info "Log file: $LOG_FILE"
info "Open Kibana at $KIBANA_URL"
