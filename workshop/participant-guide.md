# Workshop 2: Build Your Own AI Agent — From Consumer to Creator

## Participant Guide

Welcome! In the previous workshop you used the Elastic AI Assistant to investigate issues in an OpenTelemetry demo. The tools were built-in. In this workshop, you become the builder — creating your own tools and wiring them into a custom agent.

**What you will need:**
- Kibana URL and credentials (provided by the facilitator)
- A web browser
- A terminal (provided in the Instruqt lab)

**What you will build:**
- At least one custom Agent Builder tool powered by ES|QL
- Wire it into a real agent and validate it answers questions it couldn't before

---

## Module 1: From Consumer to Creator (20 min)

### The Story So Far

In Workshop 1, you deployed the OpenTelemetry demo, verified telemetry in Kibana, injected failures, and used the Observability AI Assistant to investigate. The tools you used — service health checks, log analysis, trace correlation — were all built-in.

But what happens when you need analysis that no built-in tool provides?

### Meet the Kafeju Agent

Kafeju is a custom GCP cost-optimization agent built with Elastic Agent Builder. It analyzes VM resource utilization, detects drift between allocated and actual usage, and recommends rightsizing.

Your facilitator will demonstrate:
1. Asking Kafeju: *"Which teams are wasting the most money on idle VMs?"*
2. Then asking: *"Which GCP region is cheapest for n2-standard-8 instances?"*

The first question works. The second one fails — no tool exists for that analysis. **By the end of this workshop, you will build the tool that answers it.**

### How Agent Builder Works

Every agent has two components:

| Component | What It Does |
|-----------|-------------|
| **Instructions** | A system prompt telling the AI its role, domain expertise, and guidelines |
| **Tools** | A list of tool IDs the agent can invoke to get data |

Every tool has three components:

| Component | What It Does |
|-----------|-------------|
| **ID** | Unique identifier (e.g. `kafeju.analyze_vm_usage_patterns`) |
| **Description** | Tells the AI *when* to use this tool (critical for routing) |
| **ES\|QL Query** | The actual query that runs against Elasticsearch |

That's it. No custom code. No external services. Just a query wrapped with metadata.

---

## Module 2: Explore the Data and Dissect a Tool (30 min)

### The Data

Your Elastic deployment contains 15 indices with GCP infrastructure data:

| Index Pattern | What It Contains |
|---------------|-----------------|
| `gcp-resource-executions-*` | VM execution records: CPU/memory usage, drift metrics, costs |
| `gcp-instance-lifecycle*` | VM lifecycle events: uptime, status, creation timestamps |
| `gcp-billing-actual` | Billing records: costs (`billing.cost.amount`), team (`gcp.labels.team`) |
| `gcp-pricing-catalog` | GCP machine type pricing catalog (30 types) |
| `gcp-vm-pricing` | VM pricing by machine type and region |
| `gcp-workload-requirements` | Workload resource requirements (CPU, memory, SLA) |
| `gcp-requested-resources` | Resource configurations requested by teams |
| `gcp-instance-inventory-*` | Daily instance snapshots |
| `ml-predictions-*` | ML anomaly detections, cost forecasts, growth trends |

### Exercise 2.1: Explore the Data (10 min)

1. Open Kibana and navigate to **Discover**
2. Select the `gcp-resource-executions-*` data view
3. Set the time range to **Last 1 year**
4. Examine a few documents. Find and note:
   - What does `drift_metrics.combined_drift_score` represent?
   - What is the difference between `resource_usage.cpu.avg_percent` and `resource_usage.cpu.p95_percent`?
   - Which field tells you the team responsible for a VM?
   - Which field shows the cost of running this VM?

**Tip:** Expand a document and look at the field list. The key fields are under `drift_metrics.*`, `resource_usage.*`, `metadata.*`, and `cost_actual.*`.

### Exercise 2.2: Dissect an Existing Tool (10 min)

Open the **Terminal** tab and run:

```bash
curl -s -u elastic:${PASSWORD} \
  http://localhost:5601/api/agent_builder/tools \
  -H "kbn-xsrf: true" | python3 -m json.tool | head -80
```

Find the tool `kafeju.analyze_vm_usage_patterns`. Note:
1. Its **ID**: `kafeju.analyze_vm_usage_patterns`
2. Its **description**: What does it say? When would the AI use it?
3. Its **ES|QL query**: Copy the query from `configuration.query`

Now run that ES|QL query directly in **Discover > ES|QL mode** to see the raw results. Then go to the **AI Assistant**, select the Kafeju agent, and ask:

> "Show me VM usage patterns and where drift is highest."

Compare the raw query results with the agent's interpreted answer. The tool provides the data; the AI provides the narrative.

### Exercise 2.3: Spot the Gap (10 min)

Test these three questions in the Kafeju agent. Record which ones get a data-driven answer and which ones fail:

1. *"Show me VM usage patterns"* — Does it work? Which tool is used?
2. *"What's the cheapest region for my workload?"* — Does it work?
3. *"Show me weekly cost trends per team"* — Does it work?

**Expected outcome:** Questions 2 and 3 fail because no tool exists for those analyses. This is the gap you will fill.

---

## Module 3: Build Your First Tool (40 min)

### The Concept: Zombie VM Detector

A "zombie VM" is a virtual machine that has been running for a long time with extremely low CPU utilization — it's costing money but doing nothing useful. Every cloud team has them.

Your goal: build a tool that finds VMs with <15% CPU usage, grouped by team and machine type, showing the total wasted cost.

### Step 1: Design the Query (5 min)

Think about what you need:
- **Source:** `gcp-resource-executions-*` (has CPU usage and cost data)
- **Filter:** CPU usage below 15%
- **Aggregate:** Group by team, VM type, and resource name
- **Metrics:** Average CPU, average drift, total cost, count
- **Sort:** By cost descending (most expensive zombies first)

### Step 2: Write and Test the Query (10 min)

Go to **Discover > ES|QL mode** and run this query:

```sql
FROM gcp-resource-executions-*
| WHERE resource_usage.cpu.avg_percent < 15
  AND vm_info.vm_type_actual IS NOT NULL
| STATS
    avg_cpu = AVG(resource_usage.cpu.avg_percent),
    avg_drift = AVG(drift_metrics.combined_drift_score),
    total_cost = SUM(cost_actual.total_cost_usd),
    occurrences = COUNT(*)
  BY metadata.team, vm_info.vm_type_actual, resource_name
| SORT total_cost DESC
| LIMIT 15
```

You should see results showing teams with low-CPU VMs and their associated costs. If you get results, the query works.

### Step 3: Register the Tool (10 min)

Open the **Terminal** tab and run this command (copy the entire block):

```bash
curl -s -X POST http://localhost:5601/api/agent_builder/tools \
  -u elastic:${PASSWORD} \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "participant.find_zombie_vms",
    "description": "Finds zombie VMs: machines with very low CPU usage (under 15%) that are wasting money. Shows which teams have idle resources ranked by total cost waste. Use when asked about zombie VMs, idle instances, or wasted resources.",
    "tags": ["participant", "infrastructure", "cost"],
    "configuration": {
      "query": "FROM gcp-resource-executions-*\n| WHERE resource_usage.cpu.avg_percent < 15\n  AND vm_info.vm_type_actual IS NOT NULL\n| STATS\n    avg_cpu = AVG(resource_usage.cpu.avg_percent),\n    avg_drift = AVG(drift_metrics.combined_drift_score),\n    total_cost = SUM(cost_actual.total_cost_usd),\n    occurrences = COUNT(*)\n  BY metadata.team, vm_info.vm_type_actual, resource_name\n| SORT total_cost DESC\n| LIMIT 15",
      "params": {}
    }
  }'
```

You should see a response containing `"id": "participant.find_zombie_vms"`.

### Step 4: Wire It Into the Agent (5 min)

Now add your tool to the Kafeju agent so it can use it. Run:

```bash
# First, get the current agent definition
curl -s -u elastic:${PASSWORD} \
  http://localhost:5601/api/agent_builder/agents \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
agents = json.load(sys.stdin)['results']
kafeju = next(a for a in agents if a['id'] == 'kafuju')
tools = kafeju['configuration']['tools'][0]['tool_ids']
if 'participant.find_zombie_vms' not in tools:
    tools.append('participant.find_zombie_vms')
kafeju.pop('readonly', None)
kafeju.pop('type', None)
print(json.dumps(kafeju))
" > /tmp/agent-update.json

# Then update the agent
curl -s -X PUT http://localhost:5601/api/agent_builder/agents/kafuju \
  -u elastic:${PASSWORD} \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d @/tmp/agent-update.json
```

### Step 5: Test Your Tool (10 min)

Go back to the **Kibana** tab, open the **AI Assistant**, select the **Kafeju** agent, and ask:

> **"Find zombie VMs — which expensive instances are sitting idle and wasting money?"**

The agent should invoke your new `participant.find_zombie_vms` tool and return structured results showing teams, VM types, CPU percentages, and dollar waste.

**Compare:** Think back to Exercise 2.3 — this type of question would have failed before. Now it produces real data.

**Expected outcome:** You have created a working Agent Builder tool that the AI can invoke via natural language.

---

## Module 4: Design Your Own Tool Challenge (40 min)

### The Challenge

Pick one of the challenge cards below. Your goal: design an ES|QL query, register it as a tool, wire it into the agent, and test it.

### Challenge Card A: Regional Cost Comparison (1 star)

**Question the agent can't answer:** *"Which GCP region is cheapest for my workload type?"*

**Index:** `gcp-pricing-catalog`

**Useful fields:** `region`, `machine_type`, `cpu_cores`, `memory_gb`, `cost_per_hour_usd`, `cost_per_month_usd`

**Hints:**
- Use `STATS ... BY region` to group by region
- Calculate average cost metrics per region
- Sort by cheapest first

**Test prompt:** "Which GCP region is cheapest for running VMs?"

---

### Challenge Card B: Weekly Cost Trends (2 stars)

**Question the agent can't answer:** *"Show me weekly cost trends per team for the last month."*

**Index:** `gcp-billing-actual`

**Useful fields:** `@timestamp`, `billing.cost.amount`, `gcp.labels.team`, `service.name`

**Hints:**
- Use `EVAL week = DATE_TRUNC(7 days, @timestamp)` to bucket by week
- Use `STATS ... BY gcp.labels.team, week`
- Sort by week to show the trend

**Test prompt:** "Show me weekly cost trends per team."

---

### Challenge Card C: Growth Predictions (2 stars)

**Question the agent can't answer:** *"Which teams have the most growth and will need more capacity soon?"*

**Index:** `ml-predictions-growth-summary`

**Useful fields:** `team`, `workload_type`, `growth_rate_percent_per_week`, `weeks_until_90_percent_capacity`, `recommendation`, `confidence`

**Hints:**
- Filter where `weeks_until_90_percent_capacity` is low (e.g. < 20)
- Sort by `weeks_until_90_percent_capacity ASC` (most urgent first)
- Include the `recommendation` and `confidence` fields

**Test prompt:** "Which teams will need more capacity soonest?"

---

### Challenge Card D: Requested vs Actual Cost (3 stars)

**Question the agent can't answer:** *"Compare the cost of actual VM usage versus what was originally requested."*

**Index:** `gcp-resource-executions-*`

**Useful fields:** `cost_actual.total_cost_usd`, `drift_metrics.combined_drift_score`, `metadata.team`, `resource_usage.cpu.avg_percent`, `resource_usage.memory.avg_percent`

**Hints:**
- Group by team
- Calculate total actual cost, average drift, and efficiency metrics
- Use `EVAL` to compute a "waste_usd" estimate (cost * drift / 100)
- Sort by waste descending

**Test prompt:** "How much are we overspending per team compared to actual usage?"

---

### Steps (Same for All Cards)

1. **Write your query** in Discover > ES|QL mode. Verify it returns results.
2. **Register it** via the Terminal using the curl template:

```bash
curl -s -X POST http://localhost:5601/api/agent_builder/tools \
  -u elastic:${PASSWORD} \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "participant.YOUR_TOOL_NAME",
    "description": "YOUR DESCRIPTION — explain when the AI should use this tool",
    "tags": ["participant"],
    "configuration": {
      "query": "YOUR ESQL QUERY HERE (use \\n for newlines)",
      "params": {}
    }
  }'
```

3. **Wire it into the agent** (same pattern as Module 3, Step 4).
4. **Test it** in the AI Assistant with a natural-language prompt.

### Sharing (Last 10 min)

When the facilitator calls time, 2-3 volunteers will share:
- What question their tool answers
- A quick demo of asking the agent

---

## Module 5: Getting Further (30 min)

### The Compound Question

Now that the agent has both participant-built tools and the original Kafeju tools, the facilitator will demonstrate a compound question:

> "I just found zombie VMs in my infrastructure. Can you tell me which region would be cheapest to move the surviving workloads to, and estimate my monthly savings if I rightsize and relocate?"

Watch how the agent chains:
1. Your **zombie VM tool** (finds the idle instances)
2. The **regional pricing tool** (identifies cheaper regions)
3. The existing **`kafeju.recommend_instance_for_requirements`** (recommends instance types)

...to produce a comprehensive FinOps answer that would take a human analyst hours.

### Key Takeaways

1. **Every Agent Builder tool is just 3 things:** ID, description, ES|QL query
2. **You can build a tool in 5 minutes**, not 5 sprints
3. **Good descriptions are critical** — they tell the AI *when* to use your tool
4. **Tools can be chained** — compound questions use multiple tools together
5. **The difference between "using" and "building"** is just one curl command

### What You Built Today

- Explored GCP resource data in Elasticsearch
- Dissected an existing Agent Builder tool to understand its anatomy
- Built a Zombie VM Detector tool from scratch
- Designed your own tool for a real business question
- Wired tools into a custom agent
- Saw multi-tool chaining produce compound answers

### Next Steps

- Apply these techniques to your own data and use cases
- Create tools for your team's specific analysis needs
- Explore agent system prompt design for domain specialization
- Set up alerting rules for drift thresholds
- Reference: [elastic-observability-kafeju repo](https://github.com/baerchen110/elastic-observability-kafeju)

---

## Quick Reference: ES|QL Cheat Sheet

| Command | What It Does | Example |
|---------|-------------|---------|
| `FROM` | Select the index | `FROM gcp-billing-actual` |
| `WHERE` | Filter rows | `WHERE cpu > 50 AND team == "analytics"` |
| `STATS` | Aggregate | `STATS avg_cpu = AVG(cpu) BY team` |
| `EVAL` | Add computed columns | `EVAL waste = cost * drift / 100` |
| `SORT` | Order results | `SORT waste DESC` |
| `LIMIT` | Cap the result count | `LIMIT 20` |

**Pattern for most tools:**

```sql
FROM <index>
| WHERE <filter conditions>
| STATS <aggregations> BY <group-by fields>
| EVAL <computed fields>
| SORT <order field> DESC
| LIMIT <N>
```
