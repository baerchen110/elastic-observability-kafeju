---

slug: build-zombie-vm-detector
title: "Build Your First Tool: Zombie VM Detector"
teaser: "Create a custom ES|QL-powered tool, register it, and wire it into the Kafeju agent — all from the UI."
type: challenge
timelimit: 2400
tabs:

- title: Kibana
type: service
hostname: elastic-vm
port: 5601
notes:
- type: text
contents: |
  # Build Your First Tool
    A "zombie VM" is a virtual machine running at near-zero CPU
    utilization on an expensive machine type — it costs money but does
    nothing useful. Every cloud team has them.
    You will now build a tool that finds them, register it in the
    Agent Builder UI, wire it into the Kafeju agent, and test it with
    a natural-language prompt. Everything happens in Kibana — no
    terminal or API calls required.
    The full loop: **Design → Write → Register → Wire → Test**

---

# Challenge 3: Build Your First Tool — Zombie VM Detector

## Step 1: Design the Query (5 min)

Think about what you need:

- **Source:** `gcp-resource-executions-`* (has CPU usage and cost data)
- **Filter:** CPU usage below 15% (barely alive)
- **Aggregate:** Group by team, VM type, resource name
- **Metrics:** Average CPU, drift score, total cost, occurrence count
- **Sort:** By cost descending (most expensive zombies first)

## Step 2: Test the Query in Discover (10 min)

Open **Kibana > Discover > ES|QL mode** and run:

```sql
FROM gcp-resource-executions-*
| WHERE resource_usage.cpu.avg_percent < 15
  AND vm_info.vm_type_actual IS NOT NULL
| STATS
    avg_cpu = AVG(resource_usage.cpu.avg_percent),
    avg_drift = AVG(drift_metrics.combined_drift_score),
    total_cost = SUM(cost_actual.total_cost_usd),
    occurrences = COUNT(*)
  BY metadata.team, vm_info.vm_type_actual, resource_name
| SORT total_cost DESC
| LIMIT 15
```

You should see results showing teams with low-CPU VMs and their costs.
If results appear, the query works and you can proceed.

**Tip:** If you get no results, check the time range (set to **Last 1
year**) and verify the field names by expanding a document in Discover.

Keep this query handy — you'll paste it into the tool in the next step.

## Step 3: Register the Tool in the Agent Builder UI (10 min)

1. Open the hamburger menu > **Agent Builder** (on some builds it sits
  under **Management** > **Agent Builder**).
2. Click the **Tools** tab.
3. Click **Create** (or **New tool** / **+**, depending on the build).
4. Fill in the form:

  | Field           | Value                                                                                                                                                                                                                            |
  | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | **Tool ID**     | `participant.find_zombie_vms`                                                                                                                                                                                                    |
  | **Type**        | `ES|QL`                                                                                                                                                                                                                          |
  | **Description** | *Finds zombie VMs: machines with very low CPU usage (under 15%) that are wasting money. Shows which teams have idle resources ranked by total cost waste. Use when asked about zombie VMs, idle instances, or wasted resources.* |
  | **Labels**      | `participant`, `infrastructure`, `cost`                                                                                                                                                                                          |
  | **ES|QL Query** | Paste the exact query from Step 2                                                                                                                                                                                                |

  > **Why the description matters:** When Kafeju receives a question,
  > it scans every tool's description to decide which one to call.
  > The phrase *"Use when asked about zombie VMs, idle instances, or
  > wasted resources"* is routing signal — make it explicit.
5. Click **Save** & **Test** to sanity-check the tool:
  - This tool takes no inputs, so just click **Sumbit**.
  - In the **Response** panel, expand the `tabular_data` entry and
  confirm you see rows with columns `avg_cpu`, `avg_drift`,
  `total_cost`, `occurrences`, `metadata.team`,
  `vm_info.vm_type_actual`, `resource_name`.
  - The rows should match what you saw in Discover in Step 2.
6. Click **Save**.
7. Verify the tool appears in the **Tools** list. Type `participant` in
  the filter — you should see `participant.find_zombie_vms`.

> **What you should see:** A new row in the Tools tab whose ID starts
> with `participant.`. The tool page shows the same three components
> you dissected in Challenge 2 — **ID**, **description**, **ES|QL
> query**.

## Step 4: Wire the Tool Into the Kafeju Agent (5 min)

The tool exists, but the Kafeju agent doesn't know about it yet. In
Agent Builder you attach tools to agents explicitly.

1. In Agent Builder, click the **Agents** tab.
2. Open the **Kafeju** agent (you may need to click **Edit** or the
  pencil icon to enter edit mode).
3. Scroll to the **Tools** section — this is the list of tools the
  agent is allowed to call.
4. Click **Add tool** (or the search/filter box at the bottom of the
  list) and search for `participant`.
5. Select `**participant.find_zombie_vms`** to attach it.
6. Confirm it now appears in the Kafeju tools list alongside the
  existing `kafeju.*` tools.
7. Click **Save** (or **Update agent**).

> **What you should see:** The Kafeju agent's tool list now includes
> `participant.find_zombie_vms`. If the list previously had ~10
> `kafeju.`* tools, it should now show 11.
>
> **Why this step exists:** Creating a tool and attaching it to an
> agent are two separate actions. A tool that isn't attached to any
> agent is invisible to Kafeju — the agent will never pick it up,
> no matter how good the description is.

## Step 5: Test Your Tool (10 min)

Go to **Kibana > AI Agent**, switch to the **Kafeju** agent, and
ask:

> **"Find zombie VMs — which expensive instances are sitting idle and
> wasting money?"**

Expand the **tool-call / reasoning panel** under the answer and
confirm that `participant.find_zombie_vms` was the tool that ran.
The agent should return a structured table of teams, VM types, CPU
usage, and dollar waste.

**The key comparison:** Remember in Challenge 1 when you asked this
same type of question and the agent couldn't answer? Now it produces
real data. **You built that capability in 10 minutes, without writing
a line of code outside ES|QL.**

## Check Your Work

The automated check verifies that:

1. A tool with ID containing `participant` exists.
2. The Kafeju agent's tool list includes it.

Before clicking **Check**, confirm in the UI:

- The **Tools** tab shows `participant.find_zombie_vms`.
- The **Agents** tab > **Kafeju** page lists that tool under its
attached tools.
- Kafeju actually invoked `participant.find_zombie_vms` when you
asked the zombie question in Step 5.

