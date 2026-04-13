---
slug: ml-anomaly-detection
title: "ML-Powered Anomaly Detection"
teaser: "Use ML anomaly predictions and Agent Builder to find zombie VMs, CPU spikes, and capacity risks."
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
      # ML Anomaly Detection

      Elastic's machine learning can learn normal resource usage baselines
      and flag deviations automatically. Combined with Agent Builder, you can
      investigate anomalies using natural language — no query writing needed.

      In this challenge you will investigate ML-detected anomalies including
      zombie VMs, sudden CPU spikes, and teams approaching capacity limits.
---

# Challenge 2: ML-Powered Anomaly Detection

Your ML models have been analyzing VM resource patterns and flagging anomalies.
Some are critical. Your job: investigate the most important ones and determine
what action to take.

## Step 1: Find Resource Anomalies

Open the **AI Assistant** and ask:

> **Detect resource anomalies — show me VMs with unusual behavior, especially critical ones.**

This invokes `detect_resource_anomalies`. The results show:
- `severity` — CRITICAL, HIGH, MEDIUM, or LOW
- `record_score` — how anomalous (higher = more unusual)
- `function_description` — what type of anomaly (e.g., "Low CPU usage (zombie)")
- `actual` vs `typical` — what the VM is doing vs what's normal

**Questions:**
- How many CRITICAL anomalies are there?
- What is the most common anomaly type?

## Step 2: Investigate a Zombie VM

Look for anomalies with `function_description` = "Low CPU usage (zombie)".

These are VMs that have been running at near-zero utilization for extended
periods — they are likely forgotten and should be terminated.

Ask the AI Assistant:

> **Which team owns the zombie VMs with low CPU usage? What VM types are they running?**

**Key finding:** The `devops-infra` team is running **n2-standard-32** instances
(32 cores, 128 GB RAM) at ~3% CPU. That is over $1,100/month per VM — doing
almost nothing.

## Step 3: Classify Team Workload Patterns

Ask the AI Assistant:

> **Classify each team's workloads — which are heavy users, light users, or normal?**

This invokes `detect_team_anomalies`. Review:
- `HEAVY_USER` teams (>5 cores avg) — expected for ML training, not for monitoring
- `LIGHT_USER` teams (<1 core avg) — candidates for downsizing
- Compare `avg_cores` across teams and workload types

**Question:** Is there a team classified as HEAVY_USER that shouldn't be? Or a LIGHT_USER running large VMs?

## Step 4: Predict Capacity Needs

Ask:

> **Which teams will hit 90% CPU capacity soonest? Show me the resize predictions.**

This invokes `predict_resize_needs`. Look for:
- Teams with `predicted_days_to_90pct` < 30 — need **urgent** action
- Teams with `recommendation` = "URGENT_RESIZE"
- The `growth_rate_daily` shows how fast usage is climbing

**Question:** Which team will hit capacity first, and how many days away?

## Step 5: Explore the Anomaly Dashboard

1. Go to **Dashboards** > **Anomaly Detection & Capacity Planning**
2. Review:
   - **Anomalies by Severity** — the pie chart showing the distribution
   - **Anomaly Timeline** — when anomalies are clustering
   - **Top Anomalies** — the detail table
   - **Growth Trends** — which teams are growing fastest

## Check Your Work

Before clicking **Check**, confirm you can answer:

> 1. **Name one zombie VM scenario:** Which team, what VM type, what CPU%?
> 2. **Which team needs urgent resizing?** (Hint: check `predicted_days_to_90pct`)
