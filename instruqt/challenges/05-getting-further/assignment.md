---
slug: getting-further
title: "Getting Further: Multi-Tool Chaining"
teaser: "See the agent chain your custom tools with existing tools to answer compound questions."
type: challenge
timelimit: 1800
tabs:
  - title: Kibana
    type: service
    hostname: elastic-vm
    port: 5601
notes:
  - type: text
    contents: |
      # Getting Further

      You have built two tools. The Kafeju agent already had 15.
      Now you have 17+ tools working together.

      In this final challenge, you will ask compound questions that
      require **multiple tools to chain together** — producing answers
      that no single tool could provide alone.

      This is the power of extensible AI agents: the whole is greater
      than the sum of the parts.
---

# Challenge 5: Getting Further — Multi-Tool Chaining

## The Compound Question

Open the **AI Assistant** > **Kafeju** and ask:

```
I just found zombie VMs in my infrastructure. Can you tell me which region would be cheapest to move the surviving workloads to, and estimate my monthly savings if I rightsize and relocate?
```

### Watch the agent chain tools

Expand the **reasoning / tool-call panel** under Kafeju's answer —
you should see the agent run **4–5 tool calls**, with a short
reasoning note in between each one explaining *why* it's calling the
next tool:

| # | Tool | Why it runs |
|---|------|-------------|
| 1 | **`participant.find_zombie_vms`** *(your tool)* | Identify the idle VMs, their teams, machine types, and cost impact. |
| 2 | **`kafeju.get_instance_cost_and_specs`** | Look up pricing for the current machine type (expect `n2-standard-32`) across regions. |
| 3 | **`kafeju.compare_instance_options`** | Find smaller, cost-optimized alternatives that still meet the workload's footprint. |
| 4 | **`kafeju.calculate_cost_optimization_1`** | Analyse P95 CPU / memory and drift to compute right-sized specs with a 20% safety headroom. |
| 5 | **`kafeju.get_instance_cost_and_specs`** *(again)* | Price the recommended right-sized types so it can compute savings. |

Every row in the panel is an **ES\|QL query** the agent wrote and
executed against your data. Click any row to see the query + the
raw  response that fed the next reasoning step.

### What the answer should look like

Kafeju weaves the five tool calls into a structured recommendation.
In the workshop dataset you should see something close to:

- **Cheapest region:** `us-central1` *(note: all rows in
  `gcp-pricing-catalog` live in `us-central1` for this workshop —
  so "cheapest region" here is really "only region in the catalog".
  Good reminder that tool output is only as rich as the data
  underneath.)*
- **Current machine type:** `n2-standard-32` — ~**$1,134/month** per VM
- **Recommended rightsize:** `e2-standard-4` (~$98/mo) or
  `n2-standard-4` (~$142/mo), sized for P95 + 20% headroom
- **Estimated savings:** **~$990–$1,036/month per VM**
- **Risk / priority:** Low / P0

A compound question that could have taken a FinOps analyst hours of
manual spreadsheeting is now a single prompt — because the custom
tool you built in Challenge 3 composes with the 15 built-ins that
shipped with Kafeju.

**Key insight:** You built two tools in under 30 minutes. Combined with
the existing 15, the agent can now answer FinOps questions that would
take a human analyst hours to research manually.

## Experiment: More Compound Questions

Try these compound questions that exercise multiple tools:

```
Show me the top 3 most wasteful teams, their zombie VMs, and what instances they should switch to.
```

```
Which team will hit capacity limits first, and is there a cheaper region they could expand into?
```

```
Calculate the total monthly savings if we eliminate all zombie VMs and move the remaining workloads to the cheapest region.
```

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

## Bonus: Improve a Tool Description (UI)

A common issue: the AI doesn't invoke your tool when you expect it
to. This is almost always a **description problem** — Kafeju picks
tools by matching the user's intent against each tool's description.

### The experiment

1. **Ask a question that *should* trigger your tool — using fuzzy
   wording.** For example, instead of saying "find zombie VMs",
   try:

   ```
   Which of our machines are basically doing nothing right now?
   ```

2. Expand the **tool-call / reasoning panel** under Kafeju's answer.
   Did `participant.find_zombie_vms` get invoked, or did the agent
   reach for something else (or say it couldn't help)?

3. **If the agent missed your tool**, the description is too narrow.
   Edit it in the UI and retry.

### Edit the description in the Agent Builder UI

1. Hamburger menu > **Agent Builder** > **Tools** tab.
2. Filter by `participant` and open your tool (e.g.
   `participant.find_zombie_vms`).
3. Click **Edit** (pencil icon).
4. Rewrite the **Description** to explicitly list the phrasings a
   user might use. Good descriptions include:

   - **What** the tool returns (*"idle VMs with CPU below 15% and
     their teams, machine types, total cost waste"*).
   - **When** the AI should call it (*"Use when asked about zombie
     VMs, idle machines, wasted instances, underutilised VMs, or
     'which machines are doing nothing'"*).
   - Any **aliases / synonyms** your users actually say.

5. Click **Save & Test** to confirm the query still runs, then
   **Save**.
6. Back in the **AI Assistant > Kafeju**, re-ask the same fuzzy
   question from step 1. Confirm the tool is now invoked in the
   reasoning panel.

> **Takeaway:** The ES|QL is the *capability*; the description is
> the *routing signal*. A perfect query the agent never calls is
> worth nothing. Good descriptions answer: *"When should the AI
> pick this tool instead of another one?"*

## Summary: What You Built Today

- Explored GCP resource data in Elasticsearch
- Dissected an existing Agent Builder tool
- Built a Zombie VM Detector from scratch
- Designed your own tool for a real business question
- Wired both tools into a custom agent
- Saw multi-tool chaining produce compound FinOps answers
- Learned that tool descriptions are critical for AI routing

**The difference between "using an agent" and "building an agent" is
a short UI form and ~10 lines of ES|QL.**

## Check Your Work

This challenge is complete when you have successfully asked at least
one compound question and received a multi-tool answer.
