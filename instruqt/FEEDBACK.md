# Workshop Feedback

_Reviewer: Johannes · Date: 2026-04-21 · Stack: 9.3.3_

This document consolidates learner-experience feedback on the Instruqt
challenges (`instruqt/challenges/01-*` through `05-*`). Each item is
written as an actionable TODO so it can be picked up as a follow-up PR.
Check items off as they are addressed and keep the reviewer/date line
above accurate when the document is refreshed.

> **Scope:** this file is feedback-only. No challenge content is changed
> in the same PR that introduces the feedback.

---

## Cross-cutting principles

These apply to every challenge and should be adopted as content
conventions for the whole track. Instead of repeating them in each
challenge's section, track them here once:

- [ ] **"What to notice and why" callouts.** After every learner action,
  add a short paragraph (1–3 sentences) explaining what the learner
  should notice in the output and why it matters. A brief pause to
  think, followed by interpretation, is more effective than "run this
  command → move to the next step".
- [ ] **UI-first, CLI-as-advanced.** Where a task can be done in both
  the Kibana UI and the terminal / API, the Kibana UI is the default
  path and the CLI is an optional "advanced / alternative" path. When
  both paths are shown, explain when a learner should prefer each one
  and keep expected outcomes aligned between them.
- [ ] **Explicit expected outcomes.** Every step should state what a
  "successful" result looks like (a specific row count, a visible
  chart, an HTTP 200, a named object in Kibana, etc.).
- [ ] **Link to challenge files.** When implementing a fix, quote the
  heading or step number from the corresponding
  `instruqt/challenges/<id>/assignment.md` so reviewers can match the
  change to the feedback item.

---

## Challenge 01 — From Consumer to Creator

Source: `instruqt/challenges/01-resource-drift/assignment.md`

- [ ] **Add dataset & problem framing at the top of the challenge.**
  Currently there is not enough context on (a) what data is loaded,
  (b) what concrete problem the learner is expected to solve, and
  (c) why this matters. A short "Scenario" block at the top would fix
  this.
- [ ] **Introduce "Kafeju" with one sentence of backstory.** Explain the
  name (coffee ☕ + fortune-teller) and the agent persona so learners
  understand why the workshop is branded this way.
- [ ] **Unblock Step 4.** The `curl … | python3 -c …` command needs:
  - a one-line explanation of what it does and why it exists,
  - an example of the expected output,
  - a success-criteria bullet so the learner knows when to move on.
- [ ] **Use a dashboard to establish data context.** Before the
  interpretation tasks, show the learner a Kibana dashboard (or a
  labelled Discover view) of the workshop indices so they see the
  available fields, key dimensions, and baseline patterns. Learners
  should not be asked to interpret query output before they have seen
  the shape of the data.

## Challenge 02 — Explore Data and Dissect a Tool (ML Anomaly Detection)

Source: `instruqt/challenges/02-ml-anomaly-detection/assignment.md`

- [ ] **Provide example answers after each question in Step 1.** Add a
  collapsible "Expected answer" block after each question so learners
  can validate their interpretation without waiting for an instructor.
- [ ] **Do not rely on the raw results table alone.** Customers
  frequently struggle to infer insights from the tabular output. Pair
  each query with either (a) a short Lens visualization or (b) a
  narrative "what this row tells us" bullet list.
- [ ] **Clarify the ML story.** The challenge is named "ML Anomaly
  Detection" but does not clearly explain:
  - where ML has been run on the data (which job, which index),
  - which artifact/output comes from ML (`ml-predictions-*`),
  - what additional insight ML adds compared to plain querying.
  Add a short "Why ML here?" section with a before/after example.
- [ ] **Show both the UI and terminal paths for Steps 2 and 3.** Kibana
  UI as the default, `curl` / API as the advanced alternative. Explain
  when to prefer each one.
- [ ] **Sharpen the "tool vs. agent" coaching language.** Instead of
  "Compare the raw query results with the agent's narrative answer,"
  explicitly contrast the two outputs, e.g.:
  > "Here the tool returns structured rows; there the agent summarizes
  > implications. Tools provide raw data; the model adds
  > interpretation."

## Challenge 03 — Build Your First Tool: Zombie VM Detector

Source: `instruqt/challenges/03-build-your-own-tool/assignment.md`

- [ ] **Step 3: make the Kibana UI the primary path.** The terminal
  flow is a good alternative but is not the most intuitive starting
  point for a learner.
- [ ] **Step 4: same guidance as Step 3** — lead with the UI, keep the
  terminal instructions as an optional advanced / alternative path.

## Challenge 04 — Design Your Own Tool

Source: `instruqt/challenges/04-design-your-own-tool/assignment.md`

- [ ] **Strong challenge overall — no structural changes needed.**
- [ ] **Registration flow: UI-first.** Lead with registering the tool
  through the Kibana UI. Keep the CLI / registration-template path as
  an additional learning track for learners who want to see the
  declarative form.

## Challenge 05 — The Wow Moment: Multi-Tool Chaining

Source: `instruqt/challenges/05-wow-moment/assignment.md`

- [ ] **Adding tool descriptions: UI-first.** Prefer the Kibana UI as
  the default flow for editing tool descriptions and keep any
  CLI-based steps as an optional secondary path.

---

## Change log

| Date       | Reviewer  | Note                                      |
| ---------- | --------- | ----------------------------------------- |
| 2026-04-21 | Johannes  | Initial consolidated feedback (PR #2).    |
