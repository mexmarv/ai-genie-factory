# AI Genie Factory

**by Marvin Nahmias & Javier Hauss — Alpura, Mexico City**
*Presented at DATA+AI Summit 2026*

---

## What Is This?

The AI Genie Factory is a methodology for building enterprise Databricks applications at scale using AI code generation that always adheres to your architecture.

The core insight: **AI doesn't generate architecture — it generates code. Architecture has to be defined first, then enforced as constraints.**

This repository is that constraint layer. It contains markdown specification files that, when loaded into Databricks Genie Code as persistent instructions, ensure every generated app respects your platform standards: Medallion layers, Unity Catalog governance, semantic layer KPIs, fixed file structure, error handling, and logging.

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
│
├── AGENTS.md                        ← Combined constraints — load once into Genie Code
├── GLOBAL_RULES.md                  ← Platform law (never override)
├── STACK.md                         ← Technology choices (never override)
├── build_agents.py                  ← Assembles AGENTS.md from source files
│
├── modules/
│   ├── data_access.md               ← spark.table() patterns
│   ├── ui_patterns.md               ← Plotly chart patterns
│   ├── error_handling.md            ← try/except contracts, custom exceptions
│   ├── logging.md                   ← Structured logging standard (_logger.py)
│   ├── dlt_pipeline.md              ← Delta Live Tables pipeline patterns
│   └── testing.md                   ← Unit test scaffold standard
│
├── templates/
│   ├── PROMPT_TEMPLATE.md           ← Exact prompt structure for every Genie Code session
│   └── APP_TEMPLATE.md              ← Blank APP spec — fill this out per app
│
└── apps/
    └── dbu_spend_app/
        └── APP.md                   ← Working example: DBU Spend Monitor
```

### Constraint Priority

| Priority | Source | Purpose |
|----------|--------|---------|
| 1 | `GLOBAL_RULES.md` | Platform law — never overridden |
| 2 | `STACK.md` | Technology choices — not redefined per app |
| 3 | `modules/error_handling.md` | Error contracts — never overridden |
| 4 | `modules/logging.md` | Logging standard — never overridden |
| 5 | `modules/data_access.md` | Read patterns — imported, not reinvented |
| 6 | `modules/ui_patterns.md` | Chart patterns — imported, not reinvented |
| 7 | `modules/dlt_pipeline.md` | Pipeline patterns — applies to pipeline apps |
| 8 | `modules/testing.md` | Test scaffold — never overridden |
| 9 | `APP.md` | App-specific spec — only what's unique to this app |

---

## How Genie Code Reads Constraints

Genie Code picks up constraints from specific files saved in the Databricks workspace filesystem.

| Mechanism | File | Location | Scope |
|-----------|------|----------|-------|
| User instructions | `.assistant_instructions.md` | `/Users/<your-email>/` | Your sessions only |
| Workspace instructions | `.assistant_workspace_instructions.md` | `Workspace/` root | All users (admin sets this) |

**Character limit: 20,000.** `AGENTS.md` is ~8,500 characters — well under the limit.

---

## Quick Start

### Step 1 — Load constraints into Genie Code (one-time)

1. Open **Genie Code** (sparkle icon, top-right of your Databricks workspace)
2. Click the **gear icon** → **User instructions** → **Add instructions file**
3. This creates `/Users/<your-email>/.assistant_instructions.md` — open it
4. **Copy the entire contents of `AGENTS.md` and paste it into that file, then save**

Every Genie Code session from this point on automatically applies all factory constraints.

> **Workspace-wide?** A workspace admin pastes the same content into `Workspace/.assistant_workspace_instructions.md` to enforce for all users.

---

### Step 2 — Fill out an APP spec

Copy `templates/APP_TEMPLATE.md` and fill in every field:
- App name and objective
- Unity Catalog table names (three-part: `catalog.schema.table`)
- Metrics (reference semantic layer KPIs by name — don't recalculate them)
- Transformations, UI components, filters, design

A complete APP spec is what separates a 2-hour app from a 2-day debugging session.

---

### Step 3 — Open Genie Code and paste the prompt

Copy `templates/PROMPT_TEMPLATE.md` verbatim into a new Genie Code session.
Replace `[PASTE APP.md CONTENT HERE]` with your filled-out APP spec.

Genie Code will generate exactly these files:
```
_logger.py       ← shared logger
data.py          ← data layer (spark.table reads only)
logic.py         ← logic layer (aggregations, business rules)
ui.py            ← UI layer (Plotly figures, pandas conversion)
app.py           ← entry point
tests/
  test_data.py   ← data layer test stubs
  test_logic.py  ← logic layer test stubs
```

---

### Step 4 — Deploy

```bash
# From within your Databricks workspace or CLI:
databricks apps deploy <app-name> --source-code-path /path/to/generated/app
```

---

## Rebuilding AGENTS.md

After editing any source file, regenerate `AGENTS.md`:

```bash
python build_agents.py
```

Output:
```
✅  OK  AGENTS.md — 8,512 / 20,000 chars (42.6%)
```

If you're over 85% of the limit, the script warns you. If you're over 100%, Genie Code silently truncates — constraints at the bottom stop applying.

---

## Debugging a Generated App

When something breaks, check in this order:

```
1. FILE STRUCTURE
   □ data.py / logic.py / ui.py / app.py / _logger.py all present?
   □ If no → re-prompt using PROMPT_TEMPLATE.md exactly

2. LAYER VIOLATIONS
   □ spark.table() call outside data.py?  → move to data.py
   □ Business logic inside ui.py?         → move to logic.py
   □ pandas conversion outside ui.py?     → move to ui.py

3. TABLE NAMES
   □ All table refs three-part (catalog.schema.table)?
   □ Any hardcoded outside app.py config dict?

4. LOGGING
   □ Each file imports from _logger?
   □ Check Databricks Apps logs for ERROR lines before reading code

5. ERROR HANDLING
   □ Data layer wrapped in try/except → DataAccessError?
   □ UI layer catching exceptions and displaying them?

6. KPI DRIFT
   □ Any metric calculated inline that exists in the semantic layer?
   □ If yes → delete it, read the Gold materialized view instead
```

---

## Example App: DBU Spend Monitor

See `apps/dbu_spend_app/APP.md` for a complete working example.

This app visualizes Databricks Unit consumption over time and by cluster using `system.billing.usage` — available in every Databricks workspace with system tables enabled.

**Prerequisites:**
- Unity Catalog enabled
- Genie Code enabled
- System tables enabled (Settings → System tables)

---

## Contributing

1. Edit source files (`GLOBAL_RULES.md`, `STACK.md`, `modules/*.md`)
2. Run `python build_agents.py` to regenerate `AGENTS.md`
3. Never edit `AGENTS.md` directly — it's generated
4. Add new apps under `apps/<app-name>/APP.md`

---

## License

MIT — use freely, adapt to your stack.

---

*AI generates code. Not architecture. — Marvin Nahmias, DAIS 2026*
