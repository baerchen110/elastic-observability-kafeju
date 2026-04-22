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

Where do the results live?

- Anomaly-detection jobs (`resource-usage-anomalies`,
  `vm-capacity-planning`) write their results to Elastic's built-in
  ML results index, **`.ml-anomalies-*`**. That's the same index
  Anomaly Explorer reads from — and it's what the Kafeju anomaly
  tool will query with ES|QL in a moment.
- Growth / capacity forecasts (`workload-growth-rate`) are
  post-processed into the `ml-predictions-growth-workshop` index
  (surfaced as the **ML Growth Predictions** data view) for a
  simpler per-team shape.

You'll see `.ml-anomalies-*` in action in the next steps.

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
   - `anomaly_score` — severity (0–100).

> **What you should see:** One or two VMs/teams dominating the
> anomalies, with `actual` values far above `typical` (e.g. 95% CPU
> when the model expected ~15%). Using the same thresholds the
> Kafeju tool applies, an `anomaly_score` ≥ 75 is **CRITICAL**,
> ≥ 50 is **HIGH**, ≥ 25 is **MEDIUM**, below that is **LOW**.
>
> **Why it matters:** This is the ground truth. Any question a user
> asks Kafeju like *"when is the ML model seeing unusual activity?"*
> should come back with time buckets and severities that match what
> you're looking at right now.

### 2b. Same data, from Discover + ES|QL

Anomaly Explorer is great for humans, but tools speak ES|QL. The ML
results live in the system index `.ml-anomalies-*`. Let's peek at
one raw document.

1. Open the hamburger menu > **Analytics** > **Discover**.
2. Click the data-view selector (top-left) and switch to
   **ES|QL mode** (the toggle at the top of Discover).
3. Run this small query — it's a slimmed-down version of what the
   Kafeju tool will run in Step 3:

   ```esql
   FROM .ml-anomalies-*
   | WHERE job_id == "vm-capacity-planning"
     AND result_type == "bucket"
     AND anomaly_score > 0
     AND is_interim == false
   | SORT anomaly_score DESC
   | KEEP timestamp, job_id, result_type, anomaly_score, event_count, bucket_span
   | LIMIT 20
   ```

   Key fields:

   | Field | What it means |
   |-------|--------------|
   | `job_id` | Which ML job wrote this row (here, `vm-capacity-planning`) |
   | `result_type` | `bucket`, `record`, or `influencer` — the ML API returns different shapes |
   | `anomaly_score` | Bucket-level severity (0–100) |
   | `is_interim` | `true` while a bucket is still being finalized — filter these out |
   | `timestamp` | Start of the 1-hour bucket |
   | `event_count`, `bucket_span` | How much data this bucket saw, and its span |

> **What you should see:** The top-scoring buckets line up with the
> red blocks you saw in the Overall swim lane. Notice what's *not*
> in the result: no `vm_id`, no `team`. Bucket-level rows are the
> overall model score for that hour, aggregated across all VMs — so
> "which VM" is a separate question. Keep that in mind for Step 4.

---

## Step 3: Dissect the ML Tool in the Agent Builder UI (~5 min)


Now let's see how Kafeju consumes those predictions.

1. Hamburger menu > **Agent Builder**. (Depending on the build it may
   sit under **Management** > **Agent Builder**.)
2. Click the **Tools** tab.
3. In the filter box, type `anomalies` and open the
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
   - **Configuration > ES|QL query** — the real query the tool
     runs. It should look like this:

     ```esql
     FROM .ml-anomalies-*
     | WHERE job_id == "vm-capacity-planning"
       AND result_type == "bucket"
       AND anomaly_score > 0
       AND is_interim == false
     | EVAL
         anomaly_date = DATE_FORMAT("yyyy-MM-dd HH:mm", timestamp),
         severity_level = CASE(
             anomaly_score >= 75, "CRITICAL",
             anomaly_score >= 50, "HIGH",
             anomaly_score >= 25, "MEDIUM",
             "LOW"
         )
     | SORT anomaly_score DESC
     | KEEP anomaly_date, severity_level, anomaly_score,
            event_count, bucket_span
     | LIMIT 20
     ```

Read it line by line:

- `FROM .ml-anomalies-*` — same index you queried in Step 2b.
- `WHERE job_id == "vm-capacity-planning"` — **the tool only looks
  at one job**, not all four. Anomalies from `resource-usage-anomalies`
  will not show up here.
- `result_type == "bucket"` — bucket-level only (no per-record or
  per-influencer rows). That's why there are no `vm_id` / `team`
  columns in the output.
- `is_interim == false` — drop buckets the ML engine hasn't finalized.
- `EVAL` — formats the timestamp and converts the numeric
  `anomaly_score` into a human-readable `severity_level` using
  the same thresholds you noted in Step 2a.
- `KEEP` + `LIMIT 20` — return at most 20 rows, each one a
  time bucket with its severity.

> **What you should see:** The query reads from the **same index**
> you browsed in Step 2b, and the `EVAL` turns the raw score into the
> same `CRITICAL / HIGH / MEDIUM / LOW` ladder Anomaly Explorer hints
> at. Nothing magical — it's plain ES|QL.
>
> **Why it matters:** An Agent Builder tool is *just* ID +
> description + ES|QL. No model re-training, no streaming, no custom
> code. That's the entire surface area you'll use for the rest of
> the workshop.
>
> **What to notice about this specific tool:** It only covers the
> `vm-capacity-planning` job, and it returns *bucket-level*
> severity — **not** a list of offending VMs or teams. That's a
> real limitation: when a user asks *"which VM is unusual?"*, this
> tool literally cannot answer. It can only answer *"when was the
> model unusually alarmed?"*. You'll feel this gap in Step 4.

While you're in the Tools tab, also spot **`kafeju.predict_resize_needs`**
— it follows the same pattern, but reads from the **ML Growth
Predictions** data view (backed by `ml-predictions-growth-workshop`,
the `workload-growth-rate` job's output). Two tools, same recipe.

> **Optional (Terminal):** If you prefer CLI, the same information
> is available at `GET /api/agent_builder/tools` — but the UI is the
> source of truth for this workshop.

---

## Step 4: Run the Tool Two Ways (~5 min)

You've already read the tool's ES|QL. Now run the tool and see what
it actually returns — first on its own (via Agent Builder's Test
panel), then indirectly through a natural question to Kafeju — and
check that both paths agree with the ML UI from Step 2.

### 4a. Run the tool from Agent Builder (Test button)

You don't need to leave the tool detail page from Step 3 — Agent
Builder can execute it directly.

1. On the `kafeju.detect_resource_anomalies` detail page, click the
   **Test** button (top-right).
2. This tool has no inputs, so just click **Submit**.
3. Expand the **Response** panel. You'll see three entries.

> **Why it matters:** The Test button is the fastest way to
> sanity-check a tool while you build it. 

### 4b. Ask Kafeju a natural question

Now pretend you're a platform engineer who has never heard of
`.ml-anomalies-*` or `kafeju.detect_resource_anomalies`. You just
want to know if anything weird is going on.

1. Click the **AI Assistant** icon (✨) and switch to the
   **Kafeju** agent.
2. Ask a plain, everyday question:

```
Is anything unusual happening on our VMs lately?
```

3. When Kafeju answers, expand the **tool-call / reasoning panel**
   under the answer. You should see `kafeju.detect_resource_anomalies`
   chosen automatically — the agent picked it from the **tool
   description** alone. The rows under that tool call should
   match what you got in 4a.

> **What you should see:** Three views of the same ML result:
> - **Anomaly Explorer** (Step 2a) — human-friendly swim lanes,
>   red blocks at the anomalous times.
> - **Agent Builder Test** (4a) — the tool's raw tabular output,
>   with `CRITICAL` / `HIGH` severity labels.
> - **Kafeju** (4b) — a natural-language summary of those same
>   time windows.
>
> All three should agree on *when* the anomalies happened. If the
> agent starts naming specific VMs (e.g. *"vm-web-03 spiked to 98%
> CPU"*), be suspicious: the Test response in 4a has no `vm_id`
> column. Anything VM-specific was either invented by the model or
> came from a different tool call.
>
> Try a follow-up and feel the gap:
>
> > **"Which specific VM was responsible for those anomalies?"**
>
> `kafeju.detect_resource_anomalies` cannot answer this from its
> current ES|QL. The next step turns that pain into a lesson.

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

```
Compare the hourly price of n2-standard-8 across at least three GCP regions and rank them from cheapest to most expensive.
```

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

```
List zombie VMs: instances where P95 CPU < 10%, monthly cost > $200, and the execution has been running for more than 168 hours. Return the top 10 by cost.
```

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
  high-severity anomaly (`anomaly_score` ≥ 75) and noted the
  `actual` vs `typical` values.
- I opened **`kafeju.detect_resource_anomalies`** in the Agent
  Builder UI and can state its 3 components (ID, description,
  ES|QL query), the index it reads from (`.ml-anomalies-*`), and
  that it's scoped to `job_id == "vm-capacity-planning"` and
  `result_type == "bucket"`.
- I ran the tool from the Agent Builder **Test** button and read
  the `tabular_data` response columns (`anomaly_date`,
  `severity_level`, `anomaly_score`, `event_count`, `bucket_span`),
  and those rows matched the red blocks in Anomaly Explorer.
- I asked Kafeju a generic anomaly question, confirmed
  `kafeju.detect_resource_anomalies` was picked automatically in
  the tool-call panel, and noticed the tool cannot answer
  "which VM".
- For Prompts A and B in Step 5, I inspected the tool-call panel
  and used the provided ES|QL to prove the answer was
  confabulated.

When you're ready, click **Check**.
