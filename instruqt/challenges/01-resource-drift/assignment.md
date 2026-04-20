---
slug: from-consumer-to-creator
title: "From Consumer to Creator"
teaser: "Explore the Kafeju agent and discover what it can — and can't — do."
type: challenge
timelimit: 1200
tabs:
  - title: Kibana
    type: service
    hostname: elastic-vm
    port: 5601
  - title: Terminal
    type: terminal
    hostname: elastic-vm
notes:
  - type: text
    contents: |
      # From Consumer to Creator

      In Workshop 1, you used the Observability AI Assistant with built-in
      tools. The tools were pre-made — you were a **consumer** of AI.

      In this workshop, you become a **creator**. You will build your own
      tools and wire them into a custom agent called **Kafeju** — a GCP
      cost-optimization agent that detects resource drift and recommends
      rightsizing.

      First, let's explore what Kafeju can already do — and find its gaps.
---

# Challenge 1: From Consumer to Creator

## Step 1: Log In and Meet Kafeju

1. Open the **Kibana** tab
2. Log in with: `elastic` / `workshopAdmin1!`
3. Click the **AI Assistant** icon (sparkle in the top nav)
4. In the agent selector dropdown, choose **Kafeju**

Kafeju is a custom agent with custom tools. Its specialty is GCP VM cost
optimization.

## Step 2: See What Kafeju Can Do

Ask the Kafeju agent these questions and observe the results:

> **"Which teams are wasting the most money on idle VMs?"**

Watch the tool invocation — you should see it call
`kafeju.analyze_vm_usage_patterns` or similar.

> **"Detect any resource anomalies across our VMs."**

This should invoke `kafeju.detect_resource_anomalies`.

## Step 3: Find the Gap

Now ask a question that seems reasonable but Kafeju cannot answer well:

> **"Which GCP region is cheapest for n2-standard-8 instances?"**

And:

> **"Find zombie VMs — which expensive instances are sitting idle?"**

Notice: Kafeju struggles with these. It may hallucinate, give a generic
answer, or say it doesn't have the right data. These are real questions
that the existing tools don't cover.

**Key insight:** The agent's capability is limited by its tools. No tool
for regional pricing? The agent can't answer regional questions. No tool
for zombie detection? The agent guesses instead of querying data.

## Step 4: Understand the Architecture

Open the **Terminal** tab and run:

```bash
curl -s -u elastic:workshopAdmin1! \
  http://localhost:5601/api/agent_builder/agents \
  -H "kbn-xsrf: true" | python3 -c "
import json, sys
agents = json.load(sys.stdin)['results']
for a in agents:
    if a['id'] == 'kafuju':
        print(f\"Agent: {a['name']}\")
        print(f\"Tools: {len(a['configuration']['tools'][0]['tool_ids'])}\")
        for tid in a['configuration']['tools'][0]['tool_ids']:
            print(f'  - {tid}')
"
```

Count the tools. Note which ones start with `kafeju.` (custom) vs
`platform.core.` (built-in). The custom tools are ES|QL queries that
you will learn to build in the next challenges.

## Check Your Work

Before clicking **Check**, confirm you:
- Successfully logged into Kibana
- Asked Kafeju at least one working question and one failing question
- Can explain why some questions fail (missing tools)
