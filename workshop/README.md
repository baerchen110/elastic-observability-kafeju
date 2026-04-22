# Workshop 2: Build Your Own AI Agent — From Consumer to Creator

## Facilitator Guide

**Duration:** 3 hours (with breaks)
**Max participants:** 20 (shared environment) or 10 (individual Instruqt VMs)
**Skill level:** Intermediate — participants should have basic Elasticsearch familiarity
**Prerequisite:** Workshop 1 (Observability AI Assistant with OpenTelemetry) or equivalent

### Target Audience

- **Primary:** DevOps engineers, SREs, platform engineers, cloud architects
- **Secondary:** FinOps practitioners, data engineers, solution architects
- **Prerequisites:** Basic understanding of Elasticsearch indices and queries, familiarity with the Elastic AI Assistant (from Workshop 1)

### Learning Objectives

By the end of this workshop, participants will be able to:

1. Explain the architecture of an Agent Builder agent (instructions + tools)
2. Dissect an existing tool and identify its three components (ID, description, query)
3. Write an ES|QL query that answers a specific business question
4. Register a custom tool via the Agent Builder API
5. Wire a tool into an existing agent
6. Understand why tool descriptions matter for AI routing
7. Observe multi-tool chaining for compound analysis

### Schedule

| Time | Module | Duration | Challenge |
|------|--------|----------|-----------|
| 0:00 | Module 1: From Consumer to Creator | 20 min | Challenge 1 |
| 0:20 | Module 2: Explore Data & Dissect a Tool | 30 min | Challenge 2 |
| 0:50 | Module 3: Build Your First Tool | 40 min | Challenge 3 |
| 1:30 | Break | 10 min | — |
| 1:40 | Module 4: Design Your Own Tool | 40 min | Challenge 4 |
| 2:20 | Module 5: Getting Further + Wrap-up | 30 min | Challenge 5 |
| 2:50 | Q&A and Feedback | 10 min | — |

### Positioning vs Workshop 1

| | Workshop 1 (OTel) | Workshop 2 (Agent Builder) |
|---|---|---|
| **Role** | Consumer of AI | Creator/Builder of AI |
| **Tools** | Built-in Observability tools | Custom ES\|QL-powered tools |
| **Data** | OpenTelemetry demo (live telemetry) | GCP cost data (seeded dataset) |
| **Infra** | Kubernetes + Helm + OTel Collector | Pre-provisioned ES + Kibana |
| **Key skill** | Prompt the AI Assistant | Build and register tools |
| **Outcome** | Investigate incidents with AI | Extend agent capabilities |

---

## Environment Setup

### Pre-Workshop Checklist

Run these checks at least 1 hour before the workshop starts:

```bash
# 1. Clone the repo
git clone https://github.com/baerchen110/elastic-observability-kafeju.git
cd elastic-observability-kafeju

# 2. Import all resources
./scripts/import-resources.sh <ES_URL> <KIBANA_URL> elastic <PASSWORD>

# 3. Verify the Kafeju agent exists
curl -s -u elastic:<PASSWORD> <KIBANA_URL>/api/agent_builder/agents \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
agents = json.load(sys.stdin)['results']
kafeju = [a for a in agents if a['id'] == 'kafuju']
print(f'Kafeju agent: {\"FOUND\" if kafeju else \"MISSING\"}')"

# 4. Verify tools
curl -s -u elastic:<PASSWORD> <KIBANA_URL>/api/agent_builder/tools \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
tools = json.load(sys.stdin)
kafeju_tools = [t for t in tools if 'kafeju' in t.get('id','')]
print(f'Kafeju tools: {len(kafeju_tools)} (expected: 15)')"

# 5. Verify data
curl -s -u elastic:<PASSWORD> <ES_URL>/_cat/count?h=count
# Expected: ~12243

# 6. Verify LLM connector (critical!)
curl -s -u elastic:<PASSWORD> <KIBANA_URL>/api/actions/connectors \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
connectors = json.load(sys.stdin)
llm = [c for c in connectors if c.get('connector_type_id') in ('.gen-ai', '.bedrock', '.gemini')]
print(f'LLM connectors: {len(llm)} (need at least 1)')"

# 7. Test a tool invocation manually
curl -s -X POST -u elastic:<PASSWORD> <ES_URL>/_query \
  -H "Content-Type: application/json" \
  -d '{"query": "FROM gcp-resource-executions-* | STATS count = COUNT(*) BY metadata.team | LIMIT 5"}'
```

### LLM Connector Setup

The AI Assistant requires an LLM connector. If not pre-configured:

1. Go to **Kibana > Management > Stack Management > Connectors**
2. Click **Create connector**
3. Choose one of: OpenAI, Azure OpenAI, Bedrock, or Gemini
4. Configure with your API credentials
5. Test the connector

### Per-Participant Access (Shared Environment)

If running on a shared cluster, create namespaced credentials:

```bash
for i in $(seq -w 1 20); do
  curl -s -X POST "$ES_URL/_security/api_key" \
    -u elastic:<PASSWORD> \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"workshop-participant-$i\",
      \"role_descriptors\": {
        \"workshop_user\": {
          \"cluster\": [\"monitor\", \"manage_ml\"],
          \"indices\": [{
            \"names\": [\"gcp-*\", \"ml-predictions-*\"],
            \"privileges\": [\"read\", \"view_index_metadata\"]
          }]
        }
      },
      \"expiration\": \"8h\"
    }"
done
```

**Note:** For Agent Builder tool creation, participants need write access to Kibana saved objects. Use the `elastic` superuser for simplicity in workshop settings, or create a custom role with `kibana_admin` privileges.

---

## Data Overview (Facilitator Reference)

| Index | Docs | Key Purpose |
|-------|------|-------------|
| gcp-resource-executions-2025.11 | 98 | Real VM execution data |
| gcp-resource-executions-synthetic | 5,000 | Augmented data across 9 teams |
| gcp-instance-lifecycle | 1,065 | Real VM lifecycle events |
| gcp-instance-lifecycle-synthetic | 2,000 | Augmented lifecycle |
| gcp-billing-actual | 3,000 | Billing records with team costs |
| gcp-pricing-catalog | 30 | Machine type pricing |
| gcp-vm-pricing | 189 | VM pricing by region |
| gcp-workload-requirements | 21 | Workload specs and SLAs |
| gcp-requested-resources | 5 | Original resource requests |
| gcp-instance-inventory-2025.11.07 | 35 | Daily instance snapshot |
| ml-predictions-anomalies | 3 | Real ML anomalies |
| ml-predictions-anomalies-synthetic | 500 | Augmented anomalies |
| ml-predictions-cost-forecast | 189 | Team cost projections |
| ml-predictions-growth | 104 | Workload growth trends |
| ml-predictions-growth-summary | 4 | Growth summary per team |

**Total:** ~12,243 documents

---

## Module-by-Module Facilitator Notes

### Module 1: From Consumer to Creator (20 min)

**Your demo:**
1. Open AI Assistant, select Kafeju
2. Ask: "Which teams are wasting the most money on idle VMs?"
   - Expected: Agent uses `analyze_vm_usage_patterns` or `calculate_cost_optimization_1`
   - Walk through the response, point out tool invocation
3. Ask: "Which GCP region is cheapest for n2-standard-8 instances?"
   - Expected: Agent struggles — no tool for this
   - **This is the hook.** "By the end, you will build this tool."
4. Show the architecture slide: Agent = Instructions + Tools; Tool = ID + Description + Query

**Key message:** "In Workshop 1 you were a consumer. Today you become a creator."

### Module 2: Explore Data & Dissect a Tool (30 min)

**Facilitator circulates** while participants explore Discover and run the API calls.

**Common issues:**
- Time range not set to "Last 1 year" — data appears missing
- ES|QL mode toggle not found — it's at the top of Discover
- Fields look different from docs — nested fields show as `field.subfield`

**Key teaching moment:** When they run the raw query vs. ask the agent, emphasize that the tool provides *data* and the AI provides *narrative interpretation*.

### Module 3: Build Your First Tool (40 min)

**This is the critical module.** Walk around and help anyone stuck.

**Common blockers:**
- JSON escaping in curl (newlines in queries) — remind them to use `\n`
- Tool created but not wired into agent — Step 4 is often skipped
- Agent doesn't use the tool — description might not match the prompt; help them rephrase

**Success signal:** Participant asks "Find zombie VMs" and gets a structured table response.

### Module 4: Design Your Own Tool (40 min)

**Suggest challenge cards based on comfort:**
- Struggling participants → Card A (simplest, 1 STATS BY)
- Comfortable participants → Card B or C
- Advanced participants → Card D (requires EVAL for computed fields)

**With 10 min left:** Call for volunteers to share their tool live.

### Module 5: Getting Further (30 min)

**The compound question demo is yours to run.** Have the zombie VM tool and at least one regional/pricing tool ready (either from a participant or pre-built as backup).

Ask: "I just found zombie VMs in my infrastructure. Can you tell me which region would be cheapest to move the surviving workloads to, and estimate my monthly savings if I rightsize and relocate?"

**Backup:** If no participant built the regional tool, use the solve script from Challenge 4 to create one before this demo.

---

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| AI Assistant not responding | Check LLM connector in Management > Connectors |
| "No agent found" error | Run: `curl ... /api/agent_builder/agents` to verify |
| Tool created but agent doesn't use it | Check the description — is it specific enough? |
| Query returns 0 results | Set time range to "Last 1 year"; verify index exists |
| 409 Conflict on tool creation | Tool ID already exists; delete first then recreate |
| Agent update fails | Ensure you stripped `readonly` and `type` fields |
| Participant tools conflicting | Use namespaced IDs: `participant01.tool_name` |

---

## Materials Checklist

- [ ] `workshop/participant-guide.md` — printed or shared digitally
- [ ] `workshop/esql-cheat-sheet.md` — one per participant
- [ ] `workshop/tool-template.sh` — pre-loaded on each VM at `/root/tool-template.sh`
- [ ] LLM connector configured and tested
- [ ] All 15 Kafeju tools verified working
- [ ] Kafeju agent responding to basic questions
- [ ] Slides for Module 1 intro (Agent = Instructions + Tools diagram)
- [ ] Backup solve scripts tested for Challenges 3 and 4
