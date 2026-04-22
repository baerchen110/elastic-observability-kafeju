#!/usr/bin/env bash
#
# Challenge 1 setup: re-prune Kibana data views so the participant's first
# view of Discover's data-view selector shows ONLY the 8 canonical
# workshop-* entries (matching what the assignment describes).
#
# track-setup.sh already runs this at track start, but we re-run it here
# in case demo/legacy views leaked in between track start and the
# participant reaching Challenge 1. The script is idempotent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTRUQT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -x "$INSTRUQT_DIR/data/prune-data-views.sh" ]; then
  bash "$INSTRUQT_DIR/data/prune-data-views.sh" || \
    echo "  (non-fatal) prune-data-views.sh returned non-zero; continuing."
else
  echo "No prune-data-views.sh found at $INSTRUQT_DIR/data/; skipping."
fi

echo "Challenge 1 setup complete."
