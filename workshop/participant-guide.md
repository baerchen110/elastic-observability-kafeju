# Workshop: GCP Resource Drift Detection with Elastic Agent Builder

## Participant Guide

Welcome! In this workshop you will use Elastic's Agent Builder tools to analyze GCP VM resource utilization, detect over-provisioned instances, and build cost optimization recommendations.

**What you will need:**
- Kibana URL and credentials (provided by the facilitator)
- A web browser

**How Agent Builder works:**
Agent Builder tools are pre-built ES|QL queries wrapped as natural-language tools. You invoke them by typing natural language prompts in the Kibana AI Assistant. The tool translates your request into a query, executes it, and returns structured results.

---

## Module 1: Introduction and Setup (30 min)

### The Scenario

Your company runs hundreds of GCP VMs across 9 teams. Monthly cloud spend is climbing, but nobody knows how much is wasted on over-provisioned resources. Your job: find the waste and recommend fixes.

### The Data

Your Elastic deployment contains 12 indices with real and synthetic GCP data:

| Index Pattern | What It Contains |
|---------------|-----------------|
| `gcp-resource-executions-*` | VM execution records: CPU/memory usage, drift metrics, costs |
| `gcp-instance-lifecycle*` | VM lifecycle events: uptime, status, creation timestamps |
| `gcp-billing-actual` | Billing records: costs, credits, usage by team |
| `gcp-pricing-catalog` | GCP machine type pricing catalog |
| `gcp-vm-pricing` | VM pricing by machine type and region |
| `gcp-workload-requirements` | Workload resource requirements (CPU, memory, SLA) |
| `ml-predictions-*` | ML anomaly detections, cost forecasts, growth trends |

### Exercise 1.1: Explore the Data

1. Open Kibana and navigate to **Discover**
2. Select the `gcp-resource-executions-*` index pattern
3. Set the time range to **Last 1 year**
4. Examine a few documents. Find and note:
   - What does `drift_metrics.combined_drift_score` represent?
   - What is the difference between `resource_usage.cpu.avg_percent` and `resource_usage.cpu.p95_percent`?
   - Which field tells you the team responsible for a VM?

**Expected outcome:** You understand the data model and can identify the key fields for drift analysis.

---

## Module 2: Understanding Resource Drift (45 min)

### What is Resource Drift?

Resource drift is the gap between what a team *allocated* (the VM size they requested) and what they *actually use*. A drift of 60% means a team is only using 40% of their allocated capacity -- the rest is waste.

### Exercise 2.1: Identify High-Drift VMs

Open the Kibana AI Assistant and type:

> "Analyze our VM usage patterns. Show me where resource drift is highest, broken down by team and machine type."

This invokes `kafeju.analyze_vm_usage_patterns`.

**Questions to answer:**
1. Which team has the highest average `combined_drift`?
2. Which machine type appears most in the high-drift results?
3. If a team has 70% CPU drift, what does that mean in practical terms?

### Exercise 2.2: Team Efficiency Report

Type in the AI Assistant:

> "Compare what each team has allocated versus what they actually use. Rank teams by efficiency."

This invokes `kafeju.compare_team_request_vs_usage`.

**Questions to answer:**
1. Which 3 teams have the lowest efficiency scores?
2. For the least efficient team, what is their average CPU and memory usage percentage?
3. What would you recommend to this team?

**Expected outcome:** You can identify the 3 most wasteful teams, explain why their efficiency scores are low, and articulate a recommendation.

---

## Module 3: Anomaly Detection (45 min)

### Exercise 3.1: Find ML-Detected Anomalies

Type in the AI Assistant:

> "Detect resource anomalies across our VMs. Show me any VMs with unusual usage patterns."

This invokes `kafeju.detect_resource_anomalies`.

**Questions to answer:**
1. How many CRITICAL anomalies are there?
2. What does a high `record_score` indicate?
3. For the highest-scoring anomaly, what was the `typical` value vs the `actual` value?

### Exercise 3.2: Classify Team Workload Patterns

Type:

> "Identify which teams have unusual workload patterns. Classify workloads as heavy, light, or normal."

This invokes `kafeju.detect_team_anomalies`.

**Questions to answer:**
1. Which teams have HEAVY_USER workloads?
2. Are the HEAVY_USER classifications justified based on the workload type?
3. Which teams have LIGHT_USER workloads that might indicate zombie VMs?

### Exercise 3.3: Visualize Anomaly Trends

1. Open the **Anomaly Detection & Capacity Planning** dashboard
2. Examine the anomaly timeline chart
3. Answer: Which week had the most anomalies? Which team contributed most?

**Expected outcome:** You can explain the difference between HIGH and CRITICAL anomalies, identify potential zombie VMs, and interpret ML anomaly scores.

---

## Module 4: Cost Optimization (30 min)

### Exercise 4.1: Build a Savings Report

Type in the AI Assistant:

> "Calculate cost optimization opportunities from rightsizing our VMs. Focus on instances with drift above 20%."

This invokes `kafeju.calculate_cost_optimization_1`.

**Follow up with:**

> "Find similar workloads that could be consolidated."

This invokes `kafeju.find_similar_workloads`.

**Questions to answer:**
1. What is the total cost of high-drift VMs?
2. Which team/VM-type combination has the highest total cost with high drift?
3. Are there workload types running on different machine types that could be standardized?

### Exercise 4.2: Instance Recommendations

Type:

> "Recommend the best GCP instance type for a workload that needs 8 vCPUs and 32 GB memory."

This invokes `kafeju.recommend_instance_for_requirements`.

**Questions to answer:**
1. What is the cheapest instance type that meets these requirements?
2. What is the price difference between the cheapest and second-cheapest option?
3. When would you choose a more expensive option?

### Exercise 4.3: Cost Projection

Type:

> "Show me the 30-day cost projection based on recent trends."

This invokes `kafeju.get_cost_projection`.

**Expected outcome:** You can produce a cost optimization report with specific dollar savings and justified instance recommendations.

---

## Module 5: Build Your Own Tool (30 min)

### How Agent Builder Tools Work

Each tool consists of:
- **Name:** A human-readable identifier
- **Description:** Explains what the tool does (used by the AI to decide when to invoke it)
- **ES|QL query:** The actual query that runs against Elasticsearch

### Exercise 5.1: Zombie VM Detector

Create a new Agent Builder tool that identifies VMs running longer than 7 days with less than 10% CPU utilization.

**Tool definition:**
- Name: `Detect Zombie VMs`
- Description: `Identifies VMs running for more than 7 days with very low CPU utilization (under 10%), indicating possible zombie instances that should be terminated.`
- ES|QL query:

```
FROM gcp-resource-executions-*
| WHERE drift_metrics.cpu.drift_percent > 90
| STATS count = COUNT(*),
        avg_cpu = AVG(resource_usage.cpu.avg_percent),
        total_waste_usd = SUM(cost_actual.total_cost_usd)
  BY metadata.team.keyword, vm_info.vm_type_actual.keyword
| SORT total_waste_usd DESC
```

**Steps:**
1. In Kibana, navigate to the Agent Builder tool creation interface
2. Enter the name, description, and ES|QL query above
3. Save the tool
4. Test by asking: "Find zombie VMs in our infrastructure"

### Exercise 5.2: Regional Cost Comparison

Create a tool that compares the cost-per-vCPU across regions.

**Design the query yourself** using the `gcp-vm-pricing` index. Hints:
- Use `STATS ... BY` to group by region
- Calculate `cost_per_core = AVG(pricing.price_per_hour_usd) / MAX(pricing.cpu_cores)`
- Sort by cost_per_core to find the cheapest region

**Expected outcome:** You have created and tested at least one custom Agent Builder tool, and can explain the three components (name, description, ES|QL query) required to build one.

---

## Summary

Today you learned to:

1. **Explore GCP resource data** stored in Elasticsearch
2. **Detect resource drift** -- the gap between allocated and actual VM usage
3. **Use ML anomaly detection** to find unusual patterns and zombie VMs
4. **Build cost optimization recommendations** with specific savings
5. **Create custom Agent Builder tools** powered by ES|QL

### Next Steps

- Apply these techniques to your own GCP data
- Create additional tools for your specific use cases
- Explore Kibana dashboards for continuous monitoring
- Set up alerting rules for drift thresholds
