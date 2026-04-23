# Build Your Own AI Agent - Instruqt Track

This folder contains the Instruqt track for **Workshop 2** in the Elastic
AI Assistant series:
**Build Your Own AI Agent - From Consumer to Creator**.

The track is designed as a UI-first, hands-on journey where participants move
from asking an AI agent questions to extending that agent with custom tools.
By the end, learners build and wire their own ES|QL-powered tools into Kafeju
and observe multi-tool reasoning on real FinOps-style questions.

## What Participants Learn

- How to inspect and validate agent behavior with the reasoning/tool-call panel
- How Agent Builder tools are structured (tool ID, description, ES|QL query)
- How to build a custom tool from scratch in Kibana
- How to wire custom tools into an agent and test them with natural language
- Why tool descriptions matter for routing and invocation quality
- How tool chaining enables compound answers that a single query cannot produce

## Track Structure (5 Challenges)

### 1) Use the custom agent

Participants explore the available workshop datasets in Discover, meet the
Kafeju agent, and identify capability gaps. This establishes a key mindset:
agent answers must be validated against data and tool output.

### 2) Explore ML Anomalies and Dissect a Tool

Participants start in the Kibana ML UI, inspect existing anomaly detection
jobs/results, and connect those results to a Kafeju tool. They learn how ML
outputs become queryable evidence in agent responses.

### 3) Build Your First Tool - Zombie VM Detector

Participants design and test a guided ES|QL query, register a new
`participant.find_zombie_vms` tool in Agent Builder, wire it into Kafeju, and
confirm invocation from a prompt.

### 4) Design Your Own Tool

Participants choose a business question from challenge cards, author their own
ES|QL query, create a second `participant.*` tool, and validate behavior via
tool testing and agent prompting.

### 5) Getting Further - Multi-Tool Chaining

Participants run compound prompts and inspect how Kafeju composes custom tools
with built-in tools to produce end-to-end recommendations (for example:
zombie detection + pricing + optimization).

The focus is not exact deterministic phrasing from the LLM, but evidence-backed
reasoning across tool calls and ES|QL outputs.

## Data and Domain Context

The workshop uses synthetic-but-realistic GCP FinOps data in Elasticsearch,
including:

- Resource execution telemetry and drift metrics
- Billing and pricing catalog data
- ML anomaly and growth prediction outputs
- Prebuilt visualizations/dashboards for orientation

This gives learners a realistic setting for capacity planning, rightsizing,
and cost optimization workflows.

## Repository Layout

- `track.yml` - track metadata and configuration
- `challenges/01-resource-drift/` - challenge 1 materials
- `challenges/02-ml-anomaly-detection/` - challenge 2 materials
- `challenges/03-build-your-own-tool/` - challenge 3 materials
- `challenges/04-design-your-own-tool/` - challenge 4 materials
- `challenges/05-getting-further/` - challenge 5 materials
- `data/` - workshop data generation, tool definitions, and setup scripts

## Outcome

After completing the track, participants should be able to go from:

- **Using an AI agent** -> asking questions and interpreting responses

to:

- **Building an AI agent capability** -> creating domain tools that improve
  correctness, coverage, and practical business value.
