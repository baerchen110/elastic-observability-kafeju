# Challenge 1: From consumer to creator

## About this challenge

**Kafeju** echoes the Greek *καφετζού* (*kafetzoú*): the café figure who
reads the cup to **tell fortunes** by inferring what comes next from what
is left behind. In this workshop, that metaphor is deliberate but
**secular**. Instead of mysticism, Kafeju uses **GCP execution metrics,
pricing, billing, and ML** to make **evidence-backed predictions** about
where drift will hurt the budget, which workloads look idle, what anomalies
and growth models are signaling, and where rightsizing can pay off.

Kafeju is the custom agent you will extend. It analyzes VM usage, detects
**resource drift** (the gap between what a team *asked for* and what they
*actually use*), and points toward rightsizing opportunities.

The environment is pre-loaded with workshop sample data captured through
Elastic Agent from real-world GCP telemetry (billing, VM usage, and costs).
The diagram below shows the high-level data-collection architecture.

![Screenshot 2026-04-23 at 20.46.36.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/db13147b2517b77ded9b571227083013/assets/Screenshot%202026-04-23%20at%2020.46.36.png)

- **~12,000 GCP resource-execution records** — every VM run with
  allocated vs actual CPU/memory, cost, team, zone, and machine type.
- **GCP pricing catalog** — hourly prices for every machine family and
  region.
- **ML anomaly + growth predictions** — output of four ML jobs that
  score VMs for unusual behavior and forecast capacity.
- **GCP billing records** — daily cost roll-ups.
- **Three pre-built dashboards** that visualize the above.

All data has been anonymized for this workshop.

In this challenge, you will **explore the data first**, then meet the
Kafeju agent and identify where its current tools fall short.

---

## Step 1: Explore the data in Discover
===

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

![Screenshot 2026-04-25 at 16.53.22.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/c47dd253d7b9ce8d85a8ca00d45424fe/assets/Screenshot%202026-04-25%20at%2016.53.22.png)

4. Now switch the data view to **GCP Pricing Catalog** and expand
   a document. Note how each machine type has an hourly price per
   region.
5. Switch once more to **ML Anomalies**. Each record has a
   `record_score` (how anomalous) and the VM / team it belongs to.
![Screenshot 2026-04-23 at 10.35.26.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/3b8aacbb6f20305718970fea5b5cf70f/assets/Screenshot%202026-04-23%20at%2010.35.26.png)
> **What to notice:** Three *independent* data views tell you the
> story — actual usage (**GCP Resource Executions**), pricing
> (**GCP Pricing Catalog**), and ML anomaly scores (**ML
> Anomalies**). A good agent tool has to join across them. Any
> question like *"cheapest region for n2-standard-8"* must reach
> into the pricing catalog, not the executions data.

---

## Step 2: Tour the pre-built dashboards
===


Now let's see the same data visually. Open the hamburger menu >
**Analytics** > **Dashboard** and open each dashboard in turn. (Make
sure the time picker is still on **Last 1 year**.)

### 2a. GCP Resource Drift Overview

Panels show:
- Average drift % across the fleet
- Drift broken down by **team**, **machine type**, and **zone**
![Screenshot 2026-04-25 at 16.54.13.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/72bfa35cc17d317e6419ec4f54ad0849/assets/Screenshot%202026-04-25%20at%2016.54.13.png)

> **What to notice:** Drift is *not* evenly distributed. A few teams
> and a few machine types dominate the waste. These are the exact VMs
> a cost-optimization agent should flag first.

### 2b. Cost Optimization Opportunities

Panels show:
- Total compute cost and cost by team
- Billing trend over time
- Estimated savings from rightsizing over-provisioned VMs
![Screenshot 2026-04-25 at 16.54.01.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/d0ae1823be47e4db6954709f29bb03ef/assets/Screenshot%202026-04-25%20at%2016.54.01.png)
> **What to notice:** The gap between *current spend* and *rightsized
> spend* is the prize money. Later in the workshop you will build a
> tool that surfaces that number on demand.

### 2c. Anomaly Detection & Capacity Planning

Panels show:
- ML anomaly score timeline, by team
- Growth/capacity forecasts

![Screenshot 2026-04-25 at 16.53.43.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/2bcc2611aa64c7f9b113923fa4ebbc1f/assets/Screenshot%202026-04-25%20at%2016.53.43.png)
> **What to notice:** The ML jobs have already scored every VM. The
> agent doesn't need to run ML — it just needs a **tool** to query
> these predictions. That's what you will build in Challenge 2 and 3.

---

## Step 3: Meet Kafeju — ask what it *can* do
===


With the data fresh in your mind, let's see the agent in action.

1. Click the **AI Assistant** icon  in the top nav bar.
2. Select **Try the new AI Agent** and confirm
![Screenshot 2026-04-23 at 10.40.33.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/ac883f019a0fd9964df79ebb8d650cd6/assets/Screenshot%202026-04-23%20at%2010.40.33.png)

3. In the agent selector dropdown, choose **Kafeju**.
![Screenshot 2026-04-23 at 10.40.44.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/425140636000a3b545120ad0c8bda57e/assets/Screenshot%202026-04-23%20at%2010.40.44.png)
4. Ask each of these questions. Below each answer, expand the
   **Reasoning** / tool-call panel and note **which `kafeju.*` tool
   actually ran**:

```
Which teams are wasting the most money on idle VMs?
```
![Screenshot 2026-04-23 at 10.41.26.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/91977b41b82ba4123ae2b17e8c776960/assets/Screenshot%202026-04-23%20at%2010.41.26.png)

Kafeju should pick a tool that groups the data by team and surfaces
drift / efficiency, typically **`kafeju.compare_team_request_vs_usage`**
or **`kafeju.analyze_vm_usage_patterns`**. The exact choice can vary
between runs — both are reasonable matches for this question, and
both return team-level waste metrics that should roughly agree with
the team ranking on the Drift dashboard.

![Screenshot 2026-04-23 at 10.41.36.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/d1874faa2055c3097d4397dc1b465ce2/assets/Screenshot%202026-04-23%20at%2010.41.36.png)

```
Detect any resource anomalies across our VMs.
```

This should trigger **`kafeju.detect_resource_anomalies`**, which
reads the ML predictions data you peeked at in Step 2. Confirm the
tool ID in the reasoning panel.

> **What to notice:** Every answer is grounded in a **tool call** that
> runs real ES|QL against real data. The agent is only as smart as
> the tools it has — and which tool it picks is driven entirely by
> the tool's **description**, which you'll inspect in Step 5.

---

## Step 4: Find the gap
===


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

- The tool it usually picks (`kafeju.get_instance_cost_and_specs`)
  returns a **broad slice** of the catalog (many machine types,
  sorted by hourly cost, capped at 30 rows). It does **not** run the
  tight question you asked: *rank every region for `n2-standard-8`
  only*. The LLM may still sound as if it compared **all** GCP
  regions worldwide.

- In **Discover > ES|QL**, run the ground truth for *your* dataset
  (however many regions exist in the workshop catalog):

```esql
FROM gcp-pricing-catalog
| WHERE machine_type == "n2-standard-8"
| KEEP region, cost_per_month_usd
| SORT cost_per_month_usd ASC
```

  Compare row count and ordering to Kafeju's narrative.

You'll drill into this exact prompt again in Challenge 2 with the
same verification mindset.

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

## Step 5: Inspect Kafeju's tools in the Agent Builder UI
===



Let's look under the hood — entirely in the Kibana UI, no terminal
needed.

1. Open **Agent Builder** (Search **Agents** in the App search bar on the top).
2. Open the **Agents** tab and select the **Kafeju** agent.
3. Open the **Tools** tab. Use the search bar if needed so the list
   shows only tools attached to Kafeju.

![Screenshot 2026-04-23 at 10.49.29.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/7a940e8f57fe7fa787eacdf216b33dd5/assets/Screenshot%202026-04-23%20at%2010.49.29.png)

4. Notice that **every tool attached to Kafeju starts with
   `kafeju.`** — there are no generic `platform.core.*` search /
   ES|QL tools in this agent. In Agent Builder you *can* give an agent
   a generic "search any index / run any ES|QL" escape hatch, but
   Kafeju has been **scoped on purpose** to only the custom workshop
   tools.

> **What to notice:**
> - The list of `kafeju.*` tools *is* Kafeju's capability surface.
>   If a question can't be answered with one of these tools, Kafeju
>   can't answer it reliably — which is exactly what you just saw
>   in Step 4 (Find the Gap).
> - Every `kafeju.*` tool is just an ES|QL query with a description.
>   In the next challenges you will read one of these queries line by
>   line, then write your own.

---

## Check your work
===



Before clicking **Next**, confirm you can answer *yes* to each of
these:

- I asked Kafeju at least **one question it answered well** and
  **one question it couldn't answer well**.
- I opened the **Agent Builder UI**, found the Kafeju agent, and can
  name at least one `kafeju.*` tool attached to it.

When you're ready, click **Next**.
