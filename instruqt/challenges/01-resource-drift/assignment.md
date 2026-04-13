---
slug: resource-drift-detection
title: "Detect GCP Resource Drift"
teaser: "Use Agent Builder tools to find over-provisioned VMs and quantify resource waste."
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
      # What is Resource Drift?

      Resource drift occurs when the resources **allocated** to a VM differ
      significantly from what it **actually uses**. A team running an
      n2-standard-32 (32 vCPU, 128 GB RAM) at 8% CPU utilization has massive
      drift — and massive waste.

      In this challenge you will use Elastic Agent Builder to detect and
      quantify drift across your GCP infrastructure.
---

# Challenge 1: Detect GCP Resource Drift

Your organization runs hundreds of GCP VMs across 9 teams. The monthly cloud
bill keeps climbing, but nobody knows how much of that spend is actually
necessary. Your job: find where the waste is.

## Step 1: Explore the Data

1. Open the **Kibana** tab
2. Log in with: `elastic` / `workshopAdmin1!`
3. Go to **Discover** (hamburger menu > Analytics > Discover)
4. Select the **GCP Resource Executions** data view
5. Set the time range to **Last 1 year**

Browse the data. Each document represents a VM execution with fields like:
- `resource_usage.cpu.avg_percent` — actual CPU usage
- `drift_metrics.combined_drift_score` — how far off the allocation is
- `metadata.team` — which team owns the VM
- `vm_info.vm_type_actual` — the machine type (e.g., n2-standard-16)

## Step 2: Analyze VM Usage Patterns

1. Click the **AI Assistant** icon (sparkle icon in the top nav bar)
2. Type this prompt:

   > **Show me the VM usage patterns — which teams and VM types have the highest resource drift?**

3. The AI Assistant will invoke the `analyze_vm_usage_patterns` tool
4. Review the results table

**Questions to answer:**
- Which team + VM type combination has the **highest** combined drift score?
- What does a high `avg_cpu_drift` with a low `avg_cpu_used` tell you?

## Step 3: Compare Team Efficiency

In the AI Assistant, type:

> **Compare what each team has allocated versus what they actually use. Rank by efficiency.**

This invokes `compare_team_request_vs_usage`. Look at:
- The `efficiency_score` column (lower = more waste)
- The `total_cost` column

**Question:** Which team has the lowest efficiency score, and what does that mean?

## Step 4: Deep Dive — VM Sizing Analysis

Ask the AI Assistant:

> **Show me the VM sizing analysis — where are the biggest rightsizing opportunities?**

This invokes `get_vm_sizing_analysis`. Compare:
- `p95_cpu` (actual peak usage) vs the VM type's total cores
- `combined_drift` (waste percentage)

## Step 5: Explore the Dashboard

1. Go to **Dashboards** (hamburger menu > Analytics > Dashboards)
2. Open **GCP Resource Drift Overview**
3. Correlate what you found via Agent Builder with the visual panels:
   - The **Drift by Team** bar chart
   - The **CPU Heatmap** by machine type
   - The **Top Over-Provisioned VMs** table

## Check Your Work

Before clicking **Check**, make sure you can answer:

> **Which team runs the most over-provisioned VMs?** (Hint: look for a team
> running 32-core VMs at single-digit CPU utilization)
