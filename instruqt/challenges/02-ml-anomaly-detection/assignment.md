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

      A warning up front: a confident-sounding answer from the agent is
      **not** the same as a grounded one. Modern LLMs will happily
      paraphrase whatever tool result is closest to the question — even
      when the right tool doesn't exist. In Step 4 you'll learn to
      *verify* every answer against the actual tool call and the raw
      data.
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

## Step 4: Spot the Gaps — Don't Trust, Verify

A modern LLM will **almost never say "I can't answer that."** It will
pick the closest-looking tool, run it, and re-narrate the result as if
it were the answer you asked for. Your job in this step is to tell
the difference between a **grounded** answer and a **confabulated**
one.

For each prompt below:

1. Ask it in the Kafeju agent.
2. In the chat, open the **tool-call / reasoning panel** (usually
   "Completed reasoning" or a tool-invocation dropdown under the
   answer). Note:
   - *Which* `kafeju.*` tool was actually called?
   - Was **any** tool called, or did the model answer from thin air?
3. Pull up that tool in the **Agent Builder** UI (or the curl output
   from Step 2) and read its **description** and **ES|QL query**.
   Ask yourself: *does this query actually compute what the user asked
   for?*
4. Cross-check with the one-liner ES|QL suggested below in **Discover
   > ES|QL mode**.

### Prompt A — baseline (grounded)

> **"Show me VM usage patterns and where drift is highest."**

- **Expected tool:** `kafeju.analyze_vm_usage_patterns`.
- **Verify in Discover:**
  ```esql
  FROM gcp-resource-executions-*
  | STATS avg_drift = AVG(drift_metrics.combined_drift_score) BY metadata.team
  | SORT avg_drift DESC
  ```
- **You should see:** the same team ranking the agent narrates. ✅
  Grounded.

### Prompt B — regional pricing (gap)

> **"Compare the hourly price of `n2-standard-8` across at least three
> GCP regions and rank them from cheapest to most expensive."**

The agent will almost certainly give you a confident answer like
*"us-central1 is the cheapest."* Don't trust it — verify:

- **Check the tool-call panel:** did any tool filter on `region`? (No
  existing `kafeju.*` tool does.)
- **Verify in Discover:**
  ```esql
  FROM gcp-pricing-catalog
  | WHERE machine_type == "n2-standard-8"
  | STATS n = COUNT(*) BY region
  ```
- **You should see:** only **one** region (`us-central1`) in the
  catalog. The agent *invented* a multi-region comparison — the
  dataset can't support one. ❌ Confabulated.

### Prompt C — zombie VMs (gap)

> **"List zombie VMs: instances where P95 CPU < 10%, monthly cost >
> $200, and the execution has been running for more than 168 hours.
> Return the top 10 by cost."**

The agent may respond with a nicely formatted list of high-drift VMs.
Read carefully — those filters were probably never applied.

- **Check the tool-call panel:** which tool was called? Likely
  `analyze_vm_usage_patterns` or `detect_resource_anomalies`.
- **Read its ES|QL (from Step 2):** it does **not** filter by
  `resource_usage.cpu.p95_percent < 10`, it does **not** threshold on
  `cost_actual.total_cost_usd > 200`, and it does **not** check
  `execution_time.duration_hours > 168`. It just returns the same
  high-drift VMs it always does, re-labeled.
- **Verify in Discover:**
  ```esql
  FROM gcp-resource-executions-*
  | WHERE resource_usage.cpu.p95_percent < 10
    AND cost_actual.total_cost_usd > 200
    AND execution_time.duration_hours > 168
  | STATS cost = SUM(cost_actual.total_cost_usd) BY metadata.workload_name, vm_info.vm_type_actual
  | SORT cost DESC
  | LIMIT 10
  ```
- **Compare the two lists.** If the agent's list doesn't match this
  query's output, the agent confabulated. ❌

### Takeaway

For Prompts B and C the gap isn't that the agent errored out — it's
that **no tool in the toolbox actually computes what was asked**, so
the agent improvised. In the next challenges you will build the
missing tools so these questions can be answered *from real data*,
not from the model's imagination.

## Check Your Work

Before clicking **Check**, confirm:
- You ran the `analyze_vm_usage_patterns` ES|QL query in Discover.
- You can name the 3 components of every tool (ID, description, query).
- For each of the three prompts in Step 4 you inspected the
  **tool-call panel** and can say which `kafeju.*` tool (if any) was
  invoked.
- You confirmed the regional-pricing gap with `STATS BY region` on
  `gcp-pricing-catalog` (only one region exists).
- You confirmed the zombie-VM gap by comparing the agent's answer to
  the P95/cost/duration ES|QL query.
