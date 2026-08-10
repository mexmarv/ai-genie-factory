# AI Genie Factory

**by Marvin Nahmias & Javier Hauss — Alpura, Mexico City**
*Premiering at DATA+AI Summit 2026*

**[mexmarv.github.io/ai-genie-factory](https://mexmarv.github.io/ai-genie-factory)**

[![Built on Databricks](https://img.shields.io/badge/Built%20on-Databricks-FF3621?style=flat&logo=databricks&logoColor=white)](https://github.com/databricks)
[![Genie Code](https://img.shields.io/badge/Powered%20by-Genie%20Code-00bcd4?style=flat&logo=databricks&logoColor=white)](https://www.databricks.com/product/databricks-assistant)
[![DATA+AI Summit 2026](https://img.shields.io/badge/DATA%2BAI%20Summit-2026-7c4dff?style=flat)](https://dataaisummit.com)

> Built on [@databricks](https://github.com/databricks) Genie Code Agent Mode and Unity Catalog.

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
├── AGENTS.md                          ← Lean always-on constraints (~8,300 chars)
├── GLOBAL_RULES.md                    ← Platform law (never override)
├── STACK.md                           ← Technology choices (never override)
├── LICENSE                            ← MIT
├── build_agents.py                    ← Assembles AGENTS.md from core modules only
├── deploy.sh                          ← Deploys instructions + skills via Databricks CLI
│
├── modules/                           ← Source files compiled into AGENTS.md
│   ├── error_handling.md              ← try/except contracts, custom exceptions
│   ├── logging.md                     ← Structured logging standard (_logger.py)
│   └── skill_index.md                 ← Always-loaded routing table — which skill covers what
│
├── skills/                            ← Agent Skills standard: one folder per skill
│   ├── ui-ux-patterns/SKILL.md          ← @ui-ux-patterns — dark/light tokens, typography, KPI cards, charts (Apps)
│   ├── databricks-app/SKILL.md          ← @databricks-app — app architecture, app.yaml, deployment, debug
│   ├── databricks-dashboard/SKILL.md    ← @databricks-dashboard — AI/BI datasets, widgets, filters, Vega-Lite waterfall
│   ├── databricks-dashboard-colors/SKILL.md ← @databricks-dashboard-colors — Lakeview dark/light theme + palette
│   ├── dlt-pipeline/SKILL.md            ← @dlt-pipeline — Bronze/Silver/Gold, CDC, SCD2, streaming
│   ├── data-access/SKILL.md             ← @data-access — Statement Execution, Unity Catalog, DataAccessError
│   └── testing-scaffold/SKILL.md        ← @testing-scaffold — pytest and mocked layer tests
│
├── templates/
│   ├── PROMPT_TEMPLATE.md             ← Exact prompt for every Genie Code session
│   └── APP_TEMPLATE.md                ← Blank APP spec — fill this out per app
│
├── docs/
│   └── index.html                     ← GitHub Pages landing page
│
└── apps/
    ├── nyc_taxi_explorer/
    │   └── APP.md                     ← Zero-permission starter: samples.nyctaxi.trips
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
| **Contents** | Global rules, stack, error handling, logging, skill index | Charts, pipelines, testing, UX/UI design |
| **How to invoke** | Automatic | Automatic (Agent mode) or `@skill-name` |

**Rule of thumb:** if it applies to every single generation, it goes in AGENTS.md. If it applies to a specific type of work, it's a skill.

**Do I need to `@mention` a skill?** No, not normally. Genie Code Agent mode reads each
skill's `description` frontmatter and loads it automatically when your prompt matches —
"build me a dashboard" alone is enough to pull in `@databricks-dashboard` and
`@databricks-dashboard-colors`. There is no third "always force this skill" setting for
skills — the only thing that is truly loaded on every single request, with zero matching
required, is `AGENTS.md`/the workspace instructions file. That's why `modules/skill_index.md`
exists: a short, always-loaded table naming every skill and when it should fire, so routing
stays reliable even when a prompt is worded ambiguously. `@mention` is still there for when
you want to force a specific skill regardless of wording.

---

## Constraint Priority

| Priority | Source | Purpose |
|----------|--------|---------|
| 1 | `GLOBAL_RULES.md` | Platform law — never overridden |
| 2 | `STACK.md` | Technology choices — never redefined per app |
| 3 | `modules/error_handling.md` | Error contracts — never overridden |
| 4 | `modules/logging.md` | Logging standard — never overridden |
| 5 | `@data-access` skill | WorkspaceClient Statement Execution, Unity Catalog, DataAccessError |
| 6 | `@ui-ux-patterns` skill | Design tokens, shadows, typography, charts, KPI cards (Apps) |
| 7 | `@databricks-app` skill | App file layers, app.yaml, OAuth M2M, deployment, debug checklist |
| 8 | `@databricks-dashboard` skill | AI/BI Lakeview dashboard SQL, widgets, filters, scheduling, Vega-Lite waterfall |
| 9 | `@databricks-dashboard-colors` skill | Lakeview dark/light theme tokens + visualization palette |
| 10 | `@dlt-pipeline` skill | Bronze/Silver/Gold, serverless DLT, CDC, SCD2, streaming |
| 11 | `@testing-scaffold` skill | pytest, mocked WorkspaceClient calls, pandas logic tests |
| 12 | `APP.md` | App-specific spec — only what's unique to this app |

---

## Setup: One-Time Deployment

### Prerequisites

- [Databricks CLI v0.200+](https://docs.databricks.com/dev-tools/cli/install.html) installed and configured
- Run `databricks auth login` if you haven't set up a profile yet

---

### Step 1 — Deploy instructions + skills via `deploy.sh`

From the repo root, run:

```bash
# Deploy to your personal Genie Code folder (default)
./deploy.sh

# Deploy workspace-wide so all users get the skills (requires workspace admin)
./deploy.sh --workspace

# Use a specific ~/.databrickscfg profile
./deploy.sh --profile my-profile

# Deploy to another user's personal folder (skip current-user lookup)
./deploy.sh --user someone@alpura.com

# Preview the exact commands without uploading anything
./deploy.sh --workspace --dry-run
```

The script uploads the exact paths documented by Databricks:

- Workspace instructions: `AGENTS.md` → `/Workspace/.assistant_workspace_instructions.md`
- Personal instructions: `AGENTS.md` → `/Users/<user>/.assistant_instructions.md`
- Workspace skills: `skills/<name>/SKILL.md` → `/Workspace/.assistant/skills/<name>/SKILL.md`
- Personal skills: `skills/<name>/SKILL.md` → `/Users/<user>/.assistant/skills/<name>/SKILL.md`

> **What `import-dir` can't do:** The Databricks CLI's `import-dir` only handles notebooks (`.py`, `.sql`, `.ipynb`). Plain `.md` skill files must be uploaded as raw files — `deploy.sh` handles this automatically using `databricks workspace import --format RAW`.

**Redeploying after edits:**
```bash
# After editing AGENTS.md or any skill, just re-run:
./deploy.sh
```

---

### Step 2 — Verify in Genie Code

1. Open **Genie Code** in Databricks (sparkle icon, top-right)
2. Click **⚙️** and open **User instructions** or **Workspace instructions**, depending on the deployment scope.
3. Switch to **Agent mode** and @mention any skill to confirm it's available:
   ```
   @ui-ux-patterns  @databricks-app  @databricks-dashboard  @databricks-dashboard-colors
   @dlt-pipeline  @data-access  @testing-scaffold
   ```

Genie Code picks up instructions on the next interaction. For a changed skill, start a new chat; hard-refresh the browser if its metadata remains stale.

Workspace instructions and skills guide Genie Code, but they are not a deterministic security boundary. Unity Catalog privileges, compute policies, service-principal permissions, and CI checks remain the enforcement layer. See [Workspace deployment and enforcement](docs/WORKSPACE_DEPLOYMENT.md).

---

### Step 3 — Fill out an APP spec

Copy `templates/APP_TEMPLATE.md` and fill in every field before prompting.

---

### Step 4 — Open Genie Code in Agent mode and prompt

Use `templates/PROMPT_TEMPLATE.md` as your prompt. Skills are loaded automatically, or `@mention` them:

```
@databricks-app @ui-ux-patterns build the sales dashboard per the spec below
@databricks-dashboard @databricks-dashboard-colors build a native Lakeview dashboard for daily revenue
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
✅  LEAN  AGENTS.md — 8,344 / 20,000 chars (41.7%)
   Target: keep under 12,000 chars (60%) — domain knowledge belongs in skills/

  Skills to deploy separately (copy to /Workspace/.assistant/skills/):
    @data-access
    @databricks-app
    @databricks-dashboard
    @databricks-dashboard-colors
    @dlt-pipeline
    @testing-scaffold
    @ui-ux-patterns
```

---

## Debugging a Generated App

```
1. FILE STRUCTURE
   □ data.py / logic.py / ui.py / app.py / _logger.py all present?
   □ If no → re-prompt with PROMPT_TEMPLATE.md, @mention missing skill

2. LAYER VIOLATIONS
   □ SQL outside data.py?  → @data-access, move it into the data layer
   □ WorkspaceClient created in ui.py? → move it into data.py
   □ Business logic in ui.py?          → move to logic.py
   □ toPandas() called anywhere?       → Apps use pandas; data.py returns pd.DataFrame

3. DATA ACCESS
   □ Using WorkspaceClient Statement Execution API in Databricks Apps?
   □ Warehouse ID comes from configuration rather than a hardcoded literal?
   □ Statement result types are normalized before logic/UI use?

4. TABLE NAMES
   □ All refs three-part (catalog.schema.table)?
   □ Hardcoded strings outside app.py config dict?

5. LOGGING
   □ Each file imports from _logger?
   □ Check Databricks Apps logs for ERROR lines first

6. ERROR HANDLING
   □ data.py raises DataAccessError on failure?
   □ ui.py catches exceptions and shows _error_figure()?

7. DESIGN SYSTEM
   □ Uses the shared dark or light theme tokens? → @ui-ux-patterns
   □ Plotly template follows the selected theme?
   □ No px.pie (use px.treemap), no #636efa (use #00bcd4)?

8. PIPELINE
   □ DLT tables named bronze_/silver_/gold_?  → @dlt-pipeline
   □ No spark.read() inside DLT notebooks?
   □ File paths use /Volumes/ not dbfs:/?
   □ New pipelines use serverless DLT?
```

---

## Example Apps

| App | Table | Permissions needed |
|-----|-------|-------------------|
| [NYC Taxi Explorer](apps/nyc_taxi_explorer/APP.md) | `samples.nyctaxi.trips` | None — works in every Unity Catalog workspace out of the box |
| [DBU Spend Monitor](apps/dbu_spend_app/APP.md) | `system.billing.usage` | Requires system tables enabled by an admin |

**Start with NYC Taxi Explorer** to verify the factory is wired up before building on your own data.

---

## Skill Reference

All skills are aligned with Databricks' official AI Dev Kit:
[github.com/databricks-solutions/ai-dev-kit](https://github.com/databricks-solutions/ai-dev-kit/tree/main/databricks-skills)

Key patterns enforced by this factory:
- **Apps data access:** `WorkspaceClient` + Statement Execution API, isolated in `data.py`
- **App startup:** no remote data calls at module import time
- **app.yaml resources:** `valueFrom: sql-warehouse` — never hardcode IDs
- **DLT:** serverless by default, `dlt.read()` not `spark.read()`
- **Grants:** SP `applicationId` UUID — never display name

---

## Contributing

1. Edit `GLOBAL_RULES.md`, `STACK.md`, or `modules/*.md` → run `python3 build_agents.py`
2. Edit skills in `skills/<name>/SKILL.md` → run `./deploy.sh` to push changes
3. Never edit `AGENTS.md` directly — it's generated
4. Add new apps under `apps/<app-name>/APP.md`

---

## License

[MIT](LICENSE) — use freely, adapt to your stack.

---

*AI generates code. Not architecture. — Marvin Nahmias, DAIS 2026*
