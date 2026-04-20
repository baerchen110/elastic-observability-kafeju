---
slug: wow-moment
title: "The Wow Moment: Multi-Tool Chaining"
teaser: "See the agent chain your custom tools with existing tools to answer compound questions."
type: challenge
timelimit: 1800
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
      # The Wow Moment

      You have built two tools. The Kafeju agent already had 15.
      Now you have 17+ tools working together.

      In this final challenge, you will ask compound questions that
      require **multiple tools to chain together** — producing answers
      that no single tool could provide alone.

      This is the power of extensible AI agents: the whole is greater
      than the sum of the parts.
---

# Challenge 5: The Wow Moment — Multi-Tool Chaining

## The Compound Question

Open the **AI Assistant** > **Kafeju** and ask:

> **"I just found zombie VMs in my infrastructure. Can you tell me which
> region would be cheapest to move the surviving workloads to, and
> estimate my monthly savings if I rightsize and relocate?"**

Watch what happens:
1. The agent uses your **zombie VM tool** to find idle instances
2. It uses the **regional pricing tool** (yours or built-in) to find
   cheaper alternatives
3. It uses `kafeju.recommend_instance_for_requirements` to suggest
   rightsized instance types
4. It synthesizes everything into a recommendation

**Key insight:** You built two tools in under 30 minutes. Combined with
the existing 15, the agent can now answer FinOps questions that would
take a human analyst hours to research manually.

## Experiment: More Compound Questions

Try these compound questions that exercise multiple tools:

> **"Show me the top 3 most wasteful teams, their zombie VMs, and
> what instances they should switch to."**

> **"Which team will hit capacity limits first, and is there a
> cheaper region they could expand into?"**

> **"Calculate the total monthly savings if we eliminate all zombie
> VMs and move the remaining workloads to the cheapest region."**

Notice how the agent weaves together data from different tools to
build a narrative answer. Each tool returns a data table; the AI
interprets and connects them.

## Reflect: Before vs After

Think back to Challenge 1:
- **Before:** You asked about zombie VMs and cheapest regions. The
  agent guessed, hallucinated, or said it couldn't help.
- **After:** The same agent now produces structured, data-driven
  answers backed by real ES|QL queries against your data.

**What changed?** Not the data. Not the agent's instructions. Not
the AI model. Just **two tools** — ~10 lines of ES|QL each.

## Key Takeaways

Write down your top 3 takeaways. Here are prompts:

1. What surprised you about how easy/hard it was to build a tool?
2. How important is the tool *description* vs the query itself?
3. What tool would you build first for your own data at work?

## Bonus: Improve a Tool Description

A common issue: the AI doesn't invoke your tool when you expect it
to. This is almost always a **description problem**.

Try this experiment:
1. Ask Kafeju a question that should trigger your tool
2. If it doesn't use it, update the description to be more specific

Update a tool description:

```bash
# Delete the old tool
curl -s -X DELETE http://localhost:5601/api/agent_builder/tools/participant.YOUR_TOOL \
  -u elastic:workshopAdmin1! -H "kbn-xsrf: true"

# Re-create with a better description
curl -s -X POST http://localhost:5601/api/agent_builder/tools \
  -u elastic:workshopAdmin1! \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "participant.YOUR_TOOL",
    "description": "IMPROVED DESCRIPTION: be very specific about when to use this tool",
    "tags": ["participant"],
    "configuration": {
      "query": "YOUR SAME QUERY",
      "params": {}
    }
  }'
```

Good descriptions answer: "When should the AI use this tool instead
of another one?"

## Summary: What You Built Today

- Explored GCP resource data in Elasticsearch
- Dissected an existing Agent Builder tool
- Built a Zombie VM Detector from scratch
- Designed your own tool for a real business question
- Wired both tools into a custom agent
- Saw multi-tool chaining produce compound FinOps answers
- Learned that tool descriptions are critical for AI routing

**The difference between "using an agent" and "building an agent" is
one curl command and ~10 lines of ES|QL.**

## Check Your Work

This challenge is complete when you have successfully asked at least
one compound question and received a multi-tool answer.
