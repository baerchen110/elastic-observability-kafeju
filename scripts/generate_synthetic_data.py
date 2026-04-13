#!/usr/bin/env python3
"""
Generate synthetic data for the Kafeju GCP resource optimization demo.

Produces documents matching the real schema across four index families:
  - gcp-resource-executions-synthetic  (~5,000 docs)
  - gcp-billing-actual                 (~3,000 docs)
  - gcp-instance-lifecycle-synthetic   (~2,000 docs)
  - ml-predictions-anomalies-synthetic (~500 docs)
  - ml-predictions-cost-forecast       (~200 docs)
  - ml-predictions-growth              (~100 docs)

Usage:
  export TARGET_URL=... TARGET_API_KEY=...
  python3 scripts/generate_synthetic_data.py
"""

import json
import os
import random
import sys
from datetime import datetime, timedelta, timezone

try:
    from elasticsearch import Elasticsearch
    from elasticsearch.helpers import bulk
except ImportError:
    print("Installing elasticsearch package...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "elasticsearch>=8.0"])
    from elasticsearch import Elasticsearch
    from elasticsearch.helpers import bulk

TARGET_URL = os.environ.get("TARGET_URL")
TARGET_API_KEY = os.environ.get("TARGET_API_KEY")

if not TARGET_URL or not TARGET_API_KEY:
    print("ERROR: TARGET_URL and TARGET_API_KEY must be set")
    sys.exit(1)

es = Elasticsearch(TARGET_URL, api_key=TARGET_API_KEY)

TEAMS = [
    "data-platform", "analytics", "platform", "ml-ops",
    "backend-services", "frontend", "devops-infra",
    "elastic-agent-control-plane", "security-ops"
]

ZONES = [
    "us-central1-a", "us-central1-b", "us-central1-c",
    "us-east1-b", "us-east1-c",
    "europe-west1-b", "europe-west1-c"
]

MACHINE_TYPES = {
    "e2-standard-2": (2, 8),
    "e2-standard-4": (4, 16),
    "e2-standard-8": (8, 32),
    "n2-standard-4": (4, 16),
    "n2-standard-8": (8, 32),
    "n2-standard-16": (16, 64),
    "c2-standard-4": (4, 16),
    "c2-standard-8": (8, 32),
    "n2-standard-32": (32, 128),
}

WORKLOAD_TYPES = [
    "batch-processing", "web-server", "ml-training",
    "ci-cd-pipeline", "data-pipeline", "api-server",
    "analytics", "monitoring", "unknown"
]

RESOURCE_NAMES = [
    "Customer Data ETL", "API Gateway", "ML Feature Store",
    "Log Aggregator", "Search Indexer", "Metrics Collector",
    "CI Build Runner", "Integration Tests", "Load Balancer",
    "Data Warehouse Sync", "Image Processing", "Notification Service",
    "User Analytics", "Recommendation Engine", "Cache Warmer"
]

ENVIRONMENTS = ["production", "staging", "development"]

random.seed(42)


def gen_resource_executions(count=5000):
    """Generate gcp-resource-executions-synthetic documents."""
    docs = []
    base = datetime(2025, 8, 1, tzinfo=timezone.utc)

    for i in range(count):
        team = random.choice(TEAMS)
        mt = random.choice(list(MACHINE_TYPES.keys()))
        cpus, mem_gb = MACHINE_TYPES[mt]
        zone = random.choice(ZONES)
        wtype = random.choice(WORKLOAD_TYPES)
        env = random.choice(ENVIRONMENTS)
        rname = random.choice(RESOURCE_NAMES)

        cpu_avg_pct = random.randint(8, 92)
        cpu_peak_pct = min(cpu_avg_pct + random.randint(10, 40), 100)
        cpu_p95_pct = min(cpu_avg_pct + random.randint(5, 25), cpu_peak_pct)
        avg_cores = round(cpus * cpu_avg_pct / 100, 2)
        peak_cores = round(cpus * cpu_peak_pct / 100, 2)

        mem_avg_pct = random.randint(15, 90)
        mem_peak_pct = min(mem_avg_pct + random.randint(5, 30), 100)
        mem_p95_pct = min(mem_avg_pct + random.randint(3, 15), mem_peak_pct)
        avg_gb = round(mem_gb * mem_avg_pct / 100, 1)
        peak_gb = round(mem_gb * mem_peak_pct / 100, 1)

        cpu_drift = 100 - cpu_avg_pct
        mem_drift = 100 - mem_avg_pct
        drift_cores = round(cpus - avg_cores, 2)
        drift_gb = round(mem_gb - avg_gb, 1)
        combined_drift = round((cpu_drift + mem_drift) / 2, 1)

        duration = random.uniform(5, 480)
        hours = duration / 60
        price_per_hour = cpus * 0.033
        compute_cost = round(price_per_hour * hours, 4)
        total_cost = round(compute_cost * 1.08, 4)

        started = base + timedelta(
            days=random.randint(0, 120),
            hours=random.randint(0, 23),
            minutes=random.randint(0, 59)
        )
        completed = started + timedelta(minutes=duration)

        vm_id = str(random.randint(10**18, 10**19 - 1))
        exec_id = f"exec-{started.strftime('%Y%m%d')}-{i:06d}"

        docs.append({
            "_index": "gcp-resource-executions-synthetic",
            "_source": {
                "execution_id": exec_id,
                "resource_id": f"{rname.lower().replace(' ', '-')}-v{random.randint(1,5)}",
                "resource_kind": random.choice(["helm-chart", "terraform-module", "gke-deployment"]),
                "resource_version": f"{random.randint(1,5)}.{random.randint(0,9)}.{random.randint(0,9)}",
                "resource_name": rname,
                "vm_info": {
                    "vm_id": vm_id,
                    "vm_type_actual": mt,
                    "vm_type_requested": mt,
                    "zone": zone
                },
                "execution_time": {
                    "started_at": started.isoformat().replace("+00:00", "Z"),
                    "completed_at": completed.isoformat().replace("+00:00", "Z"),
                    "duration_minutes": round(duration, 1),
                    "status": random.choices(["success", "failed", "timeout"], weights=[85, 10, 5])[0]
                },
                "resource_usage": {
                    "cpu": {
                        "avg_percent": cpu_avg_pct,
                        "peak_percent": cpu_peak_pct,
                        "p95_percent": cpu_p95_pct,
                        "avg_cores_used": avg_cores,
                        "peak_cores_used": peak_cores
                    },
                    "memory": {
                        "avg_percent": mem_avg_pct,
                        "peak_percent": mem_peak_pct,
                        "p95_percent": mem_p95_pct,
                        "avg_gb_used": avg_gb,
                        "peak_gb_used": peak_gb
                    }
                },
                "drift_metrics": {
                    "cpu": {"drift_percent": cpu_drift, "drift_cores": drift_cores},
                    "memory": {"drift_percent": mem_drift, "drift_gb": drift_gb},
                    "combined_drift_score": combined_drift
                },
                "cost_actual": {
                    "compute_cost_usd": compute_cost,
                    "total_cost_usd": total_cost
                },
                "metadata": {
                    "team": team,
                    "environment": env,
                    "workload_type": wtype,
                    "priority": random.choice(["high", "medium", "low"])
                }
            }
        })
    return docs


def gen_billing(count=3000):
    """Generate gcp-billing-actual documents."""
    docs = []
    base = datetime(2025, 6, 1, tzinfo=timezone.utc)

    for i in range(count):
        team = random.choice(TEAMS)
        zone = random.choice(ZONES)
        region = zone.rsplit("-", 1)[0]
        usage_date = base + timedelta(days=random.randint(0, 180))
        invoice_month = usage_date.strftime("%Y%m")

        hours_used = random.uniform(0.5, 24.0)
        price_per_hour = random.uniform(0.02, 1.50)
        amount = round(hours_used * price_per_hour, 6)
        credits = round(amount * random.uniform(0, 0.15), 6)
        net_cost = round(amount - credits, 6)

        docs.append({
            "_index": "gcp-billing-actual",
            "_source": {
                "@timestamp": usage_date.isoformat().replace("+00:00", "Z"),
                "billing": {
                    "invoice_month": invoice_month,
                    "usage_date": usage_date.strftime("%Y-%m-%dT00:00:00Z"),
                    "cost": {
                        "amount": amount,
                        "credits": credits,
                        "net_cost": net_cost,
                        "currency": "USD"
                    },
                    "usage": {
                        "amount": round(hours_used, 4),
                        "unit": "hour",
                        "pricing_amount": round(price_per_hour, 6),
                        "pricing_unit": "hour"
                    }
                },
                "cloud": {
                    "provider": "gcp",
                    "region": region,
                    "availability_zone": zone,
                    "project": {
                        "id": "kafeju-project-1",
                        "name": "kafeju-production"
                    },
                    "instance": {
                        "name": f"vm-{team}-{random.randint(1000,9999)}"
                    }
                },
                "service": {
                    "name": "Compute Engine",
                    "sku": f"compute-{random.choice(['standard','preemptible','committed'])}"
                },
                "gcp": {
                    "labels": {
                        "team": team,
                        "workload_type": random.choice(WORKLOAD_TYPES)
                    }
                }
            }
        })
    return docs


def gen_lifecycle(count=2000):
    """Generate gcp-instance-lifecycle-synthetic documents."""
    docs = []
    base = datetime(2025, 8, 1, tzinfo=timezone.utc)

    for i in range(count):
        team = random.choice(TEAMS)
        mt = random.choice(list(MACHINE_TYPES.keys()))
        zone = random.choice(ZONES)
        region = zone.rsplit("-", 1)[0]
        wtype = random.choice(WORKLOAD_TYPES)

        ts = base + timedelta(days=random.randint(0, 120), hours=random.randint(0, 23))
        creation = ts - timedelta(hours=random.uniform(0.5, 720))
        uptime_seconds = (ts - creation).total_seconds()
        uptime_hours = uptime_seconds / 3600

        status = random.choices(
            ["RUNNING", "TERMINATED", "STOPPED", "STAGING"],
            weights=[60, 25, 10, 5]
        )[0]

        docs.append({
            "_index": "gcp-instance-lifecycle-synthetic",
            "_source": {
                "@timestamp": ts.isoformat().replace("+00:00", "Z"),
                "cloud.instance.id": str(random.randint(10**18, 10**19 - 1)),
                "cloud.instance.name": f"bk-agent-{team}-{random.randint(10**15, 10**16 - 1)}",
                "cloud.machine.type": mt,
                "cloud.provider": "gcp",
                "cloud.region": region,
                "cloud.availability_zone": zone,
                "instance_lifecycle.status": status,
                "instance_lifecycle.creation_timestamp": creation.isoformat().replace("+00:00", "Z"),
                "instance_lifecycle.uptime_seconds": round(uptime_seconds, 2),
                "instance_lifecycle.uptime_hours": round(uptime_hours, 6),
                "instance_lifecycle.found_in_gcp": status in ("RUNNING", "STAGING"),
                "instance_lifecycle.last_updated": ts.isoformat().replace("+00:00", "Z"),
                "gcp.labels.team": team,
                "gcp.labels.workload_type": wtype,
                "labels.team": team,
                "labels.workload_type": wtype
            }
        })
    return docs


def gen_anomalies(count=500):
    """Generate ml-predictions-anomalies-synthetic documents with injected scenarios."""
    docs = []
    base = datetime(2025, 8, 1, tzinfo=timezone.utc)
    functions = ["High CPU usage", "High memory usage", "Low CPU usage (zombie)", "Unusual duration"]
    severities_weights = {"LOW": 30, "MEDIUM": 35, "HIGH": 25, "CRITICAL": 10}

    scenarios = [
        ("ml-ops", "n2-standard-16", "High CPU usage", 30, 95, 95.0, "CRITICAL"),
        ("ml-ops", "n2-standard-16", "High CPU usage", 35, 92, 90.0, "HIGH"),
        ("backend-services", "n2-standard-8", "High memory usage", 50, 97, 88.0, "CRITICAL"),
        ("devops-infra", "e2-standard-4", "Low CPU usage (zombie)", 60, 2, 55.0, "HIGH"),
        ("devops-infra", "e2-standard-2", "Low CPU usage (zombie)", 55, 3, 48.0, "HIGH"),
        ("data-platform", "n2-standard-32", "High CPU usage", 42, 89, 85.0, "CRITICAL"),
        ("analytics", "n2-standard-16", "Unusual duration", 48, 340, 78.0, "HIGH"),
    ]

    for team, vm_type, func, typical, actual, score, severity in scenarios:
        for j in range(random.randint(3, 8)):
            ts = base + timedelta(days=random.randint(0, 120), hours=random.randint(0, 23))
            docs.append({
                "_index": "ml-predictions-anomalies-synthetic",
                "_source": {
                    "@timestamp": ts.isoformat().replace("+00:00", "Z"),
                    "prediction_type": "resource-usage-anomalies",
                    "result_type": "record",
                    "partition_field_value": str(random.randint(10**18, 10**19 - 1)),
                    "function_description": func,
                    "typical": [float(typical + random.uniform(-5, 5))],
                    "actual": [float(actual + random.uniform(-3, 3))],
                    "record_score": round(score + random.uniform(-10, 5), 1),
                    "detector_index": random.randint(0, 1),
                    "is_interim": False,
                    "bucket_span": 3600,
                    "vm_id": str(random.randint(10**18, 10**19 - 1)),
                    "team": team,
                    "vm_type": vm_type,
                    "severity": severity
                }
            })

    remaining = count - len(docs)
    for i in range(remaining):
        team = random.choice(TEAMS)
        mt = random.choice(list(MACHINE_TYPES.keys()))
        func = random.choice(functions)
        severity = random.choices(
            list(severities_weights.keys()),
            list(severities_weights.values())
        )[0]
        ts = base + timedelta(days=random.randint(0, 120), hours=random.randint(0, 23))
        typical_val = random.uniform(20, 70)
        actual_val = typical_val + random.uniform(15, 50)

        docs.append({
            "_index": "ml-predictions-anomalies-synthetic",
            "_source": {
                "@timestamp": ts.isoformat().replace("+00:00", "Z"),
                "prediction_type": "resource-usage-anomalies",
                "result_type": "record",
                "partition_field_value": str(random.randint(10**18, 10**19 - 1)),
                "function_description": func,
                "typical": [round(typical_val, 1)],
                "actual": [round(actual_val, 1)],
                "record_score": round(random.uniform(25, 98), 1),
                "detector_index": random.randint(0, 1),
                "is_interim": False,
                "bucket_span": 3600,
                "vm_id": str(random.randint(10**18, 10**19 - 1)),
                "team": team,
                "vm_type": mt,
                "severity": severity
            }
        })
    return docs


def gen_cost_forecast(count=200):
    """Generate ml-predictions-cost-forecast documents."""
    docs = []
    base = datetime(2025, 9, 1, tzinfo=timezone.utc)
    periods = ["1_week", "2_weeks", "3_weeks", "1_month"]

    for team in TEAMS:
        base_cost = random.uniform(100, 800)
        growth = random.uniform(1.01, 1.08)

        for week in range(min(count // len(TEAMS), 20)):
            ts = base + timedelta(weeks=week)
            predicted = round(base_cost * (growth ** week), 2)
            lower = round(predicted * random.uniform(0.9, 0.95), 2)
            upper = round(predicted * random.uniform(1.05, 1.12), 2)

            docs.append({
                "_index": "ml-predictions-cost-forecast",
                "_source": {
                    "@timestamp": ts.isoformat().replace("+00:00", "Z"),
                    "prediction_type": "team-cost-forecast",
                    "result_type": "model_forecast",
                    "partition_field_value": team,
                    "forecast_prediction": predicted,
                    "forecast_lower": lower,
                    "forecast_upper": upper,
                    "forecast_status": "finished",
                    "team": team,
                    "forecast_period": periods[min(week, len(periods) - 1)]
                }
            })
    return docs[:count]


def gen_growth(count=100):
    """Generate ml-predictions-growth documents."""
    docs = []
    base = datetime(2025, 9, 1, tzinfo=timezone.utc)

    for team in TEAMS:
        base_cores = random.uniform(1.5, 12.0)
        daily_growth = random.uniform(0.01, 0.08)

        for day in range(min(count // len(TEAMS), 15)):
            ts = base + timedelta(days=day)
            actual_val = round(base_cores * (1 + daily_growth) ** day, 2)
            lower = round(actual_val * 0.92, 1)
            upper = round(actual_val * 1.08, 1)
            median = round(actual_val * 1.01, 1)
            wtype = random.choice(WORKLOAD_TYPES[:5])

            docs.append({
                "_index": "ml-predictions-growth",
                "_source": {
                    "@timestamp": ts.isoformat().replace("+00:00", "Z"),
                    "prediction_type": "workload-growth-rate",
                    "result_type": "model_plot",
                    "partition_field_value": team,
                    "model_feature": "mean(resource_usage.cpu.avg_cores_used)",
                    "model_lower": lower,
                    "model_upper": upper,
                    "model_median": median,
                    "actual": actual_val,
                    "team": team,
                    "workload_type": wtype
                }
            })
    return docs[:count]


def ingest(name, docs):
    """Bulk index documents with progress reporting."""
    total = len(docs)
    if total == 0:
        print(f"  {name}: SKIP (0 docs)")
        return

    success, errors = bulk(es, docs, raise_on_error=False, stats_only=True)
    print(f"  {name}: {success}/{total} indexed ({errors} errors)")


def main():
    info = es.info()
    print(f"Connected to {info['cluster_name']} (ES {info['version']['number']})")
    print()

    generators = [
        ("gcp-resource-executions-synthetic", gen_resource_executions, 5000),
        ("gcp-billing-actual", gen_billing, 3000),
        ("gcp-instance-lifecycle-synthetic", gen_lifecycle, 2000),
        ("ml-predictions-anomalies-synthetic", gen_anomalies, 500),
        ("ml-predictions-cost-forecast (augmented)", gen_cost_forecast, 200),
        ("ml-predictions-growth (augmented)", gen_growth, 100),
    ]

    print("Generating and indexing synthetic data...")
    for name, gen_fn, count in generators:
        docs = gen_fn(count)
        ingest(name, docs)

    es.indices.refresh(index="gcp-*,ml-predictions-*")
    print()
    print("Done. Verifying counts on target:")
    for idx in [
        "gcp-resource-executions-synthetic",
        "gcp-billing-actual",
        "gcp-instance-lifecycle-synthetic",
        "ml-predictions-anomalies-synthetic",
        "ml-predictions-cost-forecast",
        "ml-predictions-growth"
    ]:
        try:
            c = es.count(index=idx)["count"]
            print(f"  {idx}: {c} docs")
        except Exception:
            print(f"  {idx}: not found")


if __name__ == "__main__":
    main()
