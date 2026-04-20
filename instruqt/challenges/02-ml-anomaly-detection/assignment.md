---
slug: dissect-a-tool
title: "Explore Data and Dissect a Tool"
teaser: "Understand the data model and reverse-engineer an existing Agent Builder tool."
type: challenge
timelimit: 1500
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
      # Dissect a Tool

      Every Agent Builder tool is just three things:
      1. An **ID** — unique identifier
      2. A **description** — tells the AI when to use it
      3. An **ES|QL query** — the actual work it does

      In this challenge you will explore the data, then reverse-engineer an
      existing tool to understand exactly how it works.
---

# Challenge 2: Explore Data and Dissect a Tool

## Step 1: Explore the Data in Discover (10 min)

1. Open **Discover** (hamburger menu > Analytics > Discover)
2. Select the **gcp-resource-executions-*** data view
3. Set the time range to **Last 1 year**
4. Expand a document and find these key fields:

| Field | What It Means |
|-------|--------------|
| `drift_metrics.combined_drift_score` | % of resources allocated but unused |
| `resource_usage.cpu.avg_percent` | Actual average CPU utilization |
| `resource_usage.cpu.p95_percent` | 95th percentile CPU (peak baseline) |
| `metadata.team` | Team responsible for this VM |
| `cost_actual.total_cost_usd` | Cost of this execution run |
| `vm_info.vm_type_actual` | Machine type (e.g. n2-standard-16) |

**Question:** If `combined_drift_score` is 70, what does that mean in
practical terms?

## Step 2: Dissect a Tool via the API (10 min)

Open the **Terminal** tab and fetch all tools:

```bash
curl -s -u elastic:workshopAdmin1! \
  http://localhost:5601/api/agent_builder/tools \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
tools = json.load(sys.stdin)
for t in tools:
    if t.get('id') == 'kafeju.analyze_vm_usage_patterns':
        print('=== TOOL ANATOMY ===')
        print(f\"ID:          {t['id']}\")
        print(f\"Description: {t['description'][:100]}...\")
        print(f\"Query:\")
        print(t['configuration']['query'])
"
```

Study the output:
- The **ID** identifies the tool uniquely
- The **description** tells the AI *when* to use it (routing logic)
- The **ES|QL query** is what actually runs against Elasticsearch

## Step 3: Run the Query Yourself

Copy the ES|QL query from Step 2 and paste it into **Discover > ES|QL
mode** (toggle at the top of Discover). Run it.

You should see a table of VMs grouped by team and machine type, with
drift scores and CPU/memory usage. This is the raw data the agent sees.

Now go to the **AI Assistant** > **Kafeju** and ask:

> **"Show me VM usage patterns and where drift is highest."**

Compare the raw query results with the agent's narrative answer. The
tool provides data; the AI provides interpretation.

## Step 4: Spot the Gaps

Test these three questions in the Kafeju agent. For each, note whether
it gives a structured data answer or a vague/generic response:

1. **"Show me VM usage patterns"**
   - Expected: Works (uses `analyze_vm_usage_patterns`)

2. **"What's the cheapest region for my workload?"**
   - Expected: Fails — no tool covers regional pricing comparison

3. **"Find zombie VMs wasting money"**
   - Expected: Fails — no tool specifically targets low-CPU expensive VMs

Write down which questions fail. You will build the tools to fill these
gaps in the next challenges.

## Check Your Work

Before clicking **Check**, confirm:
- You ran the `analyze_vm_usage_patterns` ES|QL query in Discover
- You can name the 3 components of every tool (ID, description, query)
- You identified at least 1 question the agent cannot answer
