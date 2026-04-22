---
slug: from-consumer-to-creator
title: "From Consumer to Creator"
teaser: "Get familiar with the data and dashboards, then see what the Kafeju agent can — and can't — do."
type: challenge
timelimit: 1500
tabs:
  - title: Kibana
    type: service
    hostname: elastic-vm
    port: 5601
notes:
  - type: text
    contents: |
      # From Consumer to Creator

      In Workshop 1, you used the Observability AI Assistant with built-in
      tools. The tools were pre-made — you were a **consumer** of AI.

      In this workshop, you become a **creator**. You will build your own
      tools and wire them into a custom agent called **Kafeju** — a GCP
      cost-optimization agent that detects resource drift and recommends
      rightsizing.

      Before touching the agent, we'll get familiar with the **data** it
      works on, using Discover and the pre-built dashboards. Once you
      know what the raw data looks like, the agent's answers will make
      much more sense.
---

# Challenge 1: From Consumer to Creator

## About this challenge

**Kafeju** (a coffee-themed codename — think *café* for your cloud bill)
is the custom agent you will extend during this workshop. It analyzes
Google Cloud VM usage, detects **resource drift** (the gap between what a
team *asked for* and what they *actually use*), and recommends
rightsizing to cut cost.

The environment has already been pre-loaded for you with:

- **~12,000 GCP resource-execution records** — every VM run with
  allocated vs actual CPU/memory, cost, team, zone, and machine type.
- **GCP pricing catalog** — hourly prices for every machine family and
  region.
- **ML anomaly + growth predictions** — output of four ML jobs that
  score VMs for unusual behavior and forecast capacity.
- **GCP billing records** — daily cost roll-ups.
- **Three pre-built dashboards** that visualize the above.

In this challenge you will **explore that data first**, then meet the
Kafeju agent and find where its current tools fall short.

---

## Step 1: Explore the Data in Discover

Before asking an AI anything, *you* should know what data exists.

1. Open the **Kibana** tab
2. In the data view selector (top-left), pick **GCP Resource
   Executions**.
3. Expand one document and skim these fields:

| Field | What it means |
|-------|--------------|
| `metadata.team` | Team that owns the VM |
| `vm_info.vm_type_actual` | Machine type actually running (e.g. `n2-standard-16`) |
| `resource_usage.cpu.avg_percent` | Actual average CPU utilization |
| `resource_usage.cpu.p95_percent` | 95th-percentile CPU (peak baseline) |
| `drift_metrics.combined_drift_score` | % of allocated resources that are *not* being used |
| `cost_actual.total_cost_usd` | Cost of that execution |

4. Now switch the data view to **GCP Pricing Catalog** and expand
   a document. Note how each machine type has an hourly price per
   region.
5. Switch once more to **ML Anomalies**. Each record has a
   `record_score` (how anomalous) and the VM / team it belongs to.

> **What to notice:** Three *independent* data views tell you the
> story — actual usage (**GCP Resource Executions**), pricing
> (**GCP Pricing Catalog**), and ML anomaly scores (**ML
> Anomalies**). A good agent tool has to join across them. Any
> question like *"cheapest region for n2-standard-8"* must reach
> into the pricing catalog, not the executions data.

---

## Step 2: Tour the Pre-Built Dashboards

Now let's see the same data visually. Open the hamburger menu >
**Analytics** > **Dashboard** and open each dashboard in turn. (Make
sure the time picker is still on **Last 1 year**.)

### 2a. GCP Resource Drift Overview

Panels show:
- Average drift % across the fleet
- Drift broken down by **team**, **machine type**, and **zone**

> **What to notice:** Drift is *not* evenly distributed. A few teams
> and a few machine types dominate the waste. These are the exact VMs
> a cost-optimization agent should flag first.

### 2b. Cost Optimization Opportunities

Panels show:
- Total compute cost and cost by team
- Billing trend over time
- Estimated savings from rightsizing over-provisioned VMs

> **What to notice:** The gap between *current spend* and *rightsized
> spend* is the prize money. Later in the workshop you will build a
> tool that surfaces that number on demand.

### 3c. Anomaly Detection & Capacity Planning

Panels show:
- ML anomaly score timeline, by team
- Growth/capacity forecasts

> **What to notice:** The ML jobs have already scored every VM. The
> agent doesn't need to run ML — it just needs a **tool** to query
> these predictions. That's what you will build in Challenge 2 and 3.

---

## Step 3: Meet Kafeju — Ask What It *Can* Do

With the data fresh in your mind, let's see the agent in action.

1. Click the **AI Assistant** icon (sparkle ✨) in the top nav bar.
2. In the agent selector dropdown, choose **Kafeju**.
3. Ask each of these questions. Below each answer, expand the
   **Reasoning** / tool-call panel and note **which `kafeju.*` tool
   actually ran**:

```
Which teams are wasting the most money on idle VMs?
```

Kafeju should pick a tool that groups the data by team and surfaces
drift / efficiency, typically **`kafeju.compare_team_request_vs_usage`**
or **`kafeju.analyze_vm_usage_patterns`**. The exact choice can vary
between runs — both are reasonable matches for this question, and
both return team-level waste metrics that should roughly agree with
the team ranking on the Drift dashboard.

```
Detect any resource anomalies across our VMs.
```

This should trigger **`kafeju.detect_resource_anomalies`**, which
reads the ML predictions data you peeked at in Step 2. Confirm the
tool ID in the reasoning panel.

> **What to notice:** Every answer is grounded in a **tool call** that
> runs real ES|QL against real data. The agent is only as smart as
> the tools it has — and which tool it picks is driven entirely by
> the tool's **description**, which you'll inspect in Step 6.

---

## Step 4: Find the Gap

Now ask two questions that *sound* reasonable. Kafeju will give you
**confident-looking answers to both** — but for each one, expand the
**Reasoning** / tool-call panel and check *which tool ran, and what
ES|QL it actually executed*. The gap isn't "no answer"; it's a
confident answer that doesn't really answer your question.

### Prompt A — regional pricing

```
Which GCP region is cheapest for n2-standard-8 instances?
```

Kafeju will likely answer with a specific region and price (e.g.
*"us-central1, ~$283/month — the lowest price for this machine
type"*). Expand the reasoning panel and look at the ES|QL:

- The pricing catalog in this workshop only contains **one region**
  (`us-central1`). The query isn't ranking regions against each
  other — there's nothing to rank against. Kafeju re-narrates the
  single row it got back as if it were the winner of a multi-region
  comparison.

You'll drill into this exact prompt again in Challenge 2 and see the
one-line ES|QL that proves it.

### Prompt B — zombie VMs

```
Find zombie VMs — which expensive instances are sitting idle for weeks?
```

You'll likely get a polished list (something like *"Search Indexer
(n2-standard-16): 88.5% drift, avg CPU 8%, P95 CPU 15%…"*). Expand
the reasoning panel and look at the ES|QL:

- The tool Kafeju picks (typically **`kafeju.analyze_vm_usage_patterns`**)
  just **ranks by drift** — it does **not** enforce a real zombie
  definition like *P95 CPU < 10% **and** monthly cost > $X **and**
  idle for > 168 hours*. The result looks zombie-like here because
  the underlying data happens to contain idle VMs — the same tool
  would happily return a "zombie" list even on a fleet of heavy
  users (it would just surface whichever rows drift the most).

> **What to notice:** The data to answer both questions is already in
> the cluster — pricing lives in **GCP Pricing Catalog**, idle VMs
> live in **GCP Resource Executions**. What's missing is a tool whose
> ES|QL actually matches the question:
>
> - No tool ranks prices **across regions**.
> - No tool applies the strict **zombie** definition (idle P95 CPU
>   **and** expensive **and** long-running).
>
> You'll build the zombie-detection tool in Challenge 3 and design
> more tools in Challenge 4.

**Key insight:** The biggest risk with a tool-driven agent isn't "no
answer" — it's a **confident answer that's subtly wrong**, because
the LLM will narrate whatever the tool returns as if it fully
answered your question. Always open the **Reasoning** panel and
check the tool's ES|QL against your actual intent.

---

## Step 6: Inspect Kafeju's Tools in the Agent Builder UI

Let's look under the hood — entirely in the Kibana UI, no terminal
needed.

1. Open the hamburger menu and navigate to **Agent Builder**.
   (Depending on the build, it may appear directly in the menu or
   under **Management** > **Agent Builder**.)
2. Click the **Agents** tab and open the **Kafeju** agent.
3. Scroll to the **Tools** section. You should see a list of tool IDs
   attached to this agent.
4. Click on any tool to open its detail view. Notice the three parts:
   - an **ID** (unique name),
   - a **description** (how the agent decides when to use it),
   - a **configuration** that contains an **ES|QL query** (the actual
     work).
5. Go back and open the **Tools** tab. Notice that **every tool
   attached to Kafeju starts with `kafeju.`** — there are no
   generic `platform.core.*` search / ES|QL tools in this agent.
   This is deliberate: in Agent Builder you *can* hand an agent a
   generic "search any index / run any ES|QL" escape hatch, but
   Kafeju has been **scoped on purpose** to only the custom
   workshop tools. That's what makes the gaps in Step 5 actually
   show up — with an escape-hatch tool, the agent would silently
   fall back to generic search and hide the gap.

> **What to notice:**
> - The list of `kafeju.*` tools *is* Kafeju's capability surface.
>   If a question can't be answered with one of these tools, Kafeju
>   can't answer it reliably — which is exactly what you just saw
>   in Step 5.
> - Every `kafeju.*` tool is just an ES|QL query with a description.
>   In the next challenges you will read one of these queries line by
>   line, then write your own.

---

## Check Your Work

Before clicking **Check**, confirm you can answer *yes* to each of
these:

- I logged into Kibana and set the time range to **Last 1 year**.
- I explored at least the **executions**, **pricing**, and
  **ML predictions** data in Discover.
- I opened all three pre-built dashboards and can describe, in one
  sentence, what each one shows.
- I asked Kafeju at least **one question it answered well** and
  **one question it couldn't answer well**.
- I opened the **Agent Builder UI**, found the Kafeju agent, and can
  name at least one `kafeju.*` tool attached to it.

When you're ready, click **Check**.
