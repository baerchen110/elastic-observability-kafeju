#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-workshopAdmin1!}"
AGENT_FILE="$SCRIPT_DIR/kafeju-agent.json"

echo "Creating Kafeju agent on $KIBANA_URL..."
python3 -c "
import json, subprocess, sys
kibana = '$KIBANA_URL'
auth = '$ES_USER:$ES_PASS'
with open('$AGENT_FILE') as f:
    agents = json.load(f)
for a in agents:
    a.pop('readonly', None)
    a.pop('type', None)
    r = subprocess.run(
        ['curl', '-s', '-X', 'POST', f'{kibana}/api/agent_builder/agents',
         '-u', auth, '-H', 'kbn-xsrf: true', '-H', 'Content-Type: application/json',
         '-d', json.dumps(a)],
        capture_output=True, text=True,
    )
    print(r.stdout[:2000])
    try:
        resp = json.loads(r.stdout)
        if resp.get('id'):
            print('OK agent', resp['id'])
        else:
            print('FAIL', resp)
            sys.exit(1)
    except Exception as e:
        print('FAIL parse', e, r.stdout[:500])
        sys.exit(1)
"
