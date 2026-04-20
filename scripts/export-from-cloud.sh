#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES="$REPO_ROOT/resources"

source "$REPO_ROOT/.env"

ES_URL="${TARGET_URL}"
API_KEY="${TARGET_API_KEY}"
KIBANA_URL="${KIBANA_URL:-https://kafeju-9b0082.kb.europe-west1.gcp.cloud.es.io}"

es_api()  { curl -s -X "$1" "$ES_URL$2"     -H "Authorization: ApiKey $API_KEY" -H "Content-Type: application/json" ${3:+-d "$3"}; }
kb_api()  { curl -s -X "$1" "$KIBANA_URL$2"  -H "Authorization: ApiKey $API_KEY" -H "kbn-xsrf: true" -H "Content-Type: application/json" ${3:+-d "$3"}; }

INDICES=(
  gcp-billing-actual
  gcp-instance-inventory-2025.11.07
  gcp-instance-lifecycle
  gcp-instance-lifecycle-synthetic
  gcp-pricing-catalog
  gcp-requested-resources
  gcp-resource-executions-2025.11
  gcp-resource-executions-synthetic
  gcp-vm-pricing
  gcp-workload-requirements
  ml-predictions-anomalies
  ml-predictions-anomalies-synthetic
  ml-predictions-cost-forecast
  ml-predictions-growth
  ml-predictions-growth-summary
)

# ── 1. Index mappings ──────────────────────────────────────────────────
echo "=== Exporting index mappings ==="
mkdir -p "$RESOURCES/elasticsearch/mappings"
for idx in "${INDICES[@]}"; do
  es_api GET "/$idx/_mapping" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
idx = list(d.keys())[0]
json.dump(d[idx]['mappings'], sys.stdout, indent=2)
print()
" > "$RESOURCES/elasticsearch/mappings/$idx.json"
  echo "  $idx"
done

# ── 2. Seed data (scroll → bulk NDJSON) ───────────────────────────────
echo ""
echo "=== Exporting seed data ==="
mkdir -p "$RESOURCES/elasticsearch/seed-data"
for idx in "${INDICES[@]}"; do
  python3 - "$ES_URL" "$API_KEY" "$idx" "$RESOURCES/elasticsearch/seed-data/$idx.ndjson" << 'PYEOF'
import sys, json, subprocess

es, key, index, outpath = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def api(method, path, body=None):
    cmd = ["curl", "-s", "-X", method, f"{es}{path}",
           "-H", f"Authorization: ApiKey {key}",
           "-H", "Content-Type: application/json"]
    if body:
        cmd += ["-d", json.dumps(body)]
    return json.loads(subprocess.run(cmd, capture_output=True, text=True).stdout)

all_docs = []
r = api("POST", f"/{index}/_search?scroll=2m", {"size": 5000, "query": {"match_all": {}}})
hits = r.get("hits", {}).get("hits", [])
scroll_id = r.get("_scroll_id")
all_docs.extend(hits)

while hits:
    r = api("POST", "/_search/scroll", {"scroll": "2m", "scroll_id": scroll_id})
    hits = r.get("hits", {}).get("hits", [])
    scroll_id = r.get("_scroll_id")
    all_docs.extend(hits)

if scroll_id:
    api("DELETE", "/_search/scroll", {"scroll_id": scroll_id})

with open(outpath, "w") as f:
    for doc in all_docs:
        action = {"index": {"_index": index, "_id": doc["_id"]}}
        f.write(json.dumps(action) + "\n")
        f.write(json.dumps(doc["_source"]) + "\n")

print(f"  {index}: {len(all_docs)} docs")
PYEOF
done

# ── 3. Kibana saved objects (dashboards + deep refs) ──────────────────
echo ""
echo "=== Exporting Kibana saved objects ==="
mkdir -p "$RESOURCES/kibana"
kb_api POST "/api/saved_objects/_export" \
  '{"type":["dashboard"],"includeReferencesDeep":true}' \
  > "$RESOURCES/kibana/saved-objects.ndjson"
LINES=$(wc -l < "$RESOURCES/kibana/saved-objects.ndjson" | tr -d ' ')
echo "  saved-objects.ndjson: $LINES lines"

# ── 4. Data views ─────────────────────────────────────────────────────
echo ""
echo "=== Exporting data views ==="
python3 - "$KIBANA_URL" "$API_KEY" "$RESOURCES/kibana/data-views.json" << 'PYEOF'
import sys, json, subprocess

kibana, key, outpath = sys.argv[1], sys.argv[2], sys.argv[3]

def kb(method, path, body=None):
    cmd = ["curl", "-s", "-X", method, f"{kibana}{path}",
           "-H", f"Authorization: ApiKey {key}",
           "-H", "kbn-xsrf: true", "-H", "Content-Type: application/json"]
    if body:
        cmd += ["-d", json.dumps(body)]
    return json.loads(subprocess.run(cmd, capture_output=True, text=True).stdout)

listing = kb("GET", "/api/data_views")
dv_list = listing.get("data_view", listing.get("data_views", []))

full_views = []
for dv in dv_list:
    dvid = dv["id"]
    detail = kb("GET", f"/api/data_views/data_view/{dvid}")
    view = detail.get("data_view", detail)
    full_views.append({
        "id": view.get("id", dvid),
        "title": view.get("title", ""),
        "name": view.get("name", ""),
        "timeFieldName": view.get("timeFieldName", ""),
        "sourceFilters": view.get("sourceFilters", []),
        "fieldFormats": view.get("fieldFormats", {}),
        "runtimeFieldMap": view.get("runtimeFieldMap", {}),
        "allowNoIndex": view.get("allowNoIndex", False),
    })

with open(outpath, "w") as f:
    json.dump(full_views, f, indent=2)
    f.write("\n")

print(f"  data-views.json: {len(full_views)} views")
PYEOF

# ── 5. ML jobs + datafeeds ────────────────────────────────────────────
echo ""
echo "=== Exporting ML jobs ==="
mkdir -p "$RESOURCES/ml"
python3 - "$ES_URL" "$API_KEY" "$RESOURCES/ml/jobs.json" << 'PYEOF'
import sys, json, subprocess

es, key, outpath = sys.argv[1], sys.argv[2], sys.argv[3]

def api(path):
    r = subprocess.run(["curl", "-s", f"{es}{path}",
        "-H", f"Authorization: ApiKey {key}"], capture_output=True, text=True)
    return json.loads(r.stdout)

STRIP_JOB = {"job_version", "create_time", "model_snapshot_id", "model_snapshot_min_version",
             "finished_time", "job_type", "node", "open_time"}
STRIP_FEED = {"authorization", "query_delay"}

jobs_resp = api("/_ml/anomaly_detectors")
feeds_resp = api("/_ml/datafeeds")

feed_map = {}
for f in feeds_resp.get("datafeeds", []):
    for k in STRIP_FEED:
        f.pop(k, None)
    feed_map[f["job_id"]] = f

export = []
for j in jobs_resp.get("jobs", []):
    for k in STRIP_JOB:
        j.pop(k, None)
    if "datafeed_config" in j:
        dc = j["datafeed_config"]
        for k in STRIP_FEED:
            dc.pop(k, None)
    export.append({
        "job": j,
        "datafeed": feed_map.get(j["job_id"])
    })

with open(outpath, "w") as f:
    json.dump(export, f, indent=2)
    f.write("\n")

print(f"  jobs.json: {len(export)} jobs")
PYEOF

# ── 6. Agent Builder tools ────────────────────────────────────────────
echo ""
echo "=== Exporting Agent Builder tools ==="
python3 - "$KIBANA_URL" "$API_KEY" "$RESOURCES/kibana/agent-tools.json" \
         "$REPO_ROOT/scripts/tool-definitions-real.json" << 'PYEOF'
import sys, json, subprocess

kibana, key, outpath, fallback = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

r = subprocess.run(["curl", "-s", f"{kibana}/api/agent_builder/tools",
    "-H", f"Authorization: ApiKey {key}", "-H", "kbn-xsrf: true"],
    capture_output=True, text=True)
try:
    data = json.loads(r.stdout)
    tools = data if isinstance(data, list) else data.get("tools", data.get("data", []))
except:
    tools = []

if not tools:
    with open(fallback) as f:
        tools = json.load(f)
    print(f"  API returned empty — using fallback ({len(tools)} tools)")

for t in tools:
    t.pop("readonly", None)

with open(outpath, "w") as f:
    json.dump(tools, f, indent=2)
    f.write("\n")

print(f"  agent-tools.json: {len(tools)} tools")
PYEOF

echo ""
echo "=== Export complete ==="
echo "Resources written to: $RESOURCES"
find "$RESOURCES" -type f | sort | while read -r f; do
  SIZE=$(wc -c < "$f" | tr -d ' ')
  echo "  $f ($SIZE bytes)"
done
