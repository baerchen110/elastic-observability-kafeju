# Module 4 Solutions: Cost Optimization

## Exercise 4.1: Build a Savings Report

**Agent Builder prompt:** "Calculate cost optimization opportunities from rightsizing."

Expected results (from `kafeju.calculate_cost_optimization_1`):
- Total cost from high-drift VMs will be a significant portion of overall spend
- The team/VM-type combination with highest waste is typically a large instance type (n2-standard-16 or n2-standard-32) used by a team with low CPU utilization
- Workload consolidation: Look for the same workload_type (e.g., `web-server`) running on different machine types -- standardizing on the cheapest adequate type saves money

## Exercise 4.2: Instance Recommendations

**Agent Builder prompt:** "Recommend the best GCP instance for 8 vCPUs and 32 GB memory."

Expected results (from `kafeju.recommend_instance_for_requirements`):
- Cheapest option meeting 8 vCPU / 32 GB: likely `e2-standard-8` at the lowest cost_per_hour_usd
- Second cheapest: `n2-standard-8` (slightly more expensive but newer generation)
- When to choose a more expensive option:
  - CPU-intensive workloads benefit from C2 series (higher single-thread performance)
  - Memory-intensive workloads may need custom or high-memory instances
  - SLA requirements may warrant committed use pricing or premium support

## Exercise 4.3: Cost Projection

**Agent Builder prompt:** "Show me the 30-day cost projection."

Expected results (from `kafeju.get_cost_projection`):
- Daily cost breakdown showing trend direction (increasing, stable, or decreasing)
- 30-day projection is calculated from the most recent 7 days of data
- If costs are trending up, correlate with growth predictions from `ml-predictions-growth`
