# Challenge 2: Explore ML Anomalies and Dissect a Tool

Four ML anomaly-detection jobs have already been run on the GCP data.
You will start by looking at those jobs and their results in the Kibana
ML UI, then follow the same results all the way to a Kafeju answer.


## Step 1: Meet the ML Jobs
===


1. In the app search bar, type **jobs** and select **Machine learning / Anomaly Detection jobs**
![Screenshot 2026-04-23 at 15.06.16.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/cef1cb2590cd48f47bfe8b46152cd589/assets/Screenshot%202026-04-23%20at%2015.06.16.png)
2. You should see four jobs already created and run:
![Screenshot 2026-04-23 at 15.08.35.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/2b787325b212a5ba6c97c24d69321793/assets/Screenshot%202026-04-23%20at%2015.08.35.png)

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
===
### 2a. Anomaly Explorer

1. On the **Jobs** page, select `vm-capacity-planning` (and
   optionally `resource-usage-anomalies`), then click
   **Open 2 jobs in Anomaly Explorer**.
![Screenshot 2026-04-23 at 15.08.46.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/8d8d6425e0953e2b29936ecde78cd360/assets/Screenshot%202026-04-23%20at%2015.08.46.png)
2. Make sure the time range is still **Last 1 year**.
3. Scan the **Overall** swim lane at the top. Red blocks are
   high-severity anomalies; orange are warnings.
![Screenshot 2026-04-23 at 15.10.38.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/1c55a3221fa4526e2519beae90e1d760/assets/Screenshot%202026-04-23%20at%2015.10.38.png)
4. Check **Top influencers** — note which `vm_info.vm_id`
   and `metadata.team` values keep showing up.
5. In the **Anomalies** table at the bottom, click the expand arrow on
   one of the top rows. Look at:
   - `actual` — what the VM's CPU/memory actually was in that bucket.
   - `typical` — what the model expected, based on peer VMs and
     history.
   - `score` — severity (0–100).

> **What you should see:** One or two VMs/teams dominating the
> anomalies, with `actual` values far above `typical` (e.g. 95% CPU
> when the model expected ~15%). Using the same thresholds the
> Kafeju tool applies, an `score` ≥ 75 is **CRITICAL**,
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
2. Click the **Try ES|QL** button at the top of Discover and switch to
   **ES|QL mode**.
3. Run this query — it's a slimmed-down version of what the
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

![Screenshot 2026-04-23 at 15.13.48.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/5cc0e9cf241b620179e34eef31454f97/assets/Screenshot%202026-04-23%20at%2015.13.48.png)

> **Editor vs. execution:** `.ml-anomalies-*` is an Elasticsearch
> **hidden system index** (ML internal results). Discover's ES|QL
> editor may still show a **validation warning** on line 1 — for
> example *"Unknown index `.ml-anomalies-*`"* or a red underline on
> `FROM` — because the UI index picker does not always resolve dot
> indices, even when your role is allowed to read them. **If rows
> appear in the results grid, the query ran successfully**; treat
> the warning as a common false positive when querying `.ml-*`
> patterns from Discover.

**Key fields:**

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

## Step 3: Dissect the ML Tool in the Agent Builder UI
===
Now let's see how Kafeju consumes those predictions.

1. In the app search bar, type **Agent tools** and select **Agent / Tools**
![Screenshot 2026-04-23 at 15.19.34.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/55f58451546db5499b9c307574cab2d3/assets/Screenshot%202026-04-23%20at%2015.19.34.png)
2. In the filter box, type `anomalies` and open the
   tool **`kafeju.detect_resource_anomalies`**.
![Screenshot 2026-04-23 at 15.20.34.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/c220bd397290558de7d3cf1394de5b98/assets/Screenshot%202026-04-23%20at%2015.20.34.png)
3. In the detail view, identify the three parts every Agent Builder
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
![Screenshot 2026-04-23 at 15.21.40.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/484175ffedbf7fe08955d5b84a5afb4c/assets/Screenshot%202026-04-23%20at%2015.21.40.png)
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

## Step 4: Run the Tool Two Ways
===
You've already read the tool's ES|QL. Now run the tool and see what
it actually returns — first on its own (via Agent Builder's Test
panel), then indirectly through a natural question to Kafeju — and
check that both paths agree with the ML UI from Step 2.

### 4a. Run the tool from Agent Builder (Test button)

You don't need to leave the tool detail page from Step 3 — Agent
Builder can execute it directly.

1. On the `kafeju.detect_resource_anomalies` detail page, click the
   **Test** button (top-right).
![Screenshot 2026-04-23 at 15.22.14.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/ce9d162f22f8f88bdafc32808d1be958/assets/Screenshot%202026-04-23%20at%2015.22.14.png)
2. This tool has no inputs, so just click **Submit**.
3. Expand the **Response** panel and scroll down. You'll see three entries.
![Screenshot 2026-04-23 at 15.22.50.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/49ff509524fdb4bd13cd16f33dbfc40b/assets/Screenshot%202026-04-23%20at%2015.22.50.png)
> **Why it matters:** The Test button is the fastest way to
> sanity-check a tool while you build it.

### 4b. Ask Kafeju a natural question

Now pretend you're a platform engineer who has never heard of
`.ml-anomalies-*` or `kafeju.detect_resource_anomalies`. You just
want to know if anything weird is going on.

1. Click the **AI Assistant** icon and switch to the
   **Kafeju** agent.
2. Ask a plain, everyday question:

```
Is anything unusual happening on our VMs lately?
```
![Screenshot 2026-04-23 at 15.24.33.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/95e4fe286aab74adcaaccaf50ef11523/assets/Screenshot%202026-04-23%20at%2015.24.33.png)
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
```
"Which specific VM was responsible for those anomalies?"
```
>
> `kafeju.detect_resource_anomalies` cannot answer this from its
> current ES|QL. The next step turns that pain into a lesson.

---

## Step 5: Spot the Gaps — Don't Trust, verify
===
Modern LLMs rarely say *"I can't answer that."* They pick the
closest-looking tool, run it, and re-narrate the result as if it
answered your actual question. Here you'll practice telling a
**grounded** answer from a **confabulated** one.

For each prompt below, in the Kafeju chat:

1. Start a **new chat thread** (recommended) and ask the prompt.
   Reusing the same thread can bias tool selection from previous turns.
2. Open the **reasoning panel**: which `kafeju.*` tool
   (if any) was called?
3. In **Agent Builder / Tools** (or from Step 3), re-read that
   tool's **description** and **ES|QL query**. Does the query
   actually compute what the user asked for?
4. Cross-check with the ES|QL snippet provided, in
   **Discover > ES|QL mode**.

### Prompt A — regional pricing (gap)

```
Compare the hourly price of n2-standard-8 across at least three GCP regions and rank them from cheapest to most expensive.
```

Kafeju may give a confident answer like *"us-central1 is cheapest"*.
Now verify what the dataset can actually support:

```esql
FROM gcp-pricing-catalog
| WHERE machine_type == "n2-standard-8"
| STATS n = COUNT(*) BY region
```
![Screenshot 2026-04-23 at 15.25.56.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/6aecccd1fb3f2125136da4f88401e39f/assets/Screenshot%202026-04-23%20at%2015.25.56.png)

Then run:

```esql
FROM gcp-pricing-catalog
| WHERE machine_type == "n2-standard-8"
| KEEP region, cost_per_hour_usd, cost_per_month_usd
| SORT cost_per_hour_usd ASC
```

Why run this exercise even if the agent answer matches ES|QL?

- The goal is not to "catch" the model being wrong every time.
- The goal is to prove whether the answer is **fully supported** by
  tool/query evidence in *your* dataset.
- In some runs, Kafeju may genuinely return the same conclusion as the
  verification query. That is still a success for this exercise,
  because you validated the claim with data instead of trust.

> **Expected outcomes (both are valid learning outcomes):**
>
> - **Grounded answer:** Kafeju says there are not enough regions in
>   this dataset to rank "at least three", and only reports what exists
>   (for example just `us-central1`).  
>   -> This is correct and evidence-based.
>
> - **Confabulated answer:** Kafeju claims it ranked at least three
>   regions (or all GCP regions), but the ES|QL output shows fewer
>   regions.  
>   -> This is unsupported narrative.
>
> A subtle failure mode is **self-contradiction**: the response says
> "ranked three regions" but then lists only one region. Treat that as
> ungrounded reasoning.
>
> **How to interpret `STATS n = COUNT(*) BY region`:**
> - `n` is how many catalog rows exist per region for
>   `n2-standard-8`.
> - If you see one region, then "cheapest region" really means
>   "only region available in this dataset for that machine type."
> - If you see multiple regions, then you should run a second query
>   sorted by price to rank them explicitly.

### Prompt B — zombie VMs (gap by tool chaining)

```
List likely zombie workloads by team and VM type: low average P95 CPU, meaningful cumulative runtime, and non-trivial cumulative cost. Return the top 10 by cost.
```

For this prompt, Kafeju may use **one tool** or **several tools**
(tool choice varies by model run and chat context). Either way, you
still need to verify whether any invoked tool actually applies the
full filter logic.

Open the **Reasoning** panel and answer these three questions for
yourself:

1. **Which tool computed and filtered `total_runtime_hours > 2`?**
   The verification logic uses:
   `ROUND(SUM(execution_time.duration_minutes) / 60, 1)` and then a
   `WHERE total_runtime_hours > 2` filter. In most runs, the correct
   answer is **none** — no single invoked tool does that full
   aggregation + filter.

2. **Which tool filtered on `avg_p95_cpu < 30` after aggregation?**
   Some tools expose P95 CPU as a column, but not all tools apply
   the exact grouped threshold filter you asked for. In most runs,
   the answer is again **none**.

3. **Which tool computed grouped `cost = SUM(cost_actual.total_cost_usd)`
   and then filtered `cost > 0.3` by `metadata.team`,
   `resource_name`, and `vm_info.vm_type_actual`?**
   If no single tool did this exact grouped calculation (typically
   **none**), the final answer is stitched from partial evidence.

Now verify the real answer with a single ES|QL in Discover:

```esql
FROM gcp-resource-executions-*
| STATS
    avg_p95_cpu = ROUND(AVG(resource_usage.cpu.p95_percent), 1),
    total_runtime_hours = ROUND(SUM(execution_time.duration_minutes) / 60, 1),
    cost = ROUND(SUM(cost_actual.total_cost_usd), 2),
    runs = COUNT(*)
  BY metadata.team, resource_name, vm_info.vm_type_actual
| WHERE avg_p95_cpu < 30
  AND total_runtime_hours > 2
  AND cost > 0.3
| SORT cost DESC
| LIMIT 10
```

### Takeaway

The gap isn't *"the agent can't answer"* — the agent is very
willing to answer. The gap is that **no single tool applies the
user's filter**, so the agent chains several tools, fills the
missing filter in prose, and may still **violate its stated criteria**
when the data doesn't match the natural-language summary.

The only robust fix is a dedicated tool whose **ES|QL itself
applies the filter** — which is exactly what you'll build in
Challenge 3 (a real zombie-VM tool) and design in Challenge 4.

---

## Check Your Work
===
Before clicking **Next**, confirm:

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

When you're ready, click **Next**.
