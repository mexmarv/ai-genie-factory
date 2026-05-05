# AI Genie Factory

**by Marvin Nahmias & Javier Hauss — Alpura, Mexico City**
*Presented at DATA+AI Summit 2026*

---

## What Is This?

The AI Genie Factory is a methodology for building enterprise Databricks applications at scale using AI code generation that always adheres to your architecture.

The core insight: **AI doesn't generate architecture — it generates code. Architecture has to be defined first, then enforced as constraints.**

This repository is that constraint layer. It contains markdown specification files that, when loaded into Databricks Genie Code as persistent instructions, ensure every generated app respects your platform standards: Medallion layers, Unity Catalog governance, semantic layer KPIs, and the [ai-dev-kit](https://github.com/databricks/ai-dev-kit) component library.

At Alpura, this system produced **90+ apps** across Finance, Sales, Operations, and Marketing — most in days, some in hours.

---

## The Factory Methodology

Traditional approach: one app at a time, each a new project, logic reinvented per team.

Factory approach: build the system once, then generate apps on top of it.

```
Platform (Lakehouse)
  └── Governance (Unity Catalog)
        └── Semantic Layer (Central KPIs, Gold Tables)
              └── Factory (Specs + Modules + Rules)
                    └── AI Generation (Genie Code)
                          └── Apps / Pipelines / Notebooks
```

The factory gives you three things:
- **Consistency** — every app reads from Gold tables, follows the same layer separation, uses the same component library
- **Speed** — prompts replace sprints; architecture is already solved
- **Trust** — constraints prevent AI from inventing its own patterns or bypassing governance

---

## Repository Structure

```
ai-genie-factory/
├── AGENTS.md                # ⬅ COMBINED constraints file — this is what you load into Genie Code
├── GLOBAL_RULES.md          # Platform + architecture rules (included in AGENTS.md)
├── STACK.md                 # Technology stack (included in AGENTS.md)
├── modules/
│   ├── data_access.md       # spark.table() patterns (included in AGENTS.md)
│   └── ui_patterns.md       # Plotly chart patterns (included in AGENTS.md)
└── apps/
    └── dbu_spend_app/
        └── APP.md           # Example app spec — pasted into the Genie Code prompt
```

> **`AGENTS.md` is the single file you work with.** It is the combined content of `GLOBAL_RULES.md`, `STACK.md`, `modules/data_access.md`, and `modules/ui_patterns.md` in one place, ready to be loaded into Genie Code. The individual files are the source of truth — if you edit them, update `AGENTS.md` to match.

### Constraint Priority

| Priority | Source | Purpose |
|----------|--------|---------|
| 1 | `GLOBAL_RULES.md` | Platform law — never overridden |
| 2 | `STACK.md` | Technology choices — not redefined per app |
| 3 | `modules/*.md` | Reusable patterns — imported, not reinvented |
| 4 | `APP.md` | App-specific spec — only what's unique to this app |

---

## How Genie Code Reads Constraints

Genie Code does **not** accept `.md` file uploads in chat (only images can be attached). Constraints are loaded from specific files saved in the **Databricks workspace filesystem**, where Genie Code picks them up automatically.

| Mechanism | File | Location | Scope |
|-----------|------|----------|-------|
| User instructions | `.assistant_instructions.md` | `/Users/<your-email>/` | Your sessions only |
| Workspace instructions (admin) | `.assistant_workspace_instructions.md` | `Workspace/` root | All users, all sessions |

**Character limit: 20,000.** `AGENTS.md` is ~4,200 characters — well under the limit.

---

## Quick Start: Run the Example

This deploys the **DBU Spend Monitor** — a working app that visualizes Databricks Unit consumption over time and by cluster from `system.billing.usage`.

### Prerequisites

- Databricks workspace with Unity Catalog enabled
- Genie Code enabled in your workspace
- **System tables access enabled** — a workspace admin must enable system tables under *Settings → System tables*. Without this, `system.billing.usage` will be empty or inaccessible. See [Enable system tables](https://docs.databricks.com/aws/en/admin/system-tables/index.html).

---

### Step 1 — Load constraints into Genie Code (one-time setup)

> **This step loads the entire factory into Genie Code. You only do this once — all future apps just need a prompt.**

1. Click the **Genie Code sparkle icon** (upper-right corner of your workspace) to open the Genie Code pane.
2. Inside the pane, click the **gear icon** to open Genie Code settings.
3. Under **User instructions**, click **Add instructions file**.

This creates `/Users/<your-email>/.assistant_instructions.md` and opens it in a new tab.

> **Copy the entire contents of [`AGENTS.md`](./AGENTS.md) and paste it into this file, then save.**

`AGENTS.md` contains all the factory constraints combined — global rules, stack, data access patterns, and UI patterns — in a single file ready to paste.

From this point on, every Genie Code session automatically applies these constraints.

> **Want it workspace-wide?** A workspace admin can paste the same `AGENTS.md` content into `Workspace/.assistant_workspace_instructions.md` to enforce constraints for all users.

---

### Step 2 — Open Genie Code and paste the app spec

Open a new Genie Code session and paste:

```
Apply all constraints from the instructions file already loaded.

Respect this priority:
1. GLOBAL_RULES
2. STACK
3. Data access and UI modules
4. The app spec below

Use components and patterns from:
https://github.com/databricks/ai-dev-kit

Task:
Build and deploy the following app.

--- APP SPEC ---

APP NAME: DBU Spend Monitor

Objective:
Visualize Databricks Unit (DBU) consumption over time and by cluster with a polished dark-themed dashboard.

Data:
- system.billing.usage

Schema notes:
- DBU consumption column: usage_quantity (decimal)
- Date column: usage_date (date)
- Cluster identifier: usage_metadata.cluster_id (nullable struct sub-field)
- Filter to DBU records only: usage_unit = 'DBU'
- Filter to original records only: record_type = 'ORIGINAL'

Metrics:
- Total DBUs consumed per day
- Total DBUs consumed per cluster (top 10 by usage, exclude nulls)
- Grand total DBUs in selected period (KPI card)

Transformations:
- Base filter: WHERE usage_unit = 'DBU' AND record_type = 'ORIGINAL'
- Time series: group by usage_date -> sum(usage_quantity) as total_dbus
- By cluster: group by usage_metadata.cluster_id -> sum(usage_quantity) as total_dbus, filter where usage_metadata.cluster_id IS NOT NULL, order by total_dbus DESC, limit 10
- KPI total: sum(usage_quantity) across entire filtered dataset

UI:
- KPI card at the top: total DBUs in period (large bold number, formatted with commas)
- Line chart: total_dbus over usage_date, filled area under the curve
- Bar chart: top 10 clusters by total_dbus, horizontal bars sorted descending

Filters:
- Date range (default: last 30 days)

Design:
- Dark background (#0d1117)
- Color scheme: blues and teals (primary #00bcd4, accent #7c4dff)
- Use plotly_dark template for all charts
- KPI card: large font, accent color, subtitle showing date range
- Hover tooltips with formatted numbers and comma separators
- App title: "DBU Spend Monitor" with subtitle "Powered by system.billing.usage"

Constraints:
- None beyond GLOBAL_RULES

--- END SPEC ---

Do not redefine stack or architecture. Follow all constraints strictly.
Return only the deployed application details.
```

### Step 3 — Allow the file write

Genie Code will warn: **"Code execution blocked for safety reasons: the code writes a Python file to a path under /Workspace/Users."**

This is expected. Genie is writing the generated app files (e.g. `logic.py`, `app.py`) to the workspace so they can be deployed as a Databricks App — that is exactly what you want. **Click bypass/allow to continue.**

This warning is a Databricks safety gate on workspace file writes, not a constraint violation. Your constraints have nothing to do with it.

### Step 4 — Review the output

Genie Code will generate and deploy a Databricks App with:
- Line chart: DBU usage over time (grouped by `usage_date`)
- Bar chart: DBU usage by cluster (grouped by `cluster_id`)
- Date range filter
- Pandas conversion only in the UI layer
- No SQL outside the data access module

---

## Building Your Own App

1. Create `apps/<your_app_name>/APP.md` in this repo using the template below.
2. Paste its contents into a new Genie Code session using the same prompt structure as Step 2 above, replacing the DBU Spend Monitor spec with your own.

```markdown
APP NAME: <Name>

Objective:
<One sentence describing what this app shows or enables>

Data:
- <catalog.schema.table>

Metrics:
- <metric 1>
- <metric 2>

Transformations:
- <grouping/aggregation logic>

UI:
- <specific chart type if required — omit to let Genie choose>

Filters:
- <filter dimension>

Constraints:
- <only rules not already covered by GLOBAL_RULES — omit section if none>
```

The loaded constraints already enforce Gold tables, three-layer separation, Plotly, spark.table(), and ai-dev-kit. Only add a `Constraints` section for things genuinely unique to this app.

---

## Extending the Factory

When you update any source file, run `build_agents.py` to rebuild `AGENTS.md` and keep what's loaded into Genie Code in sync:

```bash
python3 build_agents.py
```

This overwrites `AGENTS.md` with the combined contents of all constraint files and prints the character count against the 20,000-character limit.

### Add a new data access pattern
Edit `modules/data_access.md` — add new `spark.table()` patterns reusable across apps. Then run `python3 build_agents.py`.

### Add a new chart type
Edit `modules/ui_patterns.md` — add new Plotly chart types compatible with the stack. Then run `python3 build_agents.py`.

### Add a global architecture rule
Edit `GLOBAL_RULES.md` — only for platform-wide rules that apply to every future app. Then run `python3 build_agents.py`.

---

## Architecture Standards Enforced

Every app generated by this factory inherits these standards:

**Medallion Architecture**
- Apps consume Gold tables only. Bronze and Silver are pipeline concerns.
- Gold tables are materialized views or Photon-optimized Delta tables with star schema.

**Unity Catalog Governance**
- All tables referenced as `catalog.schema.table` (three-part naming).
- Access controlled via RBAC/ACLs — apps inherit workspace permissions.
- Column lineage and data contracts tracked at the platform level.

**Semantic Layer**
- Central KPIs (EBITDA, Sales, Finance, Operations) defined once via `dbxs` metrics in Unity Catalog.
- No app recalculates a KPI that already exists in the semantic layer.

**Three-Layer Separation**
- `Data` — `spark.table()` reads only, no transformation logic
- `Logic` — aggregations and transformations, no SQL or UI dependencies
- `UI` — Plotly charts, pandas conversion happens here and nowhere else

**Component Library**
- All reusable components from [databricks/ai-dev-kit](https://github.com/databricks/ai-dev-kit)
- No custom components that duplicate existing ai-dev-kit patterns

---

## Contributing

Contributions are welcome — new app specs, new modules, new constraint patterns, or improvements to existing files.

When contributing, please keep attribution in any forks or derived work referencing the original authors: **Marvin Nahmias & Javier Hauss, Alpura**.

---

## Reference

- Component library: [github.com/databricks/ai-dev-kit](https://github.com/databricks/ai-dev-kit)
- Databricks Genie Code docs: [docs.databricks.com/aws/en/genie-code](https://docs.databricks.com/aws/en/genie-code)
- Databricks Apps: [docs.databricks.com/aws/en/dev-tools/databricks-apps](https://docs.databricks.com/aws/en/dev-tools/databricks-apps)
- DATA+AI Summit 2026 talk: *0 to 100 AI/BI Apps in 120 Days* — Marvin Nahmias & Javier Hauss, Alpura
