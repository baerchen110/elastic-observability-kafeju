# Challenge 4: Design your own tool

Pick one of the challenge cards below. Each represents a real question
that the Kafeju agent currently cannot answer.

---

## Challenge card A: Regional cost comparison (difficulty: 1 star)
===
**Business question:** "Which GCP region is cheapest for running VMs?"

**Data view:** **GCP Pricing Catalog** (ES|QL index pattern:
`gcp-pricing-catalog`)

**Explore first:** Run this in Discover to see the fields:
```sql
FROM gcp-pricing-catalog
| LIMIT 5
```

**Useful fields:** `region`, `machine_type`, `cpu_cores`, `memory_gb`,
`cost_per_hour_usd`, `cost_per_month_usd`

**Hints:**
- Group by `region` using `STATS ... BY region`
- Calculate `AVG(cost_per_hour_usd)` and `AVG(cost_per_month_usd)`
- Count how many machine types are available per region
- Sort by cheapest first

**Suggested tool ID:** `participant.regional_cost_comparison`

**Test prompt:** "Which GCP region is cheapest for running VMs?"

<details>
<summary><strong>Example ES|QL solution</strong> (click to reveal - instructor hint)</summary>

```sql
FROM gcp-pricing-catalog
| STATS avg_hour_usd  = AVG(cost_per_hour_usd),
        avg_month_usd = AVG(cost_per_month_usd),
        machine_types = COUNT_DISTINCT(machine_type)
    BY region
| SORT avg_hour_usd ASC
| LIMIT 20
```

Note: in the workshop dataset the catalog may only contain one region
(`us-central1`). The query is still correct — it just returns a single
row. That's itself a useful lesson: the tool is shaped right, but the
data doesn't support a multi-region ranking.

</details>

---

## Challenge card B: Weekly cost trends (difficulty: 2 stars)
===
**Business question:** "Show me weekly cost trends per team."

**Data view:** **GCP Billing** (ES|QL index pattern: `gcp-billing-*`)

**Explore first:**
```sql
FROM gcp-billing-*
| LIMIT 5
```

**Useful fields:** `@timestamp`, `billing.cost.amount`,
`gcp.labels.team`, `service.name`

**Hints:**
- Use `EVAL week = DATE_TRUNC(7 days, @timestamp)` to bucket by week
- Use `STATS total_cost = SUM(billing.cost.amount) BY gcp.labels.team, week`
- Sort by `week` then `total_cost DESC`
- Limit to the last few weeks for clarity

**Suggested tool ID:** `participant.weekly_cost_trends`

**Test prompt:** "Show me weekly cost trends per team."

<details>
<summary><strong>Example ES|QL solution</strong> (click to reveal - instructor hint)</summary>

```sql
FROM gcp-billing-*
| EVAL week = DATE_TRUNC(7 days, @timestamp)
| STATS total_cost = SUM(billing.cost.amount)
    BY gcp.labels.team, week
| SORT week DESC, total_cost DESC
| LIMIT 50
```

</details>

---

## Challenge card C: Growth predictions (difficulty: 2 stars)
===
**Business question:** "Which teams will need more capacity soonest?"

**Data view:** **ML Growth Predictions** (ES|QL index pattern:
`ml-predictions-growth-*`)

**Explore first:**
```esql
FROM ml-predictions-growth-*
| LIMIT 10
```

**Useful fields (all flat, top-level keys in each document):**
`team`, `workload_type`, `current_cores_used`, `current_vm_capacity`,
`growth_rate_percent_per_week`, `weeks_until_90_percent_capacity`,
`recommendation`, `confidence`

> **Schema check for this card:** the growth index in this workshop
> exposes `weeks_until_90_percent_capacity` (not
> `predicted_days_to_90pct`) and `growth_rate_percent_per_week` (not
> `growth_rate_daily`).

**Hints:**
- Filter where `weeks_until_90_percent_capacity` is low (e.g. `< 12`) —
  most urgent first
- Sort by `weeks_until_90_percent_capacity ASC`
- Include `recommendation` (values include `PLAN_RESIZE`, `MONITOR`,
  and `OPTIMIZE_FIRST`)
- `growth_rate_percent_per_week` is already expressed as percent points
  per week in this dataset; do not multiply by 100 again.

**Suggested tool ID:** `participant.capacity_forecast`

**Test prompt:** "Which teams will need more capacity soonest?"

<details>
<summary><strong>Example ES|QL solution</strong> (click to reveal - instructor hint)</summary>

```esql
FROM ml-predictions-growth-*
| KEEP team, workload_type, current_cores_used, current_vm_capacity,
       growth_rate_percent_per_week, weeks_until_90_percent_capacity,
       recommendation, confidence
| WHERE weeks_until_90_percent_capacity IS NOT NULL
| WHERE weeks_until_90_percent_capacity < 12
| EVAL current_utilization_pct = ROUND((current_cores_used / current_vm_capacity) * 100, 1)
| STATS soonest_weeks_to_90 = MIN(weeks_until_90_percent_capacity),
        avg_growth_pct_per_week = ROUND(AVG(growth_rate_percent_per_week), 2),
        avg_current_utilization_pct = ROUND(AVG(current_utilization_pct), 1),
        latest_reco   = VALUES(recommendation),
        confidence_levels = VALUES(confidence)
    BY team
| KEEP team, soonest_weeks_to_90, avg_growth_pct_per_week,
       avg_current_utilization_pct, latest_reco, confidence_levels
| SORT soonest_weeks_to_90 ASC
| LIMIT 20
```

Notes:

- Some teams have `weeks_until_90_percent_capacity = null` because they
  are not currently projected to hit 90% soon. Filtering out null values
  focuses the result on teams with concrete near-term capacity pressure.
- The `STATS ... BY team` pass collapses multiple snapshots into one row
  per team with the most-urgent weeks-to-90% and the latest
  recommendation.

</details>

---

## Challenge card D: Team overspend analysis (difficulty: 3 stars)
===
**Business question:** "How much is each team overspending vs actual
usage?"

**Data view:** **GCP Resource Executions** (ES|QL index pattern:
`gcp-resource-executions-*`)

**Explore first:**
```sql
FROM gcp-resource-executions-*
| LIMIT 5
```

**Useful fields:** `cost_actual.total_cost_usd`,
`drift_metrics.combined_drift_score`, `metadata.team`,
`resource_usage.cpu.avg_percent`, `resource_usage.memory.avg_percent`

**Hints:**
- Group by `metadata.team`
- Calculate `total_cost = SUM(cost_actual.total_cost_usd)`
- Calculate `avg_drift = AVG(drift_metrics.combined_drift_score)`
- Use `EVAL waste_usd = total_cost * avg_drift / 100` to estimate waste
- Sort by `waste_usd DESC`

**Suggested tool ID:** `participant.team_overspend`

**Test prompt:** "How much is each team overspending compared to actual
usage?"

<details>
<summary><strong>Example ES|QL solution</strong> (click to reveal - instructor hint)</summary>

```sql
FROM gcp-resource-executions-*
| STATS total_cost = SUM(cost_actual.total_cost_usd),
        avg_drift  = AVG(drift_metrics.combined_drift_score),
        avg_cpu    = AVG(resource_usage.cpu.avg_percent),
        avg_mem    = AVG(resource_usage.memory.avg_percent)
    BY metadata.team
| EVAL waste_usd = total_cost * avg_drift / 100
| SORT waste_usd DESC
| LIMIT 15
```

The `EVAL waste_usd = total_cost * avg_drift / 100` step estimates the
dollars each team is spending on resources they aren't using — the
headline number the agent will narrate back.

</details>

---

## Register and wire your tool (UI)

Once your query works in Discover, follow the same UI flow you used in
Challenge 3 — no terminal needed.

### Register the tool (As you did in the previous challenge)


### Wire it into the Kafeju agent (As you did in the previous challenge)


## Test your tool

Go to **Kibana > AI Agent > Kafeju** and ask the **test prompt**
from your card. Expand the **reasoning panel** under
Kafeju's answer and confirm `participant.YOUR_TOOL_NAME` was the
tool that ran.

> **If the agent picks a different tool:** revisit your tool's
> **description** in Agent Builder. Add the exact phrasing a user
> would use (e.g. *"Use when asked about regional pricing, cheapest
> region, or region cost comparison"*). Description text is routing
> logic — make it explicit.

## Check your work
===
The automated check verifies that at least **two** participant tools
exist (the zombie detector from Challenge 3 + your new tool) and that
both are attached to the Kafeju agent.

Before clicking **Check**, confirm in the UI:
- The **Tools** tab shows your new `participant.*` tool.
- The **Agents** tab > **Kafeju** page lists it alongside the
  zombie detector.
- Kafeju invoked your new tool in response to the card's test prompt.
