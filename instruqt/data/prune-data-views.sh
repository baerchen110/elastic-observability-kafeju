#!/usr/bin/env bash
#
# Prune Kibana data views so only the 8 canonical workshop-* data views remain.
#
# Safe to run any number of times. Called from:
#   - track-setup (via create-data-views.sh) at track start
#   - per-challenge setup.sh (e.g. Challenge 1) to guarantee a clean
#     Discover data-view selector even if demo/legacy views leaked in
#
# The canonical whitelist MUST stay in sync with create-data-views.sh.
set -euo pipefail

KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-workshopAdmin1!}"

KEEP_IDS_CSV="${KEEP_IDS_CSV:-workshop-executions,workshop-anomalies,workshop-growth,workshop-pricing,workshop-lifecycle,workshop-billing,workshop-all-gcp,workshop-all-ml}"

echo "Pruning non-canonical data views on $KIBANA_URL..."

KIBANA_URL="$KIBANA_URL" ES_USER="$ES_USER" ES_PASS="$ES_PASS" \
  KEEP_IDS_CSV="$KEEP_IDS_CSV" \
  python3 - <<'PYEOF'
import json
import os
import subprocess

kibana = os.environ["KIBANA_URL"].rstrip("/")
auth = f'{os.environ["ES_USER"]}:{os.environ["ES_PASS"]}'
keep = set(os.environ["KEEP_IDS_CSV"].split(","))


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


# Collect data-view IDs from two sources and dedupe:
#   1. /api/data_views                       (Data Views API)
#   2. /api/saved_objects/_find?type=index-pattern (belt + suspenders)
found = {}  # id -> title (best-effort)

r = run(["curl", "-sS", "-u", auth, "-H", "kbn-xsrf: true",
         f"{kibana}/api/data_views"])
try:
    for v in json.loads(r.stdout).get("data_view", []) or []:
        vid = v.get("id", "")
        if vid:
            found[vid] = v.get("title", v.get("name", ""))
except Exception:
    print(f"  WARN: /api/data_views did not return JSON ({r.stdout[:120]!r})")

# saved_objects fallback: paginates, may return deleted-but-orphaned objects
page = 1
while True:
    r = run(["curl", "-sS", "-u", auth, "-H", "kbn-xsrf: true",
             f"{kibana}/api/saved_objects/_find"
             f"?type=index-pattern&per_page=100&page={page}"])
    try:
        body = json.loads(r.stdout)
    except Exception:
        print(f"  WARN: saved_objects _find page {page} not JSON")
        break
    objs = body.get("saved_objects", []) or []
    for o in objs:
        oid = o.get("id", "")
        if oid and oid not in found:
            found[oid] = o.get("attributes", {}).get("title", "")
    if len(objs) < 100:
        break
    page += 1
    if page > 20:
        break  # safety

if not found:
    print("  No data views found (nothing to prune).")
    raise SystemExit(0)

deleted = []
kept = []
failed = []
for vid, title in sorted(found.items()):
    if vid in keep:
        kept.append(vid)
        continue
    d = run(["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}",
             "-X", "DELETE", "-u", auth, "-H", "kbn-xsrf: true",
             f"{kibana}/api/data_views/data_view/{vid}"])
    code = d.stdout.strip()
    if code in ("200", "204", "404"):
        deleted.append((vid, title, code))
    else:
        failed.append((vid, title, code))

print(f"  Kept {len(kept)}: {', '.join(sorted(kept))}")
if deleted:
    print(f"  Deleted {len(deleted)}:")
    for vid, title, code in deleted:
        label = f"{vid}"
        if title and title != vid:
            label += f"  [{title}]"
        print(f"    - {label}  (HTTP {code})")
else:
    print("  Nothing to delete.")
if failed:
    print(f"  FAILED to delete {len(failed)}:")
    for vid, title, code in failed:
        print(f"    ! {vid}  [{title}]  (HTTP {code})")
    raise SystemExit(1)
PYEOF

echo "Prune complete."
