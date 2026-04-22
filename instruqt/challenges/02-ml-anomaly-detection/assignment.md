---
slug: dissect-a-tool
title: "Explore ML Anomalies and Dissect a Tool"
teaser: "See where Elastic's ML jobs run, what anomalies they found, then reverse-engineer the Agent Builder tool that turns those results into answers."
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
      # Explore ML Anomalies and Dissect a Tool

      Before we touch Agent Builder, let's see what Elastic has *already*
      figured out for us. Four Machine Learning anomaly-detection jobs
      have been running against the GCP data. They scored every VM, every
      team, every hour — without you writing a single query.

      In this challenge you will:

      1. Inspect those ML jobs in the Kibana UI.
      2. Browse the anomalies they detected in **Anomaly Explorer**.
      3. Open the Agent Builder tool that exposes those anomalies to
         Kafeju, and understand its three parts — **ID**, **description**,
         **ES|QL query** — all from the UI.
      4. Run the same query yourself, ask Kafeju the matching question,
         and confirm all three views tell the same story.
      5. Finally, try a few questions the current toolbox *can't* answer
         well and learn to spot the difference between a **grounded**
         answer and a **confabulated** one.

      Everything in this challenge is UI-first. The Terminal tab is
      there only as an optional shortcut.
---

# Challenge 2: Explore ML Anomalies and Dissect a Tool

Four ML anomaly-detection jobs have already been run on the GCP data.
You will start by looking at those jobs and their results in the Kibana
ML UI, then follow the same results all the way to a Kafeju answer.

---

## Step 1: Meet the ML Jobs (UI, ~5 min)

1. In Kibana, open the hamburger menu and navigate to **Analytics** >
   **Machine Learning** > **Anomaly Detection** > **Jobs**.
   (On some builds the entry point is **AI & ML** > **Machine Learning**
   or **Management** > **Stack Management** > **Machine Learning**.)
2. Confirm the time picker (top-right) is set to **Last 1 year**.
3. You should see four jobs already created and run:

| Job ID | What it detects | Partition / "over" field |
|--------|----------------|--------------------------|
| `resource-usage-anomalies` | Abnormally high CPU / memory usage | `metadata.team` |
| `vm-capacity-planning` | Unusual CPU / memory vs peer VMs | `vm_info.vm_id` |
| `team-cost-forecast` | Forecasts `cost_actual.total_cost_usd` | `metadata.team` |
| `workload-growth-rate` | Mean cores used — growth trend | `metadata.team` |

> **What you should see:** Each job has a green status, a job count of
> records processed, and a small anomaly-score badge. The important
> thing is the **partition / over field** column — it tells you *what
> Elastic is comparing against what*. `vm-capacity-planning` compares
> each VM to its peers; `resource-usage-anomalies` compares each team
> against its own history.
>
> **Why it matters:** Elastic has already done the statistical
> heavy-lifting. You don't need to invent an anomaly algorithm for
> Kafeju — you just need a tool that reads the ML output.

To make these ML results easy for tools (and ES|QL) to consume, they
have been post-processed into two indices:

- `ml-predictions-anomalies*` — one doc per anomaly record
  (`record_score`, `severity`, `vm_id`, `team`, `actual`, `typical`…).
- `ml-predictions-growth` — one doc per team
  (`growth_rate_daily`, `predicted_days_to_90pct`…).

You'll see those indices in action in the next steps.

---

## Step 2: Explore Detected Anomalies in the UI (~10 min)

### 2a. Anomaly Explorer

1. On the **Jobs** page, select `vm-capacity-planning` (and
   optionally `resource-usage-anomalies`), then click
   **View results** > **Anomaly Explorer**.
2. Make sure the time range is still **Last 1 year**.
3. Scan the **Overall** swim lane at the top. Red blocks are
   high-severity anomalies; orange are warnings.
4. Scroll down to **Top influencers** — note which `vm_info.vm_id`
   and `metadata.team` values keep showing up.
5. In the **Anomalies** table at the bottom, click the expand arrow on
   one of the top rows. Look at:
   - `actual` — what the VM's CPU/memory actually was in that bucket.
   - `typical` — what the model expected, based on peer VMs and
     history.
   - `record_score` — severity (0–100).

> **What you should see:** One or two VMs/teams dominating the
> anomalies, with `actual` values far above `typical` (e.g. 95% CPU
> when the model expected ~15%). A `record_score` above 75 is
> "critical"; 50–75 is "major"; 25–50 is "minor".
>
> **Why it matters:** This is the ground truth. Any question a user
> asks Kafeju like *"which VMs are behaving weirdly?"* should come
> back with roughly the same VMs you're looking at right now.

### 2b. Same data, from Discover

1. Open the hamburger menu > **Analytics** > **Discover**.
2. Select the data view **`ml-predictions-anomalies-workshop`**.
3. Expand one document and find these fields:

| Field | What it means |
|-------|--------------|
| `record_score` | Anomaly severity (0–100), same as Anomaly Explorer |
| `severity` | Text bucket — `critical` / `major` / `minor` |
| `vm_id`, `vm_type`, `team` | Which VM / team produced the anomaly |
| `actual` vs `typical` | Observed value vs ML-expected value |
| `function_description` | Which detector fired (e.g. `high mean`) |

> **What you should see:** The same VMs that were red in Anomaly
> Explorer appear here as top-scoring documents. Exploring in Discover
> is uglier than the ML UI, but — critically — it can be expressed as
> an ES|QL query. That's what makes it usable by an Agent Builder
> tool.

---

## Step 3: Dissect the ML Tool in the Agent Builder UI (~5 min)

Now let's see how Kafeju consumes those predictions.

1. Hamburger menu > **Agent Builder**. (Depending on the build it may
   sit under **Management** > **Agent Builder**.)
2. Click the **Tools** tab.
3. In the filter box, type `detect_resource_anomalies` and open the
   tool **`kafeju.detect_resource_anomalies`**.
4. In the detail view, identify the three parts every Agent Builder
   tool has:
   - **ID** — `kafeju.detect_resource_anomalies`. This is how the
     agent calls it.
   - **Description** — the text that starts with *"Identifies VMs
     with unusual resource usage patterns from ML anomaly
     predictions…"*. This is **routing logic**: the AI reads it to
     decide whether this tool is the right one for the user's
     question.
   - **Configuration > ES|QL query** — a query against
     `ml-predictions-anomalies*` that filters `record_score > 25`,
     sorts by score, and keeps the fields you just saw in Discover.

> **What you should see:** The query reads from the **same index**
> you browsed in Step 2b, and returns the **same fields** you saw on
> an anomaly document. Nothing magical — it's plain ES|QL.
>
> **Why it matters:** An Agent Builder tool is *just* ID +
> description + ES|QL. No model re-training, no streaming, no custom
> code. That's the entire surface area you'll use for the rest of
> the workshop.

While you're in the Tools tab, also spot **`kafeju.predict_resize_needs`**
— it follows the same pattern, but reads from `ml-predictions-growth`
(the `workload-growth-rate` job's output). Two tools, same recipe.

> **Optional (Terminal):** If you prefer CLI, the same information
> is available at `GET /api/agent_builder/tools` — but the UI is the
> source of truth for this workshop.

---

## Step 4: Run the Query Yourself and Ask Kafeju (~5 min)

Time to connect the ML UI, the ES|QL tool, and the agent.

1. **Copy** the ES|QL query from the tool detail pane in Step 3.
2. Open **Discover** and switch to **ES|QL mode** (the toggle at the
   top of Discover).
3. **Paste and run** the query. You should get a table of the
   highest-scoring anomalies.
4. Now click the **AI Assistant** icon (✨) and switch to the
   **Kafeju** agent.
5. Ask:

> **"Which VMs have the most unusual resource usage right now? Show
> me the top anomalies."**

6. When Kafeju answers, expand the **tool-call / reasoning panel**
   under the answer and confirm that `kafeju.detect_resource_anomalies`
   was the tool that ran.

> **What you should see:** Three views of the same ML result:
> - **Anomaly Explorer** (Step 2a) — human-friendly swim lanes.
> - **Discover > ES|QL** (Step 4) — structured rows, same top VMs.
> - **Kafeju** — a natural-language summary that names the *same*
>   VMs and teams.
>
> All three should agree. If the agent's narrative names a VM that
> isn't in your ES|QL result, the tool or the agent is lying. That's
> the next step.

---

## Step 5: Spot the Gaps — Don't Trust, Verify (~10 min)

Modern LLMs rarely say *"I can't answer that."* They pick the
closest-looking tool, run it, and re-narrate the result as if it
answered your actual question. Here you'll practise telling a
**grounded** answer from a **confabulated** one.

For each prompt below, in the Kafeju chat:

1. Ask the prompt.
2. Open the **tool-call / reasoning panel**: which `kafeju.*` tool
   (if any) was called?
3. In **Agent Builder > Tools** (or from Step 3), re-read that
   tool's **description** and **ES|QL query**. Does the query
   actually compute what the user asked for?
4. Cross-check with the small ES|QL snippet provided, in
   **Discover > ES|QL mode**.

### Prompt A — regional pricing (gap)

> **"Compare the hourly price of `n2-standard-8` across at least
> three GCP regions and rank them from cheapest to most expensive."**

Kafeju will likely give a confident answer like *"us-central1 is
cheapest"*. Verify:

```esql
FROM gcp-pricing-catalog
| WHERE machine_type == "n2-standard-8"
| STATS n = COUNT(*) BY region
```

> **What you should see:** Only **one** region (`us-central1`)
> exists in the catalog. The agent *invented* a multi-region
> comparison — the data can't support one. Confabulated.

### Prompt B — zombie VMs (gap)

> **"List zombie VMs: instances where P95 CPU < 10%, monthly cost >
> $200, and the execution has been running for more than 168 hours.
> Return the top 10 by cost."**

The agent will probably answer with a list of high-drift VMs. Check
the tool-call panel: likely `kafeju.analyze_vm_usage_patterns` or
`kafeju.detect_resource_anomalies` — **neither** filters on P95
CPU, monthly cost, **and** duration together. Verify:

```esql
FROM gcp-resource-executions-*
| WHERE resource_usage.cpu.p95_percent < 10
  AND cost_actual.total_cost_usd > 200
  AND execution_time.duration_hours > 168
| STATS cost = SUM(cost_actual.total_cost_usd)
    BY metadata.workload_name, vm_info.vm_type_actual
| SORT cost DESC
| LIMIT 10
```

> **What you should see:** The real zombie list is likely very
> different from what Kafeju narrated. Confabulated — no tool
> computes this.

### Takeaway

In both prompts the agent didn't error — it just *improvised*
because no tool in the toolbox answers the question. In Challenges 3
and 4 you will build the missing tools so these questions become
grounded.

---

## Check Your Work

Before clicking **Check**, confirm:

- I opened the **Anomaly Detection Jobs** page and can name at
  least 2 of the 4 ML jobs and what each one scores.
- I used **Anomaly Explorer** to inspect at least one
  high-severity anomaly (`record_score` > 75) and noted the
  `actual` vs `typical` values.
- I opened **`kafeju.detect_resource_anomalies`** in the Agent
  Builder UI and can state its 3 components (ID, description,
  ES|QL query) plus the index it reads from.
- I ran that ES|QL in **Discover > ES|QL mode** and the top VMs
  matched the ones I saw in Anomaly Explorer.
- I asked Kafeju the anomaly question, confirmed the right tool
  was called in the tool-call panel, and saw the same VMs in the
  narrative.
- For Prompts A and B in Step 5, I inspected the tool-call panel
  and used the provided ES|QL to prove the answer was
  confabulated.

When you're ready, click **Check**.
