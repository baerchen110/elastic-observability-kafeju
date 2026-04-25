# Challenge 3: Build your first tool, zombie VM detector

A "zombie VM" is a virtual machine running at near-zero CPU
utilization on an expensive machine type — it costs money but does
nothing useful. Every cloud team has them.
You will now build a tool that finds them, register it in the
Agent Builder UI, wire it into the Kafeju agent, and test it with
a natural-language prompt. Everything happens in Kibana — no
terminal or API calls required.

## Step 1: Design the query
===
Think about what you need:

- **Data view:** **GCP Resource Executions** — has CPU usage and cost
  data (ES|QL index pattern: `gcp-resource-executions-*`)
- **Filter:** CPU usage below 15% (barely alive)
- **Aggregate:** Group by team, VM type, resource name
- **Metrics:** Average CPU, drift score, total cost, occurrence count
- **Sort:** By cost descending (most expensive zombies first)

> **Token budget tip (important for tools):**
> - `LIMIT` is the strongest control for token usage. Tool results are
>   passed back to the model; more rows means more tokens, higher cost,
>   and slower responses.
> - `KEEP` also reduces tokens by reducing the number of columns
>   returned.
> - Use both whenever possible: filter/aggregate first, then `KEEP`
>   only the columns the answer needs, then `LIMIT` to a reasonable row
>   count (often 10-50 rows for agent tools).
> - In this specific query, `STATS ... BY` already narrows output to a
>   compact schema, and `LIMIT 15` caps row volume.

## Step 2: Test the query in Discover
===
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

Why `LIMIT 15` here? It keeps the result focused on the highest-impact
zombie workloads while keeping the tool response compact for the model.

![Screenshot 2026-04-23 at 16.09.21.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/0621d0d81a2b78422054e991c8905069/assets/Screenshot%202026-04-23%20at%2016.09.21.png)
You should see results showing teams with low-CPU VMs and their costs.
If results appear, the query works and you can proceed.

**Tip:** If you get no results, check the time range (set to **Last 1
year**) and verify the field names by expanding a document in Discover.

Keep this query handy — you'll paste it into the tool in the next step.

## Step 3: Register the tool in the Agent Builder UI
===
1. In the app search bar, type **Agent tools** and select **Agents / Tools**
![Screenshot 2026-04-23 at 15.19.34.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/55f58451546db5499b9c307574cab2d3/assets/Screenshot%202026-04-23%20at%2015.19.34.png)
2. Click **New tool**
3. Fill in the form:

  | Field           | Value                                                                                                                                                                                                                            |
  | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | **Tool ID**     | `participant.find_zombie_vms`                                                                                                                                                                                                    |
  | **Type**        | `ESQL`                                                                                                                                                                                                                           |
  | **Description** | *Finds zombie VMs: machines with very low CPU usage (under 15%) that are wasting money. Shows which teams have idle resources ranked by total cost waste. Use when asked about zombie VMs, idle instances, or wasted resources.* |
  | **Labels**      | `participant`, `infrastructure`, `cost`                                                                                                                                                                                          |
  | **ES\|QL Query**| Paste the exact query from Step 2                                                                                                                                                                                                |

![Screenshot 2026-04-23 at 16.12.23.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/53bc86a884b78e02d192433b146cbf65/assets/Screenshot%202026-04-23%20at%2016.12.23.png)
  > **Why the description matters:** When Kafeju receives a question,
  > it scans every tool's description to decide which one to call.
  > The phrase *"Use when asked about zombie VMs, idle instances, or
  > wasted resources"* is routing signal — make it explicit.
4. Click **Save & Test** to sanity-check the tool:
   - This tool takes no inputs, so just click **Submit**.
   - In the **Response** panel, scroll down
     confirm you see values with fields `avg_cpu`, `avg_drift`,
     `total_cost`, `occurrences`, `metadata.team`,
     `vm_info.vm_type_actual`, `resource_name`.
   - The rows should match what you saw in Discover in Step 2.

![Screenshot 2026-04-23 at 16.13.09.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/9696533aea8eaafb180e7a040286e8d6/assets/Screenshot%202026-04-23%20at%2016.13.09.png)
5. Close the flyout.
6. Verify the tool appears in the **Tools** list. Type `participant` in
  the filter — you should see `participant.find_zombie_vms`.
![Screenshot 2026-04-23 at 16.15.18.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/4a652d508a59d832c61971e385420b3f/assets/Screenshot%202026-04-23%20at%2016.15.18.png)
> **What you should see:** A new row in the Tools tab whose ID starts
> with `participant.`. The tool page shows the same three components
> you dissected in Challenge 2 — **ID**, **description**, **ES|QL
> query**.

## Step 4: Wire the tool into the Kafeju agent
===
The tool exists, but the Kafeju agent doesn't know about it yet. In
Agent Builder you attach tools to agents explicitly.

1. In the App search bar, type **agents** and click on **Agents**.
![Screenshot 2026-04-23 at 16.17.28.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/304da552ede06aa5f5ea97cfd4befefc/assets/Screenshot%202026-04-23%20at%2016.17.28.png)
2. On the top right, click on **More** and select **View all agents**. Click to open the **Kafeju** agent.
![Screenshot 2026-04-23 at 16.17.49.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/0aaaf8ecd816e7db1a6b3569e7eee3db/assets/Screenshot%202026-04-23%20at%2016.17.49.png)

3. Click on **Tools** tab — this is the list of tools the
  agent is allowed to call.
4. Search for `participant`.
5. Select **`participant.find_zombie_vms`** to attach it.
![Screenshot 2026-04-23 at 16.22.01.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/866349baef9bbb786a953543bd000712/assets/Screenshot%202026-04-23%20at%2016.22.01.png)
7. Click **Save**
8. Confirm it now appears in the Kafeju tools list alongside the
   existing `kafeju.*` tools.
![Screenshot 2026-04-23 at 16.23.13.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/2e2427de0f108ede20ad0abadf3a018a/assets/Screenshot%202026-04-23%20at%2016.23.13.png)

> **What you should see:** The Kafeju agent's tool list now includes
> `participant.find_zombie_vms`. If the list previously had 15
> `kafeju.*` tools, it should now show 16.


## Step 5: Test your tool
===
Go to **Kibana > AI Agent**, switch to the **Kafeju** agent, and
ask:

```
Find zombie VMs — which expensive instances are sitting idle and wasting money?
```

Expand the **reasoning panel** under the answer and
confirm that `participant.find_zombie_vms` was the tool that ran.

![Screenshot 2026-04-23 at 16.24.03.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/ac9710c9f35d6b600df42240a59941fd/assets/Screenshot%202026-04-23%20at%2016.24.03.png)
The agent should return a structured table of teams, VM types, CPU
usage, and dollar waste.
![Screenshot 2026-04-23 at 16.24.48.png](https://play.instruqt.com/assets/tracks/nyxu84eztwnd/00d68a0e00a75325f347e6058ea146cc/assets/Screenshot%202026-04-23%20at%2016.24.48.png)
**The key comparison:** Remember in Challenge 1 when you asked this
same type of question and the agent couldn't answer? Now it produces
real data. **You built that capability in 10 minutes, without writing
a line of code outside ES|QL.**

## Check your work
===
The automated check verifies that:

1. A tool with ID containing `participant` exists.
2. The Kafeju agent's tool list includes it.

Before clicking **Next**, confirm in the UI:

- The **Tools** tab shows `participant.find_zombie_vms`.
- The **Agents** tab > **Kafeju** page lists that tool under its
attached tools.
- Kafeju actually invoked `participant.find_zombie_vms` when you
asked the zombie question in Step 5.

