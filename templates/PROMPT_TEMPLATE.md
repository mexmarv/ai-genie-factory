You are operating under the AI Genie Factory constraints loaded in your instructions file.
Apply constraints with this exact priority (highest = 1):

  1. GLOBAL_RULES              — never override
  2. STACK                     — never override
  3. ERROR_HANDLING            — never override
  4. LOGGING                   — never override
  5. @data-access               — WorkspaceClient Statement Execution; override only if
                                  APP spec requires a different data source type
  6. @ui-ux-patterns            — never override (chart library is always Plotly)
  7. @databricks-app            — app file layers, app.yaml, deployment
  8. @dlt-pipeline              — applies only if APP spec requests a pipeline
  9. @testing-scaffold          — never override
 10. APP SPEC below             — app-specific configuration only

Databricks Apps have no Spark session. Notebooks and DLT pipelines do — do not mix the two
runtimes' data-access patterns in the same file.

---

OUTPUT REQUIREMENTS

Produce exactly these files:

  _logger.py      — shared logger (copy from LOGGING module exactly)
  data.py         — data layer: WorkspaceClient Statement Execution reads ONLY
  logic.py        — logic layer: aggregations, transformations, business rules
  ui.py           — UI layer: Plotly figures ONLY — data.py already returns pandas
  app.py          — entry point: imports from data/logic/ui, no inline logic
  app.yaml        — command + resource-backed env vars (warehouse ID, table name)
  tests/
    test_data.py  — unit test stubs for data.py (WorkspaceClient mocked)
    test_logic.py — unit test stubs for logic.py

Each file must start with a module docstring identifying its layer:
  """Data layer — WorkspaceClient Statement Execution reads. No transformation logic."""

---

LAYER CONTRACTS

data.py:
  - ONLY WorkspaceClient().statement_execution reads, per @data-access
  - Returns pandas.DataFrame directly — no Spark, no .toPandas()
  - NO aggregations, groupBy, or business logic
  - NO imports from logic.py or ui.py
  - All table references must be three-part: catalog.schema.table, Gold schema only
  - Bind user-provided values as Statement Execution parameters — never string-interpolate SQL
  - Wrap every call in try/except → raise DataAccessError

logic.py:
  - ONLY aggregations, groupby, business rules — pandas operations on the DataFrame data.py returned
  - NO SQL, NO WorkspaceClient, NO Spark
  - NO Plotly imports or UI code
  - NO imports from ui.py
  - Wrap operations in try/except → raise LogicError

ui.py:
  - ONLY Plotly figure construction from the pandas DataFrame logic.py returned
  - NO pandas conversion here — data.py already returns pandas, there is nothing to convert
  - NO SQL, NO WorkspaceClient, NO Spark
  - NO business logic
  - Chart functions must be pure: accept pandas DataFrame, return plotly.Figure
  - Catch exceptions → return an error figure/component, never a raw traceback

app.py:
  - Entry point only
  - Imports: from data import ...; from logic import ...; from ui import ...
  - No inline logic, no direct WorkspaceClient calls, no direct Plotly calls
  - No remote call at module import time — config validated, data loaded from a callback
  - Config dict at top of file for catalog/schema/table/warehouse IDs (no hardcoded strings elsewhere)

---

FORBIDDEN (applies to all files)

  - Merging any two layers into one file
  - Any dependency not in STACK.md
  - spark, SparkSession, pyspark, or databricks-connect anywhere in a Databricks App
  - .toPandas() anywhere — Apps use pandas throughout; data.py returns it already
  - Redefining a KPI that exists in the semantic layer (read the Gold view instead)
  - Hardcoded catalog, schema, table, or warehouse IDs outside app.py config dict
  - print() statements (use logger)
  - Bare except: clauses (always catch Exception as e)
  - Reading from Bronze or Silver tables in UI-facing apps
  - A remote query running at module import time

---

APP SPEC

[PASTE APP.md CONTENT HERE — everything below this line is app-specific]
