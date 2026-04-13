# GCP Resource Drift Detection Demo

**Duration:** 15 minutes
**Target audience:** DevOps engineers, Cloud Architects, FinOps teams

## Prerequisites

- Kibana access to the hosted deployment
- All 3 dashboards imported (see `dashboards/` NDJSON files)
- Agent Builder tools recreated on the hosted deployment
- Synthetic data generated and indexed

Run `demo/setup.sh` to verify readiness before the demo.

---

## Act 1: The Problem (3 minutes)

### Talking Point

> "Your team runs hundreds of GCP VMs. Monthly bill keeps climbing.
> But how much of that spend is *actually necessary*?"

### Steps

1. **Open Dashboard 1: GCP Resource Drift Overview**
   - Point to the **Total Cost** metric -- "This is what we've spent."
   - Point to the **Avg Drift %** metric -- "And this is how much of our allocated resources are *not being used*."
   - Pause: "A 50% drift means teams are using half of what they asked for."

2. **Invoke Agent Builder tool via AI Assistant:**

   > "Show me the GCP pricing catalog for all available instance types."

   This calls `kafeju.get_instance_cost_and_specs`. Walk through a few instance types showing the price range from $0.03/hr to $1.50/hr.

3. **Set the hook:**

   > "We have the data. We have the pricing. Now let's find where the waste is."

---

## Act 2: Discovery with Agent Builder (7 minutes)

### 2a. Resource Drift Analysis

**Invoke:**

> "Analyze our VM usage patterns and show me where drift is highest."

This calls `kafeju.analyze_vm_usage_patterns`. Walk through the results:
- Highlight teams with `combined_drift > 50` -- "These teams are using less than half their allocated resources."
- Point out specific VM types: "n2-standard-16 with 25% CPU usage -- they could drop to n2-standard-4."

### 2b. ML Anomaly Detection

**Invoke:**

> "Detect any resource anomalies across our VMs."

This calls `kafeju.detect_resource_anomalies`. Show the results:
- CRITICAL anomalies: "This VM jumped to 95% CPU when its typical is 42% -- possible runaway process."
- Zombie VMs: "This one has been running at 2% CPU for two weeks."

**Switch to Dashboard 3: Anomaly Detection & Capacity Planning**
- Point to the Anomaly Timeline chart -- show the spikes by team
- Point to the severity pie chart -- "Most are HIGH or CRITICAL. These need attention."

### 2c. Team Efficiency Scoreboard

**Invoke:**

> "Compare what each team requested versus what they actually use."

This calls `kafeju.compare_team_request_vs_usage`. Show the efficiency scoreboard:
- "Lower efficiency score means more waste."
- "Team X has a score of 28 -- they're using less than a third of what's allocated."

**Follow up:**

> "Classify each team's workloads as heavy, light, or normal users."

This calls `kafeju.detect_team_anomalies`. Show the classification:
- "The ml-ops team has HEAVY_USER workloads -- that's expected for ML training."
- "But devops-infra is classified LIGHT_USER on most workloads. They should downsize."

### 2d. VM Sizing Deep Dive

**Invoke:**

> "Show me the VM sizing analysis -- where are we most over-provisioned?"

This calls `kafeju.get_vm_sizing_analysis`. Walk through P95 usage vs allocated.

---

## Act 3: Actionable Recommendations (5 minutes)

### 3a. Cost Optimization Report

**Invoke:**

> "Calculate our cost optimization opportunities from rightsizing."

This calls `kafeju.calculate_cost_optimization_1`. Show results:
- "By rightsizing the top 10 over-provisioned VM groups, we save $X per month."
- "That's Y% of total spend -- with zero performance impact since P95 usage is well below allocated."

**Switch to Dashboard 2: Cost Optimization Opportunities**
- Point to the **Potential Savings** gauge
- Show the cost-by-team pie chart -- "Here's where the money goes."

### 3b. Instance Recommendations

**Invoke:**

> "For a workload needing 4 vCPUs and 16 GB memory, what's the cheapest option?"

This calls `kafeju.recommend_instance_for_requirements`. Show the ranked options:
- "e2-standard-4 at $0.13/hr vs n2-standard-4 at $0.19/hr -- 32% savings for the same specs."

### 3c. Capacity Planning

**Invoke:**

> "Which teams will hit 90% capacity soonest? Show me resize predictions."

This calls `kafeju.predict_resize_needs`. Show the timeline:
- "The analytics team will hit 90% in 12 days at current growth. We should proactively resize."
- "Data-platform is stable -- no action needed."

**Invoke:**

> "What's our 30-day cost projection based on current trends?"

This calls `kafeju.get_cost_projection`. Show the daily cost trend.

### Closing

> "In 15 minutes, Elastic Agent Builder gave us:
> - Visibility into $X of annual waste from over-provisioned VMs
> - ML-detected anomalies including zombie VMs and runaway processes
> - Specific rightsizing recommendations with projected savings
> - Proactive capacity alerts before teams hit limits
>
> All powered by ES|QL queries against your real GCP data.
> No custom code. No external tools. Just Elastic."

---

## KPIs to Reference During Demo

| KPI | Where Shown | Target Value |
|-----|-------------|--------------|
| Average drift % | Dashboard 1, metric panel | 40-60% demonstrates significant waste |
| Potential savings | Dashboard 2, gauge | Dollar amount from high-drift VMs |
| Team efficiency spread | Agent Builder output | Range from 20% to 80% shows variance |
| Anomaly count (CRITICAL) | Dashboard 3, pie chart | 5+ shows ML is detecting real issues |
| Days to 90% capacity | Agent Builder output | <30 days for at least one team |
| Rightsizing match accuracy | Agent Builder output | Cheaper instance meets P95 requirements |
