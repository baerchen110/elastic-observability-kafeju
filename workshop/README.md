# Kafeju Workshop: GCP Resource Drift Detection with Elastic Agent Builder

## Facilitator Guide

**Duration:** 3 hours (with breaks)
**Max participants:** 20 (shared environment) or 10 (individual environments)
**Skill level:** Intermediate -- participants should have basic Elasticsearch familiarity

### Target Audience

- **Primary:** DevOps engineers, SREs, platform engineers, cloud architects
- **Secondary:** Data scientists and analysts focused on infrastructure cost optimization
- **Prerequisites:** Basic understanding of Elasticsearch indices and queries, GCP VM instance types, and cloud cost management concepts

### Learning Objectives

By the end of this workshop, participants will be able to:

1. Use Elastic Agent Builder to invoke and create ES|QL-powered tools
2. Analyze GCP resource utilization patterns and identify over-provisioned VMs
3. Detect resource drift between allocated and actual usage
4. Build cost optimization recommendations using real usage data
5. Create custom Agent Builder tools for infrastructure analysis

### Schedule

| Time | Module | Duration |
|------|--------|----------|
| 0:00 | Module 1: Introduction and Setup | 30 min |
| 0:30 | Module 2: Understanding Resource Drift | 45 min |
| 1:15 | Break | 10 min |
| 1:25 | Module 3: Anomaly Detection | 45 min |
| 2:10 | Module 4: Cost Optimization | 30 min |
| 2:40 | Module 5: Build Your Own Tool | 30 min |
| 3:10 | Wrap-up and Q&A | 10 min |

### Environment Setup

**Before the workshop:**

1. Ensure the target hosted deployment is running and healthy
2. Run `demo/setup.sh` to verify all indices and data are in place
3. Import all 3 dashboards from `demo/dashboards/` into Kibana
4. Recreate the 15 Agent Builder tools on the target (see `scripts/import-tools.sh`)
5. For per-participant access, create API keys with read-only permissions:

```bash
curl -X POST "$TARGET_URL/_security/api_key" \
  -H "Authorization: ApiKey $TARGET_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "workshop-participant-01",
    "role_descriptors": {
      "workshop_reader": {
        "cluster": ["monitor"],
        "indices": [{
          "names": ["gcp-*", "ml-predictions-*"],
          "privileges": ["read", "view_index_metadata"]
        }]
      }
    },
    "expiration": "8h"
  }'
```

6. Share the Kibana URL and credentials with participants
7. Distribute `workshop/participant-guide.md`

### Data Overview (for facilitator reference)

| Index | Docs | Description |
|-------|------|-------------|
| gcp-resource-executions-2025.11 | 98 | Real VM execution data with CPU/memory/drift metrics |
| gcp-resource-executions-synthetic | 5,000 | Augmented execution data across 9 teams, 4 months |
| gcp-instance-lifecycle | 1,065 | Real VM lifecycle (uptime, status, creation) |
| gcp-instance-lifecycle-synthetic | 2,000 | Augmented lifecycle data |
| gcp-billing-actual | 3,000 | Billing records with cost, credits, usage |
| gcp-pricing-catalog | 30 | Machine type pricing catalog |
| gcp-vm-pricing | 189 | VM pricing by region |
| gcp-workload-requirements | 21 | Workload resource requirements |
| gcp-requested-resources | 5 | Resource configs requested by teams |
| ml-predictions-anomalies / -synthetic | 503 | ML-detected resource usage anomalies |
| ml-predictions-cost-forecast | 189 | Team-level cost forecasts |
| ml-predictions-growth | 104 | Workload growth trend predictions |

### Troubleshooting

| Issue | Resolution |
|-------|------------|
| Agent Builder tools not responding | Verify tools exist in Kibana AI Assistant settings |
| Empty query results | Check the time range in Kibana (set to last 1 year) |
| Permission errors | Ensure participant API keys have read access to gcp-* and ml-* indices |
| Slow queries | Expected for first run; subsequent queries use cache |
