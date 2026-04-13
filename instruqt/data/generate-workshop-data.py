#!/usr/bin/env python3
"""
Generate workshop-ready synthetic data with clear, discoverable patterns.

Designed for the Instruqt workshop environment. Produces data with:
  - Obvious drift scenarios (teams running oversized VMs at low utilization)
  - Clear anomaly stories (zombie VMs, CPU spikes, capacity warnings)
  - A "before/after" team that demonstrates rightsizing benefits
  - Continuous 90-day time series for good chart rendering
  - @timestamp on all docs for time-based filtering

Indices produced:
  - gcp-resource-executions-workshop  (~3,000 docs)
  - gcp-billing-workshop              (~2,000 docs)
  - gcp-instance-lifecycle-workshop    (~1,000 docs)
  - ml-predictions-anomalies-workshop  (~300 docs)
  - ml-predictions-growth-workshop     (~100 docs)
  - gcp-pricing-catalog                (~30 docs, reference data)
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
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "elasticsearch>=8.0"])
    from elasticsearch import Elasticsearch
    from elasticsearch.helpers import bulk

ES_URL = os.environ.get("ES_URL", "http://localhost:9200")
ES_USER = os.environ.get("ES_USER", "elastic")
ES_PASS = os.environ.get("ES_PASS", "workshopAdmin1!")

es = Elasticsearch(ES_URL, basic_auth=(ES_USER, ES_PASS), request_timeout=60)

random.seed(42)

NOW = datetime(2025, 11, 15, tzinfo=timezone.utc)
WINDOW_DAYS = 90
START = NOW - timedelta(days=WINDOW_DAYS)

TEAMS = {
    "data-platform":   {"bias": "heavy",  "drift_range": (25, 50)},
    "analytics":       {"bias": "normal", "drift_range": (35, 65)},
    "ml-ops":          {"bias": "heavy",  "drift_range": (15, 35)},
    "backend-services": {"bias": "normal", "drift_range": (30, 55)},
    "frontend":        {"bias": "light",  "drift_range": (55, 85)},
    "devops-infra":    {"bias": "light",  "drift_range": (60, 90)},
    "security-ops":    {"bias": "normal", "drift_range": (20, 45)},
    "platform":        {"bias": "normal", "drift_range": (30, 50)},
    "cost-optimized":  {"bias": "efficient", "drift_range": (5, 15)},
}

ZONES = [
    "us-central1-a", "us-central1-b", "us-east1-b",
    "europe-west1-b", "europe-west1-c",
]

MACHINE_TYPES = {
    "e2-micro":        (2, 1),
    "e2-standard-2":   (2, 8),
    "e2-standard-4":   (4, 16),
    "e2-standard-8":   (8, 32),
    "n2-standard-4":   (4, 16),
    "n2-standard-8":   (8, 32),
    "n2-standard-16":  (16, 64),
    "n2-standard-32":  (32, 128),
    "c2-standard-4":   (4, 16),
    "c2-standard-8":   (8, 32),
}

PRICE_PER_CORE_HOUR = {
    "e2-micro": 0.008, "e2-standard-2": 0.034, "e2-standard-4": 0.034,
    "e2-standard-8": 0.034, "n2-standard-4": 0.047, "n2-standard-8": 0.047,
    "n2-standard-16": 0.047, "n2-standard-32": 0.047, "c2-standard-4": 0.052,
    "c2-standard-8": 0.052,
}

WORKLOAD_TYPES = [
    "batch-processing", "web-server", "ml-training", "ci-cd-pipeline",
    "data-pipeline", "api-server", "analytics", "monitoring",
]

ENVIRONMENTS = ["production", "staging", "development"]


def ts_iso(dt):
    return dt.isoformat().replace("+00:00", "Z")


def gen_resource_executions():
    """Generate gcp-resource-executions-workshop with planted scenarios."""
    docs = []

    # --- Planted scenario: devops-infra runs n2-standard-32 at 8% CPU (obvious waste) ---
    for i in range(50):
        t = START + timedelta(days=random.randint(0, WINDOW_DAYS), hours=random.randint(0, 23))
        cpu_avg = random.randint(5, 12)
        mem_avg = random.randint(10, 20)
        docs.append(_exec_doc(t, "devops-infra", "n2-standard-32", cpu_avg, mem_avg,
                              "monitoring", "production", f"idle-monitor-{i%5}"))

    # --- Planted scenario: frontend runs e2-standard-8 at 75% CPU (well-sized) ---
    for i in range(40):
        t = START + timedelta(days=random.randint(0, WINDOW_DAYS), hours=random.randint(0, 23))
        cpu_avg = random.randint(65, 85)
        mem_avg = random.randint(55, 75)
        docs.append(_exec_doc(t, "frontend", "e2-standard-4", cpu_avg, mem_avg,
                              "web-server", "production", f"web-frontend-{i%3}"))

    # --- Planted scenario: cost-optimized team (recently rightsized, low drift) ---
    for i in range(60):
        t = START + timedelta(days=random.randint(0, WINDOW_DAYS), hours=random.randint(0, 23))
        cpu_avg = random.randint(60, 80)
        mem_avg = random.randint(55, 75)
        docs.append(_exec_doc(t, "cost-optimized", "e2-standard-2", cpu_avg, mem_avg,
                              "api-server", "production", f"opt-api-{i%4}"))

    # --- Planted scenario: analytics with erratic spikes (anomaly candidate) ---
    for i in range(30):
        t = START + timedelta(days=random.randint(60, WINDOW_DAYS), hours=random.randint(0, 23))
        cpu_avg = random.choice([random.randint(15, 30), random.randint(85, 98)])
        mem_avg = random.randint(40, 70)
        docs.append(_exec_doc(t, "analytics", "n2-standard-16", cpu_avg, mem_avg,
                              "analytics", "production", f"analytics-batch-{i%3}"))

    # --- Bulk normal data for all teams ---
    for i in range(2820):
        team_name = random.choice(list(TEAMS.keys()))
        team = TEAMS[team_name]
        lo, hi = team["drift_range"]
        drift_target = random.randint(lo, hi)
        cpu_avg = max(5, min(95, 100 - drift_target + random.randint(-10, 10)))
        mem_avg = max(10, min(95, 100 - drift_target + random.randint(-15, 15)))
        mt = _pick_machine_type(team["bias"])
        wtype = random.choice(WORKLOAD_TYPES)
        env = random.choice(ENVIRONMENTS)
        t = START + timedelta(days=random.randint(0, WINDOW_DAYS),
                              hours=random.randint(0, 23),
                              minutes=random.randint(0, 59))
        docs.append(_exec_doc(t, team_name, mt, cpu_avg, mem_avg, wtype, env,
                              f"workload-{wtype}-{i%10}"))
    return docs


def _pick_machine_type(bias):
    if bias == "heavy":
        return random.choice(["n2-standard-16", "n2-standard-32", "c2-standard-8", "n2-standard-8"])
    elif bias == "light":
        return random.choice(["e2-standard-8", "n2-standard-8", "e2-standard-4"])
    elif bias == "efficient":
        return random.choice(["e2-standard-2", "e2-standard-4", "e2-micro"])
    return random.choice(list(MACHINE_TYPES.keys()))


def _exec_doc(t, team, mt, cpu_avg, mem_avg, wtype, env, rname):
    cpus, mem_gb = MACHINE_TYPES[mt]
    cpu_peak = min(cpu_avg + random.randint(8, 30), 100)
    cpu_p95 = min(cpu_avg + random.randint(3, 18), cpu_peak)
    mem_peak = min(mem_avg + random.randint(5, 25), 100)
    mem_p95 = min(mem_avg + random.randint(2, 12), mem_peak)

    cpu_drift = 100 - cpu_avg
    mem_drift = 100 - mem_avg
    combined_drift = round((cpu_drift + mem_drift) / 2, 1)
    duration = random.uniform(10, 360)
    hours = duration / 60
    price = PRICE_PER_CORE_HOUR.get(mt, 0.04) * cpus
    compute_cost = round(price * hours, 4)

    completed = t + timedelta(minutes=duration)
    return {
        "_index": "gcp-resource-executions-workshop",
        "_source": {
            "@timestamp": ts_iso(t),
            "execution_id": f"exec-{ts_iso(t)[:10].replace('-','')}-{random.randint(0,999999):06d}",
            "resource_name": rname,
            "resource_kind": random.choice(["helm-chart", "terraform-module", "gke-deployment"]),
            "vm_info": {
                "vm_id": str(random.randint(10**18, 10**19 - 1)),
                "vm_type_actual": mt,
                "vm_type_requested": mt,
                "zone": random.choice(ZONES),
            },
            "execution_time": {
                "started_at": ts_iso(t),
                "completed_at": ts_iso(completed),
                "duration_minutes": round(duration, 1),
                "status": random.choices(["success", "failed", "timeout"], weights=[88, 8, 4])[0],
            },
            "resource_usage": {
                "cpu": {
                    "avg_percent": cpu_avg,
                    "peak_percent": cpu_peak,
                    "p95_percent": cpu_p95,
                    "avg_cores_used": round(cpus * cpu_avg / 100, 2),
                    "peak_cores_used": round(cpus * cpu_peak / 100, 2),
                },
                "memory": {
                    "avg_percent": mem_avg,
                    "peak_percent": mem_peak,
                    "p95_percent": mem_p95,
                    "avg_gb_used": round(mem_gb * mem_avg / 100, 1),
                    "peak_gb_used": round(mem_gb * mem_peak / 100, 1),
                },
            },
            "drift_metrics": {
                "cpu": {"drift_percent": cpu_drift, "drift_cores": round(cpus * cpu_drift / 100, 2)},
                "memory": {"drift_percent": mem_drift, "drift_gb": round(mem_gb * mem_drift / 100, 1)},
                "combined_drift_score": combined_drift,
            },
            "cost_actual": {
                "compute_cost_usd": compute_cost,
                "total_cost_usd": round(compute_cost * 1.08, 4),
            },
            "metadata": {
                "team": team,
                "environment": env,
                "workload_type": wtype,
                "priority": random.choice(["high", "medium", "low"]),
            },
        },
    }


def gen_anomalies():
    """Generate ML anomaly predictions with clear, discoverable stories."""
    docs = []

    stories = [
        # (team, vm_type, function, typical, actual, score, severity, count, desc)
        ("devops-infra", "n2-standard-32", "Low CPU usage (zombie)", 45, 3, 92, "CRITICAL", 12,
         "Zombie VM: 32 cores allocated, 3% used for 2+ weeks"),
        ("devops-infra", "e2-standard-8", "Low CPU usage (zombie)", 40, 5, 85, "CRITICAL", 8,
         "Zombie VM: 8 cores at 5% usage"),
        ("analytics", "n2-standard-16", "High CPU usage", 35, 96, 88, "CRITICAL", 10,
         "Sudden CPU spike from normal 35% to 96%"),
        ("ml-ops", "n2-standard-32", "High memory usage", 50, 97, 82, "HIGH", 6,
         "Memory pressure event on ML training node"),
        ("data-platform", "n2-standard-16", "High CPU usage", 42, 91, 78, "HIGH", 8,
         "Sustained high CPU on data pipeline"),
        ("backend-services", "n2-standard-8", "Unusual duration", 120, 480, 65, "MEDIUM", 5,
         "Job running 4x longer than normal"),
    ]

    for team, vm_type, func, typical, actual, score, sev, count, _ in stories:
        vm_id = str(random.randint(10**18, 10**19 - 1))
        for j in range(count):
            t = START + timedelta(days=random.randint(30, WINDOW_DAYS), hours=random.randint(0, 23))
            docs.append({
                "_index": "ml-predictions-anomalies-workshop",
                "_source": {
                    "@timestamp": ts_iso(t),
                    "prediction_type": "resource-usage-anomalies",
                    "result_type": "record",
                    "partition_field_value": vm_id,
                    "function_description": func,
                    "typical": [round(typical + random.uniform(-3, 3), 1)],
                    "actual": [round(actual + random.uniform(-2, 2), 1)],
                    "record_score": round(score + random.uniform(-5, 3), 1),
                    "detector_index": 0,
                    "is_interim": False,
                    "bucket_span": 3600,
                    "vm_id": vm_id,
                    "team": team,
                    "vm_type": vm_type,
                    "severity": sev,
                },
            })

    remaining = 300 - len(docs)
    for i in range(remaining):
        team = random.choice(list(TEAMS.keys()))
        mt = random.choice(list(MACHINE_TYPES.keys()))
        func = random.choice(["High CPU usage", "High memory usage", "Low CPU usage (zombie)", "Unusual duration"])
        sev = random.choices(["LOW", "MEDIUM", "HIGH", "CRITICAL"], weights=[30, 35, 25, 10])[0]
        t = START + timedelta(days=random.randint(0, WINDOW_DAYS), hours=random.randint(0, 23))
        typical_val = random.uniform(25, 60)
        actual_val = typical_val + random.uniform(15, 45)
        docs.append({
            "_index": "ml-predictions-anomalies-workshop",
            "_source": {
                "@timestamp": ts_iso(t),
                "prediction_type": "resource-usage-anomalies",
                "result_type": "record",
                "partition_field_value": str(random.randint(10**18, 10**19 - 1)),
                "function_description": func,
                "typical": [round(typical_val, 1)],
                "actual": [round(actual_val, 1)],
                "record_score": round(random.uniform(25, 85), 1),
                "detector_index": random.randint(0, 1),
                "is_interim": False,
                "bucket_span": 3600,
                "vm_id": str(random.randint(10**18, 10**19 - 1)),
                "team": team,
                "vm_type": mt,
                "severity": sev,
            },
        })
    return docs


def gen_growth():
    """Generate growth predictions showing teams approaching capacity."""
    docs = []
    predictions = [
        ("analytics",       8.2, 0.12, 12,  "URGENT_RESIZE"),
        ("data-platform",   6.5, 0.08, 22,  "PLAN_RESIZE"),
        ("ml-ops",         11.0, 0.05, 45,  "MONITOR"),
        ("backend-services", 4.2, 0.03, 90, "MONITOR"),
        ("frontend",        2.1, 0.01, 200, "MONITOR"),
        ("devops-infra",    1.5, 0.02, 150, "MONITOR"),
        ("security-ops",    3.8, 0.06, 35,  "PLAN_RESIZE"),
        ("platform",        5.0, 0.04, 55,  "MONITOR"),
        ("cost-optimized",  1.8, 0.01, 300, "MONITOR"),
    ]
    for team, base_cpu, growth, days_to_90, rec in predictions:
        for day in range(12):
            t = START + timedelta(days=60 + day)
            actual_val = round(base_cpu * (1 + growth) ** day, 2)
            docs.append({
                "_index": "ml-predictions-growth-workshop",
                "_source": {
                    "@timestamp": ts_iso(t),
                    "prediction_type": "workload-growth-rate",
                    "result_type": "model_plot",
                    "partition_field_value": team,
                    "model_feature": "mean(resource_usage.cpu.avg_cores_used)",
                    "model_lower": round(actual_val * 0.9, 2),
                    "model_upper": round(actual_val * 1.1, 2),
                    "model_median": round(actual_val * 1.01, 2),
                    "actual": actual_val,
                    "team": team,
                    "current_avg_cpu": base_cpu,
                    "growth_rate_daily": growth,
                    "predicted_days_to_90pct": days_to_90,
                    "recommendation": rec,
                },
            })
    return docs


def gen_pricing_catalog():
    """Reference data: GCP pricing catalog."""
    docs = []
    catalog = [
        ("e2-micro",       "e2", 2, 1,    0.008, 5.84,   "Burstable micro instances"),
        ("e2-small",       "e2", 2, 2,    0.017, 12.41,  "Burstable small instances"),
        ("e2-medium",      "e2", 2, 4,    0.034, 24.82,  "Burstable medium instances"),
        ("e2-standard-2",  "e2", 2, 8,    0.067, 48.91,  "General purpose"),
        ("e2-standard-4",  "e2", 4, 16,   0.134, 97.83,  "General purpose"),
        ("e2-standard-8",  "e2", 8, 32,   0.268, 195.66, "General purpose"),
        ("e2-standard-16", "e2", 16, 64,  0.536, 391.32, "General purpose"),
        ("n2-standard-2",  "n2", 2, 8,    0.097, 70.81,  "Balanced performance"),
        ("n2-standard-4",  "n2", 4, 16,   0.194, 141.62, "Balanced performance"),
        ("n2-standard-8",  "n2", 8, 32,   0.388, 283.24, "Balanced performance"),
        ("n2-standard-16", "n2", 16, 64,  0.776, 566.48, "Balanced performance"),
        ("n2-standard-32", "n2", 32, 128, 1.552, 1132.96,"High-memory workloads"),
        ("c2-standard-4",  "c2", 4, 16,   0.209, 152.57, "Compute-optimized"),
        ("c2-standard-8",  "c2", 8, 32,   0.418, 305.14, "Compute-optimized"),
        ("c2-standard-16", "c2", 16, 64,  0.836, 610.28, "Compute-optimized"),
        ("n2d-standard-2", "n2d", 2, 8,   0.084, 61.32,  "AMD-based balanced"),
        ("n2d-standard-4", "n2d", 4, 16,  0.169, 123.37, "AMD-based balanced"),
        ("n2d-standard-8", "n2d", 8, 32,  0.338, 246.74, "AMD-based balanced"),
        ("t2d-standard-2", "t2d", 2, 8,   0.076, 55.48,  "AMD Tau budget"),
        ("t2d-standard-4", "t2d", 4, 16,  0.152, 110.96, "AMD Tau budget"),
    ]
    for mt, family, cpus, mem, hourly, monthly, desc in catalog:
        for region in ["us-central1", "europe-west1"]:
            mult = 1.0 if region == "us-central1" else 1.10
            docs.append({
                "_index": "gcp-pricing-catalog",
                "_source": {
                    "machine_type": mt,
                    "machine_family": family,
                    "cpu_cores": cpus,
                    "memory_gb": mem,
                    "cost_per_hour_usd": round(hourly * mult, 4),
                    "cost_per_month_usd": round(monthly * mult, 2),
                    "cost_per_core_hour": round(hourly * mult / cpus, 6),
                    "cost_per_gb_hour": round(hourly * mult / mem, 6),
                    "region": region,
                    "use_case": desc,
                    "description": f"{mt} ({family} family): {cpus} vCPU, {mem} GB RAM",
                    "last_updated": ts_iso(NOW),
                },
            })
    return docs


def gen_lifecycle():
    """Generate instance lifecycle data."""
    docs = []
    for i in range(1000):
        team = random.choice(list(TEAMS.keys()))
        mt = _pick_machine_type(TEAMS[team]["bias"])
        zone = random.choice(ZONES)
        region = zone.rsplit("-", 1)[0]
        t = START + timedelta(days=random.randint(0, WINDOW_DAYS), hours=random.randint(0, 23))
        creation = t - timedelta(hours=random.uniform(1, 720))
        uptime_sec = (t - creation).total_seconds()
        status = random.choices(["RUNNING", "TERMINATED", "STOPPED"], weights=[65, 25, 10])[0]
        docs.append({
            "_index": "gcp-instance-lifecycle-workshop",
            "_source": {
                "@timestamp": ts_iso(t),
                "cloud.instance.id": str(random.randint(10**18, 10**19 - 1)),
                "cloud.instance.name": f"vm-{team}-{random.randint(1000,9999)}",
                "cloud.machine.type": mt,
                "cloud.provider": "gcp",
                "cloud.region": region,
                "cloud.availability_zone": zone,
                "instance_lifecycle.status": status,
                "instance_lifecycle.creation_timestamp": ts_iso(creation),
                "instance_lifecycle.uptime_seconds": round(uptime_sec, 2),
                "instance_lifecycle.uptime_hours": round(uptime_sec / 3600, 4),
                "instance_lifecycle.last_updated": ts_iso(t),
                "labels.team": team,
                "labels.workload_type": random.choice(WORKLOAD_TYPES),
            },
        })
    return docs


def gen_billing():
    """Generate billing data."""
    docs = []
    for i in range(2000):
        team = random.choice(list(TEAMS.keys()))
        zone = random.choice(ZONES)
        region = zone.rsplit("-", 1)[0]
        t = START + timedelta(days=random.randint(0, WINDOW_DAYS))
        hours_used = random.uniform(0.5, 24.0)
        price = random.uniform(0.03, 1.20)
        amount = round(hours_used * price, 4)
        credits = round(amount * random.uniform(0, 0.12), 4)
        docs.append({
            "_index": "gcp-billing-workshop",
            "_source": {
                "@timestamp": ts_iso(t),
                "billing": {
                    "invoice_month": t.strftime("%Y%m"),
                    "usage_date": t.strftime("%Y-%m-%dT00:00:00Z"),
                    "cost": {"amount": amount, "credits": credits, "net_cost": round(amount - credits, 4), "currency": "USD"},
                    "usage": {"amount": round(hours_used, 4), "unit": "hour", "pricing_amount": round(price, 6), "pricing_unit": "hour"},
                },
                "cloud": {"provider": "gcp", "region": region, "availability_zone": zone,
                          "project": {"id": "kafeju-workshop", "name": "kafeju-workshop"},
                          "instance": {"name": f"vm-{team}-{random.randint(1000,9999)}"}},
                "service": {"name": "Compute Engine", "sku": f"compute-{random.choice(['standard','preemptible','committed'])}"},
                "gcp": {"labels": {"team": team, "workload_type": random.choice(WORKLOAD_TYPES)}},
            },
        })
    return docs


def ingest(name, docs):
    total = len(docs)
    if total == 0:
        print(f"  {name}: SKIP (0 docs)")
        return
    success, errors = bulk(es, docs, raise_on_error=False, stats_only=True, chunk_size=500)
    print(f"  {name}: {success}/{total} indexed ({errors} errors)")


def main():
    info = es.info()
    print(f"Connected to {info['cluster_name']} (ES {info['version']['number']})")
    print()

    generators = [
        ("gcp-resource-executions-workshop", gen_resource_executions),
        ("ml-predictions-anomalies-workshop", gen_anomalies),
        ("ml-predictions-growth-workshop", gen_growth),
        ("gcp-pricing-catalog", gen_pricing_catalog),
        ("gcp-instance-lifecycle-workshop", gen_lifecycle),
        ("gcp-billing-workshop", gen_billing),
    ]

    print("Generating and indexing workshop data...")
    for name, gen_fn in generators:
        docs = gen_fn()
        ingest(name, docs)

    es.indices.refresh(index="gcp-*,ml-predictions-*")
    print("\nDone. Index counts:")
    for idx in ["gcp-resource-executions-workshop", "gcp-billing-workshop",
                "gcp-instance-lifecycle-workshop", "ml-predictions-anomalies-workshop",
                "ml-predictions-growth-workshop", "gcp-pricing-catalog"]:
        try:
            c = es.count(index=idx)["count"]
            print(f"  {idx}: {c}")
        except Exception:
            print(f"  {idx}: not found")


if __name__ == "__main__":
    main()
