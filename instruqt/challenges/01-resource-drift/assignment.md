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

## Step 1: Log In

1. Open the **Kibana** tab.
2. Log in with: `elastic` / `workshopAdmin1!`.
3. Set the time picker (top-right) to **Last 1 year**. The workshop
   dataset spans roughly 12 months, so shorter ranges will look empty.

> **What to notice:** Every screen in this challenge should use
> *Last 1 year* as the time range. If a dashboard or Discover view
> looks blank, check the time picker first.

---

## Step 2: Explore the Data in Discover

Before asking an AI anything, *you* should know what data exists.

1. Open the hamburger menu > **Analytics** > **Discover**.
2. In the data view selector (top-left), pick
   **`gcp-resource-executions-*`**.
3. Expand one document and skim these fields:

| Field | What it means |
|-------|--------------|
| `metadata.team` | Team that owns the VM |
| `vm_info.vm_type_actual` | Machine type actually running (e.g. `n2-standard-16`) |
| `resource_usage.cpu.avg_percent` | Actual average CPU utilization |
| `resource_usage.cpu.p95_percent` | 95th-percentile CPU (peak baseline) |
| `drift_metrics.combined_drift_score` | % of allocated resources that are *not* being used |
| `cost_actual.total_cost_usd` | Cost of that execution |

4. Now switch the data view to **`gcp-pricing-catalog`** and expand a
   document. Note how each machine type has an hourly price per region.
5. Switch once more to **`ml-predictions-anomalies-workshop`**. Each
   record has a `record_score` (how anomalous) and the VM / team it
   belongs to.

> **What to notice:** Three *independent* datasets tell you the story —
> actual usage, pricing, and ML anomaly scores. A good agent tool has
> to join across them. Keep this in mind: any question that needs,
> say, "cheapest region for n2-standard-8" must reach into
> `gcp-pricing-catalog`, not the executions index.

---

## Step 3: Tour the Pre-Built Dashboards

Now let's see the same data visually. Open the hamburger menu >
**Analytics** > **Dashboard** and open each dashboard in turn. (Make
sure the time picker is still on **Last 1 year**.)

### 3a. GCP Resource Drift Overview

Panels show:
- Average drift % across the fleet
- Drift broken down by **team**, **machine type**, and **zone**

> **What to notice:** Drift is *not* evenly distributed. A few teams
> and a few machine types dominate the waste. These are the exact VMs
> a cost-optimization agent should flag first.

### 3b. Cost Optimization Opportunities

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

## Step 4: Meet Kafeju — Ask What It *Can* Do

With the data fresh in your mind, let's see the agent in action.

1. Click the **AI Assistant** icon (sparkle ✨) in the top nav bar.
2. In the agent selector dropdown, choose **Kafeju**.
3. Ask each of these questions and watch the tool invocation pane:

> **"Which teams are wasting the most money on idle VMs?"**

You should see Kafeju call a tool whose ID starts with `kafeju.`
(for example `kafeju.analyze_vm_usage_patterns`). The answer should
roughly agree with the team ranking you saw on the Drift dashboard.

> **"Detect any resource anomalies across our VMs."**

This invokes `kafeju.detect_resource_anomalies`, which reads the same
ML predictions index you peeked at in Step 2.

> **What to notice:** Every answer is grounded in a **tool call** that
> runs real ES|QL against real data. The agent is only as smart as
> the tools it has.

---

## Step 5: Find the Gap

Now ask two questions that *sound* reasonable but that Kafeju's current
toolbox can't properly answer:

> **"Which GCP region is cheapest for n2-standard-8 instances?"**

> **"Find zombie VMs — which expensive instances are sitting idle for
> weeks?"**

Kafeju will either:
- hallucinate a plausible-sounding answer,
- give a generic non-answer, or
- apologize that it doesn't have the right data.

> **What to notice:** The data to answer both questions *is already in
> the cluster* — pricing lives in `gcp-pricing-catalog`, idle VMs live
> in `gcp-resource-executions-*`. What's missing is a **tool** that
> knows how to query them. You will fix that in Challenges 3 and 4.

**Key insight:** An agent's capability is bounded by its tools. No
regional-pricing tool → no regional-pricing answers. No
zombie-detection tool → the agent guesses.

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
5. Go back and open the **Tools** tab. Scan the full list and group
   them mentally:
   - IDs starting with **`kafeju.`** → **custom** ES|QL tools made for
     this workshop.
   - IDs starting with **`platform.core.`** (or similar built-in
     prefixes) → tools that ship with Kibana out of the box.

> **What to notice:**
> - Count the `kafeju.*` tools — that's Kafeju's *real* capability
>   surface. If a question can't be answered with one of these
>   tools (plus the built-ins), Kafeju can't answer it reliably.
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
