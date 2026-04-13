---
slug: build-your-own-tool
title: "Build Your Own Agent Builder Tool"
teaser: "Create a custom ES|QL-powered tool and invoke it through natural language."
type: challenge
timelimit: 1200
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
      # Build Your Own Tool

      Every Agent Builder tool is just three things:
      1. An **ID** — unique identifier
      2. A **description** — tells the AI *when* to use it
      3. An **ES|QL query** — the actual work it does

      In this challenge, you will examine an existing tool, then build your
      own from scratch.
---

# Challenge 3: Build Your Own Agent Builder Tool

You have seen how powerful pre-built tools are. Now it is time to create
your own.

## Step 1: Examine an Existing Tool

Open the **Terminal** tab and run:

```bash
curl -s -u elastic:workshopAdmin1! \
  http://localhost:5601/api/agent_builder/tools \
  | python3 -m json.tool | head -50
```

This shows all registered tools. Find one with `type: "esql"` and look at its
`configuration.query` field. Notice how the ES|QL query is self-contained —
it reads from an index, aggregates data, and returns results.

## Step 2: Build a Zombie VM Detector

Your goal: create a tool that finds VMs with extremely low CPU usage running
on expensive machine types — the "zombie VMs" that waste money.

Here is the ES|QL query to use:

```sql
FROM gcp-resource-executions-workshop
| WHERE resource_usage.cpu.avg_percent < 15
  AND vm_info.vm_type_actual.keyword IN ("n2-standard-16", "n2-standard-32", "c2-standard-8")
| STATS
    avg_cpu = AVG(resource_usage.cpu.avg_percent),
    avg_drift = AVG(drift_metrics.combined_drift_score),
    total_cost = SUM(cost_actual.total_cost_usd),
    occurrences = COUNT(*)
  BY metadata.team.keyword,
     vm_info.vm_type_actual.keyword,
     resource_name.keyword
| SORT total_cost DESC
| LIMIT 15
```

## Step 3: Create the Tool via the Terminal

Run this command in the **Terminal** tab (it is a single command — copy the
whole block):

```bash
curl -s -X POST http://localhost:5601/api/agent_builder/tools \
  -u elastic:workshopAdmin1! \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "participant.find_zombie_vms",
    "type": "esql",
    "description": "Finds zombie VMs: machines with very low CPU usage (<15%) running on expensive instance types. Shows which teams are wasting money on idle resources. Use when asked about zombie VMs, idle instances, or wasted resources.",
    "tags": ["participant", "infrastructure", "cost"],
    "configuration": {
      "query": "FROM gcp-resource-executions-workshop\n| WHERE resource_usage.cpu.avg_percent < 15\n  AND vm_info.vm_type_actual.keyword IN (\"n2-standard-16\", \"n2-standard-32\", \"c2-standard-8\")\n| STATS\n    avg_cpu = AVG(resource_usage.cpu.avg_percent),\n    avg_drift = AVG(drift_metrics.combined_drift_score),\n    total_cost = SUM(cost_actual.total_cost_usd),\n    occurrences = COUNT(*)\n  BY metadata.team.keyword,\n     vm_info.vm_type_actual.keyword,\n     resource_name.keyword\n| SORT total_cost DESC\n| LIMIT 15",
      "params": {}
    }
  }'
```

You should see a response containing `"id": "participant.find_zombie_vms"`.

## Step 4: Test Your Tool

Go back to the **Kibana** tab and open the **AI Assistant**. Ask:

> **Find zombie VMs — which expensive instances are sitting idle?**

The AI should invoke your new `find_zombie_vms` tool and return results
showing `devops-infra` running n2-standard-32 instances at single-digit
CPU utilization.

## Step 5 (Bonus): Design Your Own Tool

Think of another analysis you would find useful. Some ideas:

- **Regional Cost Comparison**: Which region is cheapest for each VM type?
  (query `gcp-pricing-catalog`)
- **Failed Execution Finder**: Which workloads fail most often?
  (filter `execution_time.status == "failed"` on executions)
- **Team Cost Breakdown**: Total cost per team per week
  (aggregate `cost_actual.total_cost_usd` with `DATE_TRUNC`)

Create it using the same `curl` pattern from Step 3, with your own ID
(e.g., `participant.my_custom_tool`), description, and ES|QL query.

## Check Your Work

The check verifies that a tool with ID starting with `participant.` exists
on this Kibana instance.
