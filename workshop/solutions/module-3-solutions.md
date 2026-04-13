# Module 3 Solutions: Anomaly Detection

## Exercise 3.1: Find ML-Detected Anomalies

**Agent Builder prompt:** "Detect resource anomalies across our VMs."

Expected results (from `kafeju.detect_resource_anomalies`):
- CRITICAL anomalies: Look for `record_score > 85` and `severity: CRITICAL`
- A high record_score (0-100 scale) indicates the observation deviates significantly from the learned baseline. Scores above 75 are notable; above 90 are severe.
- For the highest-scoring anomaly, the `typical` array shows the ML model's expected value, and `actual` shows what was observed. A typical of [42.0] with actual of [89.5] means CPU jumped to more than double the expected level.

## Exercise 3.2: Classify Team Workload Patterns

**Agent Builder prompt:** "Classify team workloads as heavy, light, or normal."

Expected results (from `kafeju.detect_team_anomalies`):
- HEAVY_USER teams (avg_cores > 5): Typically `ml-ops`, `analytics`, `data-platform` -- justified for ML training and data processing workloads
- LIGHT_USER teams (avg_cores < 1): Potentially `devops-infra`, `frontend` -- these may have zombie VMs or over-provisioned instances for lightweight services
- HEAVY_USER is justified when the workload_type is `ml-training`, `batch-processing`, or `analytics`. It is suspicious when the workload_type is `web-server` or `monitoring`.

## Exercise 3.3: Visualize Anomaly Trends

Dashboard interpretation:
- The anomaly timeline shows clusters of detections, often correlating with deployment events or traffic spikes
- The severity pie chart should show a mix of LOW/MEDIUM/HIGH/CRITICAL, with CRITICAL being the smallest segment but highest priority
- Teams with the most anomalies may need dedicated capacity review
