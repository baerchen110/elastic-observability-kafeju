# Module 5 Solutions: Build Your Own Tool

## Exercise 5.1: Zombie VM Detector

**Tool name:** Detect Zombie VMs

**Description:** Identifies VMs running for more than 7 days with very low CPU utilization (under 10%), indicating possible zombie instances that should be terminated.

**ES|QL query:**

```esql
FROM gcp-resource-executions-*
| WHERE drift_metrics.cpu.drift_percent > 90
| STATS count = COUNT(*),
        avg_cpu = AVG(resource_usage.cpu.avg_percent),
        total_waste_usd = SUM(cost_actual.total_cost_usd)
  BY metadata.team.keyword, vm_info.vm_type_actual.keyword
| SORT total_waste_usd DESC
```

**Why this works:**
- `drift_percent > 90` means the VM is using less than 10% of allocated CPU
- Grouping by team and VM type shows where the zombie problem is concentrated
- Sorting by total_waste_usd prioritizes the most expensive zombies

**Test prompt:** "Find zombie VMs in our infrastructure that should be terminated."

## Exercise 5.2: Regional Cost Comparison

**Tool name:** Compare Regional VM Costs

**Description:** Compares the average cost per vCPU hour across GCP regions to identify the cheapest regions for deploying workloads.

**ES|QL query:**

```esql
FROM gcp-vm-pricing
| STATS avg_price = AVG(pricing.price_per_hour_usd),
        max_cores = MAX(pricing.cpu_cores),
        instance_count = COUNT(*)
  BY cloud.region.keyword
| EVAL cost_per_core = ROUND(avg_price / max_cores, 4)
| SORT cost_per_core ASC
```

**Alternative using gcp-pricing-catalog:**

```esql
FROM gcp-pricing-catalog
| STATS avg_hourly = AVG(cost_per_hour_usd),
        avg_monthly = AVG(cost_per_month_usd),
        types_available = COUNT(*)
  BY region.keyword
| EVAL monthly_per_core = ROUND(avg_monthly / types_available, 2)
| SORT avg_hourly ASC
```

**Test prompt:** "Which GCP region is cheapest for running VMs?"
