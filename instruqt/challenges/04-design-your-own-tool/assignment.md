---
slug: design-your-own-tool
title: "Design Your Own Tool"
teaser: "Choose a challenge card, design an ES|QL query, and build a tool the agent couldn't use before."
type: challenge
timelimit: 2400
tabs:
  - title: Kibana
    type: service
    hostname: elastic-vm
    port: 5601
notes:
  - type: text
    contents: |
      # Design Your Own Tool

      You have built one guided tool. Now it is time to design one yourself.

      Choose a challenge card below based on your comfort level. Each card
      gives you a business question, a target index, and hints — but you
      write the ES|QL query and register the tool yourself.

      **Remember the pattern:**
      1. Explore the index in Discover to understand the fields
      2. Write an ES|QL query that answers the business question
      3. Test the query in Discover (does it return useful results?)
      4. Register it as a tool in the Agent Builder UI
      5. Wire it into the Kafeju agent in the Agents tab
      6. Test with a natural-language prompt
---

# Challenge 4: Design Your Own Tool

Pick one of the challenge cards below. Each represents a real question
that the Kafeju agent currently cannot answer.

---

## Challenge Card A: Regional Cost Comparison (Difficulty: 1 star)

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
<summary><strong>Example ES|QL solution</strong> (click to reveal — instructor hint)</summary>

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

## Challenge Card B: Weekly Cost Trends (Difficulty: 2 stars)

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
<summary><strong>Example ES|QL solution</strong> (click to reveal — instructor hint)</summary>

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

## Challenge Card C: Growth Predictions (Difficulty: 2 stars)

**Business question:** "Which teams will need more capacity soonest?"

**Data view:** **ML Growth Predictions** (ES|QL index pattern:
`ml-predictions-growth-*`)

**Explore first:**
```sql
FROM ml-predictions-growth-*
| LIMIT 10
```

**Useful fields:** `team`, `current_avg_cpu`, `growth_rate_daily`,
`predicted_days_to_90pct`, `recommendation`

**Hints:**
- Filter where `predicted_days_to_90pct` is small (e.g. `< 60`) —
  most urgent first
- Sort by `predicted_days_to_90pct ASC`
- Include `recommendation` (values include `URGENT_RESIZE`,
  `PLAN_RESIZE`, `MONITOR`)
- `growth_rate_daily` is a fractional daily growth rate (e.g. `0.12`
  = 12% per day). Multiply by 100 to show a percentage.

**Suggested tool ID:** `participant.capacity_forecast`

**Test prompt:** "Which teams will need more capacity soonest?"

<details>
<summary><strong>Example ES|QL solution</strong> (click to reveal — instructor hint)</summary>

```sql
FROM ml-predictions-growth-*
| WHERE predicted_days_to_90pct < 60
| STATS latest_days = MIN(predicted_days_to_90pct),
        latest_growth = AVG(growth_rate_daily),
        latest_cpu    = AVG(current_avg_cpu),
        latest_reco   = VALUES(recommendation)
    BY team
| EVAL growth_pct_per_day = ROUND(latest_growth * 100, 2)
| KEEP team, latest_cpu, growth_pct_per_day, latest_days, latest_reco
| SORT latest_days ASC
| LIMIT 20
```

Note: the growth index has one document per (team, day) snapshot.
The `STATS ... BY team` pass collapses the snapshots into one row
per team with the most-urgent days-to-90% and the latest
recommendation.

</details>

---

## Challenge Card D: Team Overspend Analysis (Difficulty: 3 stars)

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
<summary><strong>Example ES|QL solution</strong> (click to reveal — instructor hint)</summary>

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

## Register and Wire Your Tool (UI)

Once your query works in Discover, follow the same UI flow you used in
Challenge 3 — no terminal needed.

### Register the tool

1. Hamburger menu > **Agent Builder** > **Tools** tab.
2. Click **Create** (or **New tool**).
3. Fill in the form:

   | Field | Value |
   |-------|-------|
   | **Tool ID** | `participant.YOUR_TOOL_NAME` (e.g. the suggested ID on your card) |
   | **Type** | `ESQL` |
   | **Description** | A sentence or two describing *when* the agent should call this tool. Be specific — this is routing logic for the AI. |
   | **Labels** | `participant` (plus any others from the card, e.g. `cost`, `infrastructure`) |
   | **ES\|QL Query** | Paste your query from Discover |

4. Click **Save & Test** and **Submit**. Confirm the `tabular_data`
   response has the columns you expect.
5. Click **Save** to persist the tool.

### Wire it into the Kafeju agent

1. In Agent Builder, click the **Agents** tab.
2. Open the **Kafeju** agent and click **Edit** (pencil icon).
3. Scroll to the **Tools** section.
4. Click **Add tool**, search for `participant`, and select your new
   tool.
5. Click **Save** (or **Update agent**).

## Test Your Tool

Go to **Kibana > AI Assistant > Kafeju** and ask the **test prompt**
from your card. Expand the **tool-call / reasoning panel** under
Kafeju's answer and confirm `participant.YOUR_TOOL_NAME` was the
tool that ran.

> **If the agent picks a different tool:** revisit your tool's
> **description** in Agent Builder. Add the exact phrasing a user
> would use (e.g. *"Use when asked about regional pricing, cheapest
> region, or region cost comparison"*). Description text is routing
> logic — make it explicit.

## Check Your Work

The automated check verifies that at least **two** participant tools
exist (the zombie detector from Challenge 3 + your new tool) and that
both are attached to the Kafeju agent.

Before clicking **Check**, confirm in the UI:
- The **Tools** tab shows your new `participant.*` tool.
- The **Agents** tab > **Kafeju** page lists it alongside the
  zombie detector.
- Kafeju invoked your new tool in response to the card's test prompt.
