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
  - title: Terminal
    type: terminal
    hostname: elastic-vm
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
      4. Register it as a tool via the API
      5. Wire it into the Kafeju agent
      6. Test with a natural-language prompt
---

# Challenge 4: Design Your Own Tool

Pick one of the challenge cards below. Each represents a real question
that the Kafeju agent currently cannot answer.

---

## Challenge Card A: Regional Cost Comparison (Difficulty: 1 star)

**Business question:** "Which GCP region is cheapest for running VMs?"

**Index:** `gcp-pricing-catalog`

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

**Index:** `gcp-billing-actual`

**Explore first:**
```sql
FROM gcp-billing-actual
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
FROM gcp-billing-actual
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

**Index:** `ml-predictions-growth-summary`

**Explore first:**
```sql
FROM ml-predictions-growth-summary
| LIMIT 10
```

**Useful fields:** `team`, `workload_type`,
`growth_rate_percent_per_week`, `weeks_until_90_percent_capacity`,
`recommendation`, `confidence`

**Hints:**
- Filter where `weeks_until_90_percent_capacity` is small (< 20)
- Sort by `weeks_until_90_percent_capacity ASC` (most urgent first)
- Include `recommendation` and `confidence` in output

**Suggested tool ID:** `participant.capacity_forecast`

**Test prompt:** "Which teams will need more capacity soonest?"

<details>
<summary><strong>Example ES|QL solution</strong> (click to reveal — instructor hint)</summary>

```sql
FROM ml-predictions-growth-summary
| WHERE weeks_until_90_percent_capacity < 20
| KEEP team, workload_type, growth_rate_percent_per_week,
       weeks_until_90_percent_capacity, recommendation, confidence
| SORT weeks_until_90_percent_capacity ASC
| LIMIT 20
```

</details>

---

## Challenge Card D: Team Overspend Analysis (Difficulty: 3 stars)

**Business question:** "How much is each team overspending vs actual
usage?"

**Index:** `gcp-resource-executions-*`

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

## Registration Template

Once your query works in Discover, register it via the Terminal:

```bash
curl -s -X POST http://localhost:5601/api/agent_builder/tools \
  -u elastic:workshopAdmin1! \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "participant.YOUR_TOOL_NAME",
    "description": "YOUR DESCRIPTION — be specific about when the AI should use this",
    "tags": ["participant"],
    "configuration": {
      "query": "YOUR ESQL QUERY (use \\n for newlines within the string)",
      "params": {}
    }
  }'
```

Then wire it into the agent:

```bash
curl -s -u elastic:workshopAdmin1! \
  http://localhost:5601/api/agent_builder/agents \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
agents = json.load(sys.stdin)['results']
kafeju = next(a for a in agents if a['id'] == 'kafuju')
tools = kafeju['configuration']['tools'][0]['tool_ids']
new_tool = 'participant.YOUR_TOOL_NAME'  # <-- CHANGE THIS
if new_tool not in tools:
    tools.append(new_tool)
kafeju.pop('readonly', None)
kafeju.pop('type', None)
print(json.dumps(kafeju))
" > /tmp/agent-update.json

curl -s -X PUT http://localhost:5601/api/agent_builder/agents/kafuju \
  -u elastic:workshopAdmin1! \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d @/tmp/agent-update.json
```

## Test Your Tool

Go to **Kibana > AI Assistant > Kafeju** and ask your test prompt. The
agent should invoke your new tool and return structured results.

## Check Your Work

The check verifies that at least **two** participant tools exist (the
zombie detector from Challenge 3 + your new tool).
