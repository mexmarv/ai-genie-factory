You are operating under the AI Genie Factory constraints loaded in your instructions file.
Apply constraints with this exact priority (highest = 1):

  1. GLOBAL_RULES     — never override
  2. STACK            — never override
  3. ERROR_HANDLING   — never override
  4. LOGGING          — never override
  5. DATA_ACCESS      — override only if APP spec requires a different data source type
  6. UI_PATTERNS      — never override (chart library is always Plotly)
  7. DLT_PIPELINES    — applies only if APP spec requests a pipeline
  8. TESTING          — never override
  9. APP SPEC below   — app-specific configuration only

---

OUTPUT REQUIREMENTS

Produce exactly these files:

  _logger.py      — shared logger (copy from LOGGING module exactly)
  data.py         — data layer: spark.table() reads and filters ONLY
  logic.py        — logic layer: aggregations, transformations, business rules
  ui.py           — UI layer: Plotly figures and pandas conversion ONLY
  app.py          — entry point: imports from data/logic/ui, no inline logic
  tests/
    test_data.py  — unit test stubs for data.py
    test_logic.py — unit test stubs for logic.py

Each file must start with a module docstring identifying its layer:
  """Data layer — spark.table() reads and filters. No transformation logic."""

---

LAYER CONTRACTS

data.py:
  - ONLY spark.table() reads and .filter() calls
  - NO aggregations, groupBy, or business logic
  - NO imports from logic.py or ui.py
  - All table references must be three-part: catalog.schema.table
  - Wrap every spark.table() call in try/except → raise DataAccessError

logic.py:
  - ONLY aggregations, groupBy, .agg(), business rules
  - NO spark.table() calls (receives DataFrames from data.py)
  - NO Plotly imports or UI code
  - NO imports from ui.py
  - Wrap operations in try/except → raise LogicError

ui.py:
  - ONLY Plotly figure construction
  - Pandas conversion happens HERE (df.toPandas()) — never in data.py or logic.py
  - NO spark calls
  - NO business logic
  - Chart functions must be pure: accept pandas DataFrame, return plotly.Figure
  - Catch exceptions → display with st.error() or equivalent

app.py:
  - Entry point only
  - Imports: from data import ...; from logic import ...; from ui import ...
  - No inline logic, no direct spark calls, no direct Plotly calls
  - Config dict at top of file for catalog/schema/table names (no hardcoded strings elsewhere)

---

FORBIDDEN (applies to all files)

  - Merging any two layers into one file
  - Any dependency not in STACK.md
  - Redefining a KPI that exists in the semantic layer (read the Gold view instead)
  - Hardcoded catalog, schema, or table names outside app.py config dict
  - print() statements (use logger)
  - Bare except: clauses (always catch Exception as e)
  - Reading from Bronze or Silver tables in UI-facing apps

---

APP SPEC

[PASTE APP.md CONTENT HERE — everything below this line is app-specific]
