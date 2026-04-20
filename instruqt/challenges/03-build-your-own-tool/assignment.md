---
slug: build-zombie-vm-detector
title: "Build Your First Tool: Zombie VM Detector"
teaser: "Create a custom ES|QL-powered tool, register it, and wire it into the Kafeju agent."
type: challenge
timelimit: 2400
tabs:
  - title: Kibana
    type: service
    hostname: elastic-vm
    port: 5601
  - title: Terminal
    type: terminal
    hostname: elastic-vm
notes:
  - type: text
    contents: |
      # Build Your First Tool

      A "zombie VM" is a virtual machine running at near-zero CPU
      utilization on an expensive machine type — it costs money but does
      nothing useful. Every cloud team has them.

      You will now build a tool that finds them, register it via the API,
      wire it into the Kafeju agent, and test it with a natural-language
      prompt.

      The full loop: **Design → Write → Register → Wire → Test**
---

# Challenge 3: Build Your First Tool — Zombie VM Detector

## Step 1: Design the Query (5 min)

Think about what you need:
- **Source:** `gcp-resource-executions-*` (has CPU usage and cost data)
- **Filter:** CPU usage below 15% (barely alive)
- **Aggregate:** Group by team, VM type, resource name
- **Metrics:** Average CPU, drift score, total cost, occurrence count
- **Sort:** By cost descending (most expensive zombies first)

## Step 2: Test the Query in Discover (10 min)

Open **Kibana > Discover > ES|QL mode** and run:

```sql
FROM gcp-resource-executions-*
| WHERE resource_usage.cpu.avg_percent < 15
  AND vm_info.vm_type_actual IS NOT NULL
| STATS
    avg_cpu = AVG(resource_usage.cpu.avg_percent),
    avg_drift = AVG(drift_metrics.combined_drift_score),
    total_cost = SUM(cost_actual.total_cost_usd),
    occurrences = COUNT(*)
  BY metadata.team, vm_info.vm_type_actual, resource_name
| SORT total_cost DESC
| LIMIT 15
```

You should see results showing teams with low-CPU VMs and their costs.
If results appear, the query works and you can proceed.

**Tip:** If you get no results, check the time range (set to Last 1
year) and verify the field names by expanding a document in Discover.

## Step 3: Register the Tool (10 min)

Open the **Terminal** tab and run this command (copy the whole block):

```bash
curl -s -X POST http://localhost:5601/api/agent_builder/tools \
  -u elastic:workshopAdmin1! \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "participant.find_zombie_vms",
    "description": "Finds zombie VMs: machines with very low CPU usage (under 15%) that are wasting money. Shows which teams have idle resources ranked by total cost waste. Use when asked about zombie VMs, idle instances, or wasted resources.",
    "tags": ["participant", "infrastructure", "cost"],
    "configuration": {
      "query": "FROM gcp-resource-executions-*\n| WHERE resource_usage.cpu.avg_percent < 15\n  AND vm_info.vm_type_actual IS NOT NULL\n| STATS\n    avg_cpu = AVG(resource_usage.cpu.avg_percent),\n    avg_drift = AVG(drift_metrics.combined_drift_score),\n    total_cost = SUM(cost_actual.total_cost_usd),\n    occurrences = COUNT(*)\n  BY metadata.team, vm_info.vm_type_actual, resource_name\n| SORT total_cost DESC\n| LIMIT 15",
      "params": {}
    }
  }'
```

You should see a JSON response containing `"id": "participant.find_zombie_vms"`.

**Verify** it was created:

```bash
curl -s -u elastic:workshopAdmin1! \
  http://localhost:5601/api/agent_builder/tools \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
tools = json.load(sys.stdin)
participant_tools = [t for t in tools if 'participant' in t.get('id','')]
for t in participant_tools:
    print(f\"  {t['id']}: {t['description'][:60]}...\")
print(f'\nTotal participant tools: {len(participant_tools)}')
"
```

## Step 4: Wire It Into the Kafeju Agent (5 min)

The tool exists, but the Kafeju agent doesn't know about it yet. Add it:

```bash
curl -s -u elastic:workshopAdmin1! \
  http://localhost:5601/api/agent_builder/agents \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
agents = json.load(sys.stdin)['results']
kafeju = next(a for a in agents if a['id'] == 'kafuju')
tools = kafeju['configuration']['tools'][0]['tool_ids']
if 'participant.find_zombie_vms' not in tools:
    tools.append('participant.find_zombie_vms')
kafeju.pop('readonly', None)
kafeju.pop('type', None)
print(json.dumps(kafeju))
" > /tmp/agent-update.json

curl -s -X PUT http://localhost:5601/api/agent_builder/agents/kafuju \
  -u elastic:workshopAdmin1! \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d @/tmp/agent-update.json | python3 -c "
import json, sys
r = json.load(sys.stdin)
print(f\"Agent updated: {r.get('name', 'error')}\")
tools = r.get('configuration',{}).get('tools',[{}])[0].get('tool_ids',[])
print(f\"Total tools: {len(tools)}\")
print(f\"Includes zombie detector: {'participant.find_zombie_vms' in tools}\")
"
```

You should see `Includes zombie detector: True`.

## Step 5: Test Your Tool (10 min)

Go back to **Kibana > AI Assistant > Kafeju** and ask:

> **"Find zombie VMs — which expensive instances are sitting idle and wasting money?"**

The agent should invoke your `participant.find_zombie_vms` tool and
return a structured table of teams, VM types, CPU usage, and dollar
waste.

**The key comparison:** Remember in Challenge 1 when you asked this
same type of question and the agent couldn't answer? Now it produces
real data. **You built that capability in 10 minutes.**

## Check Your Work

The automated check verifies that:
1. A tool with ID containing `participant` exists
2. The Kafeju agent's tool list includes it
