# Challenge 5: Getting Further — Multi-Tool Chaining

## The Compound Question
===
Open the **AI Agent** > **Kafeju** and ask:

```
I just found zombie VMs in my infrastructure. Can you tell me which region would be cheapest to move the surviving workloads to, and estimate my monthly savings if I rightsize and relocate?
```

### Watch the agent chain tools

Expand the **reasoning / tool-call panel** under Kafeju's answer —
you should see the agent run **3–5 tool calls**, with a short
reasoning note in between each one explaining *why* it's calling the
next tool. The exact chain can vary by run/model:

| # | Tool | Why it runs |
|---|------|-------------|
| 1 | **`participant.find_zombie_vms`** *(your tool)* | Identify the idle VMs, their teams, machine types, and cost impact. |
| 2 | **`kafeju.get_instance_cost_and_specs`** | Look up pricing for the current machine type (expect `n2-standard-32`) across regions. |
| 3 | **`kafeju.compare_instance_options`** *(optional in some runs)* | Find smaller, cost-optimized alternatives that still meet the workload's footprint. |
| 4 | **`kafeju.calculate_cost_optimization_1`** *(optional in some runs)* | Analyse P95 CPU / memory and drift to compute right-sized specs with a 20% safety headroom. |
| 5 | **`kafeju.get_instance_cost_and_specs`** *(optional repeat)* | Price the recommended right-sized types so it can compute savings. |

You may also see a shorter chain like:

1. `participant.find_zombie_vms`
2. `kafeju.get_instance_cost_and_specs`
3. `kafeju.calculate_cost_optimization_1`

That is still a correct multi-tool composition.

Every row in the panel is an **ES\|QL query** the agent wrote and
executed against your data. Click any row to see the query + the
raw  response that fed the next reasoning step.

### What the answer should look like

Kafeju should weave the tool calls into a structured recommendation.
Because LLM synthesis is non-deterministic, **do not expect identical
wording or identical savings numbers every run**. Validate by checking
that the answer is grounded in tool output from this dataset:

- **Region conclusion:** usually `us-central1` *(for this workshop,
  the pricing catalog is effectively single-region, so "cheapest" is
  constrained by available catalog rows).*
- **Current machine context:** often references `n2-standard-32` for
  zombie/idle workloads.
- **Rightsizing narrative:** proposes smaller instance families/sizes
  based on drift and utilization evidence.
- **Savings estimate:** should be directionally large (material
  monthly reduction), but exact per-VM and total numbers may vary.
- **Priority/risk statement:** may vary (`P0`, "low risk", etc.).

If your run reports a different savings range (for example "~$850-$990
per VM" and ">$6,000/month total"), that is acceptable if the
reasoning panel shows the data path and ES|QL evidence.

A compound question that could have taken a FinOps analyst hours of
manual spreadsheeting is now a single prompt — because your custom
tools compose with Kafeju's built-in tools.

**Key insight:** You built two tools in under 30 minutes. Combined with
the existing built-ins, the agent can now answer FinOps questions that would
take a human analyst hours to research manually.

## Experiment: More Compound Questions
===
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
===
Think back to Challenge 1:
- **Before:** You asked about zombie VMs and cheapest regions. The
  agent guessed, hallucinated, or said it couldn't help.
- **After:** The same agent now produces structured, data-driven
  answers backed by real ES|QL queries against your data.

**What changed?** Not the data. Not the agent's instructions. Not
the AI model. Just **two tools** — ~10 lines of ES|QL each.

## Key Takeaways
===
Write down your top 3 takeaways. Here are prompts:

1. What surprised you about how easy/hard it was to build a tool?
2. How important is the tool *description* vs the query itself?
3. What tool would you build first for your own data at work?

## Bonus: Improve a Tool Description (UI)
===
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
===
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
===
This challenge is complete when you have successfully asked at least
one compound question and received a multi-tool answer.
