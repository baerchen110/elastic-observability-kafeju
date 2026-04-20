#!/usr/bin/env bash
#
# Remove all workshop resources from a running Elasticsearch + Kibana deployment.
# This is the reverse of import-resources.sh.
#
# Usage:
#   ./scripts/cleanup-resources.sh <ES_URL> <KIBANA_URL> <USERNAME> <PASSWORD>
#
# Example:
#   ./scripts/cleanup-resources.sh \
#     http://elasticsearch-es-http.default.svc:9200 \
#     http://elasticsearch-es-http.default.svc:5601 \
#     elastic \
#     "${ELASTICSEARCH_PASSWORD}"
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES="$REPO_ROOT/resources"

if [ $# -lt 4 ]; then
  echo "Usage: $0 <ES_URL> <KIBANA_URL> <USERNAME> <PASSWORD>"
  exit 1
fi

ES_URL="${1%/}"
KIBANA_URL="${2%/}"
USERNAME="$3"
PASSWORD="$4"
AUTH="$USERNAME:$PASSWORD"

LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/cleanup-$(date +%Y%m%d-%H%M%S).log"
exec > >(stdbuf -oL tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ts()    { date +"%H:%M:%S"; }
info()  { echo -e "$(ts) ${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "$(ts) ${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "$(ts) ${RED}[FAIL]${NC}  $*"; echo ""; echo "Full log: $LOG_FILE"; exit 1; }

info "Log file: $LOG_FILE"
info "Cleaning up workshop resources from $ES_URL"

command -v curl    >/dev/null 2>&1 || fail "curl is not installed"
command -v python3 >/dev/null 2>&1 || fail "python3 is not installed"

# ── Verify connectivity ───────────────────────────────────────────────
ES_VERSION=$(curl -s -u "$AUTH" "$ES_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['version']['number'])" 2>/dev/null || true)
[ -z "$ES_VERSION" ] && fail "Cannot connect to Elasticsearch at $ES_URL"
info "Connected to Elasticsearch $ES_VERSION"

# ── 1. Stop and delete ML datafeeds + jobs ────────────────────────────
info "Removing ML jobs and datafeeds..."
if [ -f "$RESOURCES/ml/jobs.json" ]; then
  python3 - "$ES_URL" "$AUTH" "$RESOURCES/ml/jobs.json" << 'PYEOF'
import sys, json, subprocess

es, auth, jobpath = sys.argv[1], sys.argv[2], sys.argv[3]

with open(jobpath) as f:
    entries = json.load(f)

def api(method, path):
    r = subprocess.run(["curl", "-s", "-X", method, f"{es}{path}",
        "-u", auth, "-H", "Content-Type: application/json"],
        capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except:
        return {}

for entry in entries:
    jid = entry["job"]["job_id"]
    fid = f"datafeed-{jid}"

    api("POST", f"/_ml/datafeeds/{fid}/_stop?force=true")
    r = api("DELETE", f"/_ml/datafeeds/{fid}?force=true")
    ok = r.get("acknowledged", False)
    print(f"  datafeed {fid}: {'deleted' if ok else 'not found / already gone'}")

    api("POST", f"/_ml/anomaly_detectors/{jid}/_close?force=true")
    r = api("DELETE", f"/_ml/anomaly_detectors/{jid}?force=true")
    ok = r.get("acknowledged", False)
    print(f"  job {jid}: {'deleted' if ok else 'not found / already gone'}")
PYEOF
else
  warn "No resources/ml/jobs.json found, skipping"
fi

# ── 2. Delete Agent Builder tools ─────────────────────────────────────
info "Removing Agent Builder tools..."
if [ -f "$RESOURCES/kibana/agent-tools.json" ]; then
  python3 - "$KIBANA_URL" "$AUTH" "$RESOURCES/kibana/agent-tools.json" << 'PYEOF'
import sys, json, subprocess

kibana, auth, toolpath = sys.argv[1], sys.argv[2], sys.argv[3]

with open(toolpath) as f:
    tools = json.load(f)

deleted = 0
for t in tools:
    tid = t.get("id", "")
    if not tid:
        continue
    r = subprocess.run(["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
        "-X", "DELETE", f"{kibana}/api/agent_builder/tools/{tid}",
        "-u", auth, "-H", "kbn-xsrf: true"],
        capture_output=True, text=True)
    code = r.stdout.strip()
    if code in ("200", "204"):
        deleted += 1
        print(f"  {tid}: deleted")
    else:
        print(f"  {tid}: not found (HTTP {code})")

print(f"  Deleted {deleted}/{len(tools)} tools")
PYEOF
else
  warn "No resources/kibana/agent-tools.json found, skipping"
fi

# ── 3. Delete data views ─────────────────────────────────────────────
info "Removing data views..."
if [ -f "$RESOURCES/kibana/data-views.json" ]; then
  python3 - "$KIBANA_URL" "$AUTH" "$RESOURCES/kibana/data-views.json" << 'PYEOF'
import sys, json, subprocess

kibana, auth, dvpath = sys.argv[1], sys.argv[2], sys.argv[3]

with open(dvpath) as f:
    views = json.load(f)

deleted = 0
for v in views:
    vid = v.get("id", "")
    if not vid:
        continue
    r = subprocess.run(["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
        "-X", "DELETE", f"{kibana}/api/data_views/data_view/{vid}",
        "-u", auth, "-H", "kbn-xsrf: true"],
        capture_output=True, text=True)
    code = r.stdout.strip()
    if code in ("200", "204"):
        deleted += 1
    else:
        print(f"  {vid}: HTTP {code}")

print(f"  Deleted {deleted}/{len(views)} data views")
PYEOF
else
  warn "No resources/kibana/data-views.json found, skipping"
fi

# ── 4. Delete Kibana saved objects ────────────────────────────────────
info "Removing Kibana saved objects (dashboards, visualizations)..."
if [ -f "$RESOURCES/kibana/saved-objects.ndjson" ]; then
  python3 - "$KIBANA_URL" "$AUTH" "$RESOURCES/kibana/saved-objects.ndjson" << 'PYEOF'
import sys, json, subprocess

kibana, auth, sopath = sys.argv[1], sys.argv[2], sys.argv[3]

deleted = 0; total = 0
with open(sopath) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except:
            continue
        oid = obj.get("id", "")
        otype = obj.get("type", "")
        if not oid or not otype:
            continue
        total += 1
        r = subprocess.run(["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "-X", "DELETE", f"{kibana}/api/saved_objects/{otype}/{oid}",
            "-u", auth, "-H", "kbn-xsrf: true"],
            capture_output=True, text=True)
        code = r.stdout.strip()
        if code in ("200", "204"):
            deleted += 1

print(f"  Deleted {deleted}/{total} saved objects")
PYEOF
else
  warn "No resources/kibana/saved-objects.ndjson found, skipping"
fi

# ── 5. Delete Elasticsearch indices ───────────────────────────────────
info "Removing Elasticsearch indices..."
DELETED=0
for mapping_file in "$RESOURCES/elasticsearch/mappings"/*.json; do
  idx=$(basename "$mapping_file" .json)
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -u "$AUTH" "$ES_URL/$idx")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "  $idx: deleted"
    DELETED=$((DELETED + 1))
  elif [ "$HTTP_CODE" = "404" ]; then
    echo "  $idx: not found (already gone)"
  else
    warn "$idx: HTTP $HTTP_CODE"
  fi
done
info "Deleted $DELETED indices"

# ── Summary ───────────────────────────────────────────────────────────
echo ""
info "=========================================="
info " Cleanup complete!"
info "=========================================="
info ""
info "You can now re-import with:"
info "  ./scripts/import-resources.sh $ES_URL $KIBANA_URL $USERNAME <password>"
info ""
info "Log file: $LOG_FILE"
