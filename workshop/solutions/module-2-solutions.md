# Module 2 Solutions: Understanding Resource Drift

## Exercise 1.1: Explore the Data

- `drift_metrics.combined_drift_score`: The average of CPU drift % and memory drift %. A score of 50 means the VM is using only half its allocated resources on average.
- `resource_usage.cpu.avg_percent`: Average CPU utilization across the execution window. `p95_percent`: The 95th percentile -- the level exceeded only 5% of the time. P95 is used for rightsizing because it accounts for peaks.
- Team field: `metadata.team` (keyword subfield: `metadata.team.keyword`)

## Exercise 2.1: Identify High-Drift VMs

**Agent Builder prompt:** "Analyze our VM usage patterns. Show me where resource drift is highest, broken down by team and machine type."

Expected results (from `kafeju.analyze_vm_usage_patterns`):
- Teams with highest combined drift will vary with synthetic data, but look for `combined_drift > 50`
- Common high-drift machine types: `n2-standard-16` and `n2-standard-32` (larger VMs tend to be more over-provisioned)
- 70% CPU drift means the team allocated 100% of the VM's CPU capacity but only uses 30% on average. They could potentially drop to a VM with 30-40% of the current CPU cores (accounting for P95 headroom).

## Exercise 2.2: Team Efficiency Report

**Agent Builder prompt:** "Compare what each team has allocated versus what they actually use."

Expected results (from `kafeju.compare_team_request_vs_usage`):
- Efficiency score = (avg_cpu_used + avg_mem_used) / 2
- Teams with scores below 30 are using less than 30% of allocated resources
- Recommendation for low-efficiency teams: Audit their VM sizes, switch to smaller instance types, or implement autoscaling. Start with the highest-cost VMs first for maximum savings.
