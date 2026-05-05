# AI Genie Factory

**by Marvin Nahmias & Javier Hauss — Alpura, Mexico City**
*Presented at DATA+AI Summit 2026*

---

## What Is This?

The AI Genie Factory is a methodology for building enterprise Databricks applications at scale using AI code generation that always adheres to your architecture.

The core insight: **AI doesn't generate architecture — it generates code. Architecture has to be defined first, then enforced as constraints.**

This repository is that constraint layer. It contains markdown specification files that are deployed into the Databricks workspace filesystem, where Genie Code automatically picks them up as persistent instructions. Every generated app then respects your platform standards: Medallion layers, Unity Catalog governance, semantic layer KPIs, and the [ai-dev-kit](https://github.com/databricks/ai-dev-kit) component library.

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
├── GLOBAL_RULES.md          # Non-negotiable platform + architecture rules
├── STACK.md                 # Technology stack (language, UI, data access, libraries)
├── modules/
│   ├── data_access.md       # All spark.table() patterns and Unity Catalog access
│   └── ui_patterns.md       # Approved Plotly chart types
└── apps/
    └── dbu_spend_app/
        └── APP.md           # Example: DBU Spend Monitor
```

### Constraint Priority

When Genie processes multiple files, this priority order applies:

| Priority | File | Purpose |
|----------|------|---------|
| 1 | `GLOBAL_RULES.md` | Platform law — never overridden |
| 2 | `STACK.md` | Technology choices — not redefined per app |
| 3 | `modules/*.md` | Reusable patterns — imported, not reinvented |
| 4 | `APP.md` | App-specific spec — only what's unique to this app |

---

## How Genie Code Reads Constraints

Genie Code does **not** accept `.md` file uploads in chat (only images can be attached there). Instead, constraints are loaded from specific files in the **Databricks workspace filesystem**. Genie Code reads these automatically — no chat attachment needed.

There are three mechanisms, from broadest to narrowest scope:

| Mechanism | File | Location in workspace | Scope |
|-----------|------|-----------------------|-------|
| Workspace instructions (admin) | `.assistant_workspace_instructions.md` | `Workspace/` root | All users, all sessions |
| User instructions | `.assistant_instructions.md` | `/Users/<your-email>/` | Your sessions only |
| Project instructions | `AGENTS.md` | Any project folder | Notebooks in that folder subtree |

**Limit:** All instruction files are capped at 20,000 characters (the combined factory files are well under this).

---

## Quick Start: Run the Example

This walks you through deploying the **DBU Spend Monitor** — a working app that visualizes Databricks Unit consumption over time and by cluster, reading from `system.billing.usage`.

### Prerequisites

- Databricks workspace with Unity Catalog enabled
- Access to `system.billing.usage` (requires `system` catalog read permission)
- Genie Code enabled in your workspace

### Step 1 — Load the constraints into Genie Code (one-time setup)

1. Click the **Genie Code sparkle icon** (upper-right corner of your workspace) to open the Genie Code pane.
2. Inside the pane, click the **gear icon** to open Genie Code settings.
3. Under **User instructions**, click **Add instructions file**.

This creates `/Users/<your-email>/.assistant_instructions.md` and opens it in a new tab. Paste the full contents of [`AGENTS.md`](./AGENTS.md) from this repository into it and save. Limit is 20,000 characters — the factory constraints are well under that.

From this point on, every Genie Code session you open will automatically apply these constraints — no need to repeat this step for future apps.

> **Want it workspace-wide?** A workspace admin can paste the same content into `Workspace/.assistant_workspace_instructions.md` to enforce the constraints for all users automatically.

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
Visualize DBU usage over time and by cluster.

Data:
- system.billing.usage

Metrics:
- total DBUs per day
- total DBUs per cluster

Transformations:
- group by usage_date -> sum(dbus)
- group by cluster_id -> sum(dbus)

UI:
- Line chart (DBUs over time)
- Bar chart (DBUs by cluster)

Filters:
- Date range

Constraints:
- Use Plotly for charts
- Convert to pandas only in UI layer
- No SQL outside data access module

--- END SPEC ---

Rules:
- Do not redefine stack or architecture
- Follow all constraints strictly

Return only the deployed application details.
```

### Step 3 — Review the output

Genie Code will generate and deploy a Databricks App with:
- Line chart: DBU usage over time (grouped by `usage_date`)
- Bar chart: DBU usage by cluster (grouped by `cluster_id`)
- Date range filter
- Pandas conversion only in the UI layer
- No SQL outside the data access module

---

## Building Your Own App

Create `apps/<your_app_name>/APP.md` following this template:

```markdown
APP NAME: <Name>

Objective:
<One sentence describing what this app shows or enables>

Data:
- <catalog>.<schema>.<table>   ← always a Gold table from Unity Catalog

Metrics:
- <metric 1>
- <metric 2>

Transformations:
- <grouping/aggregation logic>

UI:
- <chart type from modules/ui_patterns.md>
- <chart type>

Filters:
- <filter dimension>

Constraints:
- <any app-specific constraints beyond GLOBAL_RULES>
```

**Rules for writing APP.md:**
- Reference only Gold layer tables (e.g., `catalog.gold.sales_daily`). Never Bronze or Silver in UI-facing apps.
- Do not redeclare the stack, charts library, or architecture — those are inherited.
- Keep transformations declarative (describe what, not how). Genie decides the implementation.
- Add app-specific constraints only for things not covered by GLOBAL_RULES.md.

---

## Extending the Factory

### Add a new data access pattern
Edit `modules/data_access.md` when a new Unity Catalog table or read pattern is needed across multiple apps. Keep it as `spark.table("catalog.schema.table")` — no JDBC, no raw SQL.

### Add a new chart type
Edit `modules/ui_patterns.md` when a new Plotly chart type is approved for use. Only add chart types that are compatible with the Plotly/Databricks Apps stack.

### Add architecture constraints
Edit `GLOBAL_RULES.md` only when a new platform-wide rule applies to all future apps — for example, adding a data quality requirement or a new governance policy.

---

## Architecture Standards Enforced

Every app generated by this factory inherits these standards:

**Medallion Architecture**
- Apps consume Gold tables only. Bronze and Silver are pipeline concerns.
- Gold tables are materialized views or Delta tables with Photon-optimized star schemas.

**Unity Catalog Governance**
- All tables referenced as `catalog.schema.table` (three-part naming).
- Access controlled via RBAC/ACLs — apps inherit workspace permissions.
- Column lineage and data contracts are tracked at the platform level.

**Semantic Layer**
- Central KPIs (EBITDA, Sales, Finance, Operations) defined once in the semantic layer via `dbxs` metrics and Unity Catalog metrics store.
- No app recalculates a KPI that already exists in the semantic layer.

**Three-Layer Separation**
- `Data` — `spark.table()` calls only, in the data access module
- `Logic` — transformations and aggregations, no UI dependencies
- `UI` — Plotly charts, pandas conversion happens here and nowhere else

**Component Library**
- All reusable components sourced from [databricks/ai-dev-kit](https://github.com/databricks/ai-dev-kit)
- No custom components that duplicate existing ai-dev-kit patterns

---

## Contributing

Contributions are welcome — new app specs, new modules, new constraint patterns, or improvements to existing files.

When contributing, please keep attribution in any forks or derived work referencing the original authors: **Marvin Nahmias & Javier Hauss, Alpura**.

---

## Reference

- Component library: [github.com/databricks/ai-dev-kit](https://github.com/databricks/ai-dev-kit)
- Databricks Genie Code: [docs.databricks.com/genie](https://docs.databricks.com/genie)
- Databricks Apps: [docs.databricks.com/apps](https://docs.databricks.com/apps)
- DATA+AI Summit 2026 talk: *0 to 100 AI/BI Apps in 120 Days* — Marvin Nahmias & Javier Hauss, Alpura
