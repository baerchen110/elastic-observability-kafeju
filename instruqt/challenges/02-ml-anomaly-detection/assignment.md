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
      # Explore Data and Dissect a Tool

      In Challenge 1, you explored **Kafeju** and saw that its answers depend
      on its tools — and where those tools end, the agent struggles.

      Now you go under the hood. Every Agent Builder tool is three things:
      1. An **ID** — a unique identifier
      2. A **description** — tells the model when to use the tool
      3. An **ES|QL query** — the work that runs against Elasticsearch

      In this challenge, you explore the data in Discover, then
      reverse-engineer an existing tool so you know exactly how it works.
---

# Challenge 2: Explore Data and Dissect a Tool

## Step 1: Explore the Data in Discover

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

## Step 2: Dissect a Tool via the API

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
- The **description** tells the model *when* to use it (routing logic)
- The **ES|QL query** is what actually runs against Elasticsearch

## Step 3: Run the Query Yourself

Copy the ES|QL query from Step 2 and paste it into **Discover** > **ES|QL**
(toggle at the top of Discover). Run it.

You should see a table of VMs grouped by team and machine type, with
drift scores and CPU/memory usage. This is the raw data the agent sees.

Now open the **AI Assistant**, choose **Kafeju**, and ask:

> **"Show me VM usage patterns and where drift is highest."**

Compare the raw query results with the agent's narrative answer. The
tool provides data; the AI provides interpretation.

## Step 4: Spot the Gaps

In the Kafeju agent, try these three questions. For each one, note whether
you get a structured, data-backed answer or something vague or generic:

1. **"Show me VM usage patterns"**  
   Expected: Works — uses `analyze_vm_usage_patterns`.

2. **"What's the cheapest region for my workload?"**  
   Expected: Fails — no tool covers regional pricing comparison.

3. **"Find zombie VMs wasting money"**  
   Expected: Fails — no tool specifically targets low-CPU, expensive VMs.

Write down which questions fail. In later challenges, you will build tools
to fill these gaps.

## Check Your Work

Before clicking **Check**, confirm you:
- Ran the `analyze_vm_usage_patterns` ES|QL query in Discover
- Can name the three parts of every tool (ID, description, ES|QL query)
- Identified at least one question the agent cannot answer well
