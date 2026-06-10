# AI Genie Factory

**by Marvin Nahmias & Javier Hauss — Alpura, Mexico City**
*Presented at DATA+AI Summit 2026*

---

## What Is This?

The AI Genie Factory is a methodology for building enterprise Databricks applications at scale using AI code generation that always adheres to your architecture.

The core insight: **AI doesn't generate architecture — it generates code. Architecture has to be defined first, then enforced as constraints.**

This repository contains two types of constraints:

- **`AGENTS.md`** — lean always-on guardrails (platform rules, stack, error handling, logging). Loaded once into Genie Code's instructions file. ~6,000 chars.
- **`skills/`** — domain skills loaded on demand by Genie Code Agent mode, or `@mentioned` by name. Each skill is focused, contextual, and doesn't bloat every generation.

At Alpura, this system produced **90+ apps** across Finance, Sales, Operations, and Marketing — most in days, some in hours.

---

## The Factory Methodology

```
Platform (Lakehouse)
  └── Governance (Unity Catalog)
        └── Semantic Layer (Central KPIs, Gold Tables)
              └── Factory (AGENTS.md + Skills)
                    └── Genie Code Agent Mode
                          └── Apps / Pipelines / Notebooks
```

---

## Repository Structure

```
ai-genie-factory/
│
├── AGENTS.md                          ← Lean always-on constraints (~6,000 chars)
├── GLOBAL_RULES.md                    ← Platform law (never override)
├── STACK.md                           ← Technology choices (never override)
├── build_agents.py                    ← Assembles AGENTS.md from core modules only
│
├── modules/                           ← Source files compiled into AGENTS.md
│   ├── error_handling.md              ← try/except contracts, custom exceptions
│   └── logging.md                     ← Structured logging standard (_logger.py)
│
├── skills/                            ← Databricks Genie Code Agent skills
│   ├── databricks-app-design/         ← @databricks-app-design
│   │   ├── SKILL.md                   ← UX/UI tokens, Plotly theme, layout, KPI cards
│   │   └── references/
│   │       ├── dash_patterns.md       ← Full Dash app shell + callback patterns
│   │       └── streamlit_patterns.md  ← Streamlit equivalent patterns
│   ├── data-access/                   ← @data-access
│   │   └── SKILL.md                   ← spark.table(), Unity Catalog, DataAccessError
│   ├── dlt-pipeline/                  ← @dlt-pipeline
│   │   └── SKILL.md                   ← Bronze/Silver/Gold, Auto Loader, expectations
│   ├── testing-scaffold/              ← @testing-scaffold
│   │   └── SKILL.md                   ← pytest, mocked Spark, pandas logic tests
│   └── ui-patterns/                   ← @ui-patterns
│       └── SKILL.md                   ← Plotly chart functions, pandas conversion rules
│
├── templates/
│   ├── PROMPT_TEMPLATE.md             ← Exact prompt for every Genie Code session
│   └── APP_TEMPLATE.md                ← Blank APP spec — fill this out per app
│
└── apps/
    └── dbu_spend_app/
        └── APP.md                     ← Working example: DBU Spend Monitor
```

---

## AGENTS.md vs Skills — When to Use Each

| | AGENTS.md | Skills |
|---|---|---|
| **When loaded** | Every Genie Code session | Only when relevant to the request |
| **Purpose** | Non-negotiable platform guardrails | Domain knowledge, patterns, design systems |
| **Size target** | < 6,000 chars | As large as needed |
| **Contents** | Global rules, stack, error handling, logging | Charts, pipelines, testing, UX/UI design |
| **How to invoke** | Automatic | Automatic (Agent mode) or `@skill-name` |

**Rule of thumb:** if it applies to every single generation, it goes in AGENTS.md. If it applies to a specific type of work, it's a skill.

---

## Constraint Priority

| Priority | Source | Purpose |
|----------|--------|---------|
| 1 | `GLOBAL_RULES.md` | Platform law — never overridden |
| 2 | `STACK.md` | Technology choices — never redefined per app |
| 3 | `modules/error_handling.md` | Error contracts — never overridden |
| 4 | `modules/logging.md` | Logging standard — never overridden |
| 5 | `@data-access` skill | spark.table() patterns |
| 6 | `@ui-patterns` skill | Plotly chart layer rules |
| 7 | `@databricks-app-design` skill | UX/UI design system, color tokens |
| 8 | `@dlt-pipeline` skill | Pipeline patterns |
| 9 | `@testing-scaffold` skill | Test scaffold |
| 10 | `APP.md` | App-specific spec — only what's unique to this app |

---

## Setup: One-Time Deployment

### Step 1 — Load AGENTS.md into Genie Code instructions

1. Open **Genie Code** (sparkle icon, top-right of Databricks workspace)
2. Click **gear icon ⚙️ → User instructions → Add instructions file**
3. This creates `/Users/<your-email>/.assistant/instructions.md`
4. **Paste the entire contents of `AGENTS.md` into that file and save**

> **Workspace-wide:** Admin pastes the same into `Workspace/.assistant/instructions.md`

---

### Step 2 — Deploy skills to Databricks workspace

Skills live at `Workspace/.assistant/skills/` (workspace) or `/Users/<email>/.assistant/skills/` (personal).

**Option A — Databricks CLI (recommended):**
```bash
# From repo root — deploy all skills workspace-wide (requires admin)
for skill in skills/*/; do
  skill_name=$(basename "$skill")
  databricks workspace import-dir "$skill" \
    "/Workspace/.assistant/skills/${skill_name}" --overwrite
done

# Or deploy to your personal skills folder
for skill in skills/*/; do
  skill_name=$(basename "$skill")
  databricks workspace import-dir "$skill" \
    "/Users/<your-email>/.assistant/skills/${skill_name}" --overwrite
done
```

**Option B — Databricks workspace UI:**
1. Open **Workspace** in the left sidebar
2. Navigate to `.assistant/skills/` (create it if it doesn't exist)
3. Create a folder for each skill (e.g., `databricks-app-design`)
4. Upload the `SKILL.md` and any reference files into each folder

Genie Code picks up skills automatically the next time you open it in Agent mode.

---

### Step 3 — Fill out an APP spec

Copy `templates/APP_TEMPLATE.md` and fill in every field before prompting.

---

### Step 4 — Open Genie Code in Agent mode and prompt

Use `templates/PROMPT_TEMPLATE.md` as your prompt. Skills are loaded automatically, or `@mention` them:

```
@databricks-app-design build the sales dashboard per the spec below
@dlt-pipeline create the ingestion pipeline for the orders feed
@testing-scaffold add tests to the app I just built
```

---

## Rebuilding AGENTS.md

After editing `GLOBAL_RULES.md`, `STACK.md`, or `modules/*.md`:

```bash
python build_agents.py
```

Output:
```
✅  LEAN  AGENTS.md — 5,989 / 20,000 chars (29.9%)
   Target: keep under 12,000 chars (60%) — domain knowledge belongs in skills/

  Skills to deploy separately (copy to Workspace/.assistant/skills/):
    @data-access
    @databricks-app-design
    @dlt-pipeline
    @testing-scaffold
    @ui-patterns
```

---

## Debugging a Generated App

```
1. FILE STRUCTURE
   □ data.py / logic.py / ui.py / app.py / _logger.py all present?
   □ If no → re-prompt with PROMPT_TEMPLATE.md, @mention missing skill

2. LAYER VIOLATIONS
   □ spark.table() outside data.py?   → @data-access, move to data.py
   □ Business logic in ui.py?         → move to logic.py
   □ toPandas() outside ui.py?        → @ui-patterns, move to ui.py

3. TABLE NAMES
   □ All refs three-part (catalog.schema.table)?
   □ Hardcoded strings outside app.py config dict?

4. LOGGING
   □ Each file imports from _logger?
   □ Check Databricks Apps logs for ERROR lines first

5. ERROR HANDLING
   □ data.py raises DataAccessError on failure?
   □ ui.py catches exceptions and shows _error_figure()?

6. DESIGN SYSTEM
   □ Background #0d1117, cards #161b22?  → @databricks-app-design
   □ All charts use plotly_dark template?
   □ No px.pie (use px.treemap), no #636efa (use #00bcd4)?

7. PIPELINE
   □ DLT tables named bronze_/silver_/gold_?  → @dlt-pipeline
   □ No spark.read() inside DLT notebooks?
   □ File paths use /Volumes/ not dbfs:/?
```

---

## Example App: DBU Spend Monitor

See `apps/dbu_spend_app/APP.md` — reads `system.billing.usage`, available in every workspace with system tables enabled.

---

## Contributing

1. Edit `GLOBAL_RULES.md`, `STACK.md`, or `modules/*.md` → run `python build_agents.py`
2. Edit skills in `skills/<name>/SKILL.md` → redeploy that skill folder to the workspace
3. Never edit `AGENTS.md` directly — it's generated
4. Add new apps under `apps/<app-name>/APP.md`

---

## License

MIT — use freely, adapt to your stack.

---

*AI generates code. Not architecture. — Marvin Nahmias, DAIS 2026*
