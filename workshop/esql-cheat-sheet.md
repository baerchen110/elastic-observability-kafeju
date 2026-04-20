# ES|QL Cheat Sheet for Agent Builder Tools

## The 6 Commands You Need

| Command | What It Does | Syntax |
|---------|-------------|--------|
| `FROM` | Select which index to query | `FROM index-name` |
| `WHERE` | Filter rows (keep only matching) | `WHERE field > value` |
| `STATS` | Aggregate (sum, avg, count, etc.) | `STATS metric = AGG(field) BY group` |
| `EVAL` | Add computed columns | `EVAL new_field = expression` |
| `SORT` | Order results | `SORT field DESC` |
| `LIMIT` | Cap result count | `LIMIT 20` |

## Basic Pattern

```sql
FROM <index-pattern>
| WHERE <filter>
| STATS <metrics> BY <grouping>
| EVAL <computed fields>
| SORT <order> DESC
| LIMIT <N>
```

## Aggregation Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `AVG(field)` | Average | `AVG(cpu_percent)` |
| `SUM(field)` | Total | `SUM(cost_usd)` |
| `COUNT(*)` | Count rows | `COUNT(*)` |
| `MAX(field)` | Maximum | `MAX(memory_gb)` |
| `MIN(field)` | Minimum | `MIN(price)` |
| `PERCENTILE(field, N)` | Nth percentile | `PERCENTILE(cpu, 95)` |
| `COUNT_DISTINCT(field)` | Unique values | `COUNT_DISTINCT(team)` |

## Common Patterns

### Group by one field
```sql
FROM gcp-billing-actual
| STATS total = SUM(billing.cost.amount) BY gcp.labels.team
| SORT total DESC
```

### Group by multiple fields
```sql
FROM gcp-resource-executions-*
| STATS avg_cpu = AVG(resource_usage.cpu.avg_percent)
  BY metadata.team, vm_info.vm_type_actual
| SORT avg_cpu ASC
```

### Filter + Aggregate
```sql
FROM gcp-resource-executions-*
| WHERE drift_metrics.combined_drift_score > 50
| STATS count = COUNT(*), total_cost = SUM(cost_actual.total_cost_usd)
  BY metadata.team
| SORT total_cost DESC
| LIMIT 10
```

### Computed column with EVAL
```sql
FROM gcp-resource-executions-*
| STATS total_cost = SUM(cost_actual.total_cost_usd),
        avg_drift = AVG(drift_metrics.combined_drift_score)
  BY metadata.team
| EVAL waste_usd = total_cost * avg_drift / 100
| SORT waste_usd DESC
```

### Time bucketing
```sql
FROM gcp-billing-actual
| EVAL week = DATE_TRUNC(7 days, @timestamp)
| STATS weekly_cost = SUM(billing.cost_usd) BY billing.team, week
| SORT week, weekly_cost DESC
```

### IS NOT NULL filter
```sql
FROM gcp-resource-executions-*
| WHERE vm_info.vm_type_actual IS NOT NULL
| STATS count = COUNT(*) BY vm_info.vm_type_actual
```

## Available Indices (This Workshop)

| Index | Key Fields |
|-------|-----------|
| `gcp-resource-executions-*` | `resource_usage.cpu.avg_percent`, `drift_metrics.combined_drift_score`, `cost_actual.total_cost_usd`, `metadata.team`, `vm_info.vm_type_actual`, `resource_name` |
| `gcp-billing-actual` | `@timestamp`, `billing.cost.amount`, `gcp.labels.team`, `service.name`, `billing.cost.net_cost` |
| `gcp-pricing-catalog` | `region`, `machine_type`, `cpu_cores`, `memory_gb`, `cost_per_hour_usd`, `cost_per_month_usd` |
| `gcp-vm-pricing` | `machine_type`, `cloud.region`, `pricing.cpu_cores`, `pricing.memory_gb`, `pricing.price_per_hour_usd`, `pricing.price_per_month_usd` |
| `gcp-instance-lifecycle*` | `@timestamp`, `instance_lifecycle.uptime_hours`, `instance_lifecycle.status`, `cloud.region`, `cloud.machine.type`, `gcp.labels.team` |
| `gcp-workload-requirements` | `workload_type`, `requirements.min_cpu_cores`, `requirements.min_memory_gb`, `requirements.preferred_cpu_cores`, `resource_profile.avg_cpu_usage_percent` |
| `ml-predictions-growth-summary` | `team`, `growth_rate_percent_per_week`, `weeks_until_90_percent_capacity`, `recommendation`, `confidence` |
| `ml-predictions-anomalies*` | `@timestamp`, `severity`, `record_score`, `actual`, `typical`, `team`, `function_description`, `vm_type` |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| No results | Check time range (Last 1 year); verify index name spelling |
| Field not found | Check exact field path (use Discover to browse fields) |
| Type error | Some fields need `.keyword` suffix for grouping; try without first |
| Syntax error | Check pipe (`|`) at start of each line; check comma separation in STATS |
