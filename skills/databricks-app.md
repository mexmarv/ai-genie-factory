---
name: databricks-app
description: >
  Full Databricks Apps architecture for Alpura — Dash and Streamlit apps deployed on
  Databricks App Service. Load when building, reviewing, or deploying any Databricks App:
  file structure, app.yaml, requirements.txt, service principal auth, environment config,
  data/logic/ui/app layer architecture, OAuth token passthrough, deployment commands,
  debug patterns, and live reload. Also load when the user asks about app.yaml, permissions,
  service principals, why the app won't start, or how to deploy. Always pair with
  @ui-ux-patterns for all visual components and chart functions.
---

# Databricks App Architecture — Alpura

Apply to every Databricks App (Dash or Streamlit) built at Alpura.

> Always load **@ui-ux-patterns** alongside this skill for design tokens, KPI cards,
> chart functions, and full shell patterns. This skill covers architecture, deployment,
> auth, and the non-visual layer contracts.

---

## Rules

- Every app follows the 5-file layer architecture: `data.py / logic.py / ui.py / app.py / _logger.py`
- `data.py` reads only — `WorkspaceClient` + Statement Execution API; **NO `spark` session in Apps runtime**
- `logic.py` transforms only — pandas DataFrames, no Spark, no UI imports
- `ui.py` renders only — Plotly figures, Dash/Streamlit components
- `app.py` orchestrates — wires layers, defines layout and callbacks
- `_logger.py` is the only logging import — never use `print()` or raw `logging`
- All table names and `warehouse_id` come from the `CONFIG` dict in `app.py` — never hardcoded in `data.py`
- `WorkspaceClient()` with no arguments is the auth pattern — it auto-configures from the App runtime environment
- Always include `requirements.txt` and `app.yaml`

---

## Standard File Structure

```
my-app/
├── app.py              ← Orchestrator: layout, callbacks, CONFIG dict
├── data.py             ← Data layer: spark.table() reads and filters only
├── logic.py            ← Logic layer: pandas transforms, aggregations, KPI math
├── ui.py               ← UI layer: Plotly figures, Dash/Streamlit components
├── _logger.py          ← Structured logger (copy from template)
├── app.yaml            ← Databricks App deployment manifest
├── requirements.txt    ← Python dependencies
└── APP.md              ← App spec (purpose, tables, filters, tiles)
```

---

## Layer Contracts

### data.py

```python
"""Data layer — databricks-sdk Statement Execution API reads only. No Spark (not available in Apps runtime)."""
import pandas as pd
from databricks.sdk import WorkspaceClient
from _logger import get_logger

logger = get_logger(__name__)


class DataAccessError(Exception):
    pass


def _execute_sql(sql: str, warehouse_id: str) -> pd.DataFrame:
    """Run SQL via Statement Execution API; return a pandas DataFrame."""
    w = WorkspaceClient()  # auto-configures from App runtime environment; no credentials needed
    result = w.statement_execution.execute_statement(
        warehouse_id=warehouse_id,
        statement=sql,
        wait_timeout="30s",
    )
    if result.status.state.value != "SUCCEEDED":
        raise DataAccessError(f"Query failed: {result.status.error.message}")
    cols = [c.name for c in result.manifest.schema.columns]
    return pd.DataFrame(result.result.data_array or [], columns=cols)


def load_table(catalog: str, schema: str, table: str, warehouse_id: str) -> pd.DataFrame:
    full_name = f"{catalog}.{schema}.{table}"
    try:
        logger.info(f"Loading {full_name}")
        df = _execute_sql(f"SELECT * FROM {full_name}", warehouse_id)
        logger.info(f"Loaded {len(df)} rows from {full_name}")
        return df
    except DataAccessError:
        raise
    except Exception as e:
        logger.error(f"Failed to load {full_name}: {e}")
        raise DataAccessError(f"Table unavailable: {full_name}") from e


def filter_by_date(df: pd.DataFrame, col: str, start, end) -> pd.DataFrame:
    return df[(df[col] >= start) & (df[col] <= end)]


def filter_by_values(df: pd.DataFrame, col: str, values: list) -> pd.DataFrame:
    if not values or values == ["All"]:
        return df
    return df[df[col].isin(values)]
```

### logic.py

```python
"""Logic layer — pandas transforms only. No Spark, no UI imports."""
import pandas as pd
import numpy as np
from _logger import get_logger
logger = get_logger(__name__)

def compute_kpis(df: pd.DataFrame, start_date: str, end_date: str) -> dict:
    """Return flat dict of scalar KPI values for the period."""
    mask = (df["order_date"] >= start_date) & (df["order_date"] <= end_date)
    filtered = df[mask]
    prior_mask = (df["order_date"] >= _prior_start(start_date, end_date)) & \
                 (df["order_date"] < start_date)
    prior = df[prior_mask]
    return {
        "revenue":        filtered["amount"].sum(),
        "revenue_prior":  prior["amount"].sum(),
        "orders":         len(filtered),
        "orders_prior":   len(prior),
        "avg_order":      filtered["amount"].mean() if len(filtered) else 0,
    }

def compute_trend(df: pd.DataFrame, start_date: str, end_date: str) -> pd.DataFrame:
    """Return daily totals for the period."""
    mask = (df["order_date"] >= start_date) & (df["order_date"] <= end_date)
    return (df[mask]
            .groupby("order_date", as_index=False)["amount"]
            .sum()
            .rename(columns={"amount": "total_revenue"})
            .sort_values("order_date"))

def compute_by_category(df: pd.DataFrame, col: str, start_date: str, end_date: str) -> pd.DataFrame:
    """Return totals grouped by any category column."""
    mask = (df["order_date"] >= start_date) & (df["order_date"] <= end_date)
    return (df[mask]
            .groupby(col, as_index=False)["amount"]
            .sum()
            .rename(columns={"amount": "total_revenue"})
            .sort_values("total_revenue", ascending=False))

def _prior_start(start_date: str, end_date: str) -> str:
    from datetime import datetime, timedelta
    delta = datetime.fromisoformat(end_date) - datetime.fromisoformat(start_date)
    return (datetime.fromisoformat(start_date) - delta - timedelta(days=1)).date().isoformat()
```

### _logger.py

```python
"""Structured logger — copy this file into every app unchanged."""
import logging
import sys

def get_logger(name: str) -> logging.Logger:
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(logging.Formatter(
            "%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        ))
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
    return logger
```

---

## app.yaml — Deployment Manifest

```yaml
# app.yaml — Databricks App deployment manifest
command: ["python", "app.py"]       # Dash
# command: ["streamlit", "run", "app.py", "--server.port=8050"]  # Streamlit

env:
  - name: DATABRICKS_HOST
    valueFrom: "databricks"         # injected by Databricks Apps runtime
  - name: DATABRICKS_WAREHOUSE_ID
    value: "your-sql-warehouse-id"  # replace with your Serverless or Pro warehouse ID
  - name: APP_ENV
    value: "production"

resources:
  requests:
    cpu: "0.5"
    memory: "1Gi"
  limits:
    cpu: "2"
    memory: "4Gi"
```

---

## requirements.txt

```
# Core
dash==2.18.1
plotly==5.24.1
pandas==2.2.3
databricks-sdk>=0.30.0   # WorkspaceClient + Statement Execution API — primary data access

# Streamlit alternative
# streamlit==1.41.0

# Utilities
python-dateutil>=2.9.0
numpy>=1.26.0
```

**Do NOT add** `pyspark` or `databricks-connect` — no Spark session is available in Apps runtime.

Pin major versions. Never use `>=` for `dash` or `streamlit` — breaking changes between minors.

---

## Auth in Databricks Apps

`WorkspaceClient()` with **no arguments** is the correct pattern. It reads `DATABRICKS_HOST` from the injected environment and authenticates via the App's service principal.

**CRITICAL: Never call `WorkspaceClient()` at module level.** The SDK performs auth/metadata resolution on first use which can block the App's health check and crash the app. Always call it inside a function or callback.

```python
# data.py — correct: WorkspaceClient() inside a function, never at module level
from databricks.sdk import WorkspaceClient

def _execute_sql(sql: str, warehouse_id: str) -> pd.DataFrame:
    w = WorkspaceClient()  # called inside function — safe
    result = w.statement_execution.execute_statement(...)
    ...
```

**Do NOT do:**
```python
# Wrong — blocks health check, crashes app
w = WorkspaceClient()  # module-level: SDK hangs resolving auth metadata

# Wrong — DATABRICKS_TOKEN may not be set in App runtime
WorkspaceClient(host=os.environ["DATABRICKS_HOST"], token=os.environ.get("DATABRICKS_TOKEN"))
```

**Startup data loading:** Initialize globals as empty DataFrames at module level. Use `dcc.Interval(max_intervals=1)` to trigger a UC load 3 seconds after first page load (after the health check has already passed). Show a loading banner while data is pending; update it to a success/error state in the callback.

```python
# app.py — correct startup pattern
# Empty at startup — UC data loads via callback after health check passes.
stores_df = pd.DataFrame()
items_df = pd.DataFrame()
store_options = []

# In layout:
dcc.Interval(id='uc-reload-interval', interval=3000, max_intervals=1, n_intervals=0),
html.Div(id='data-loading-banner', children=[html.Span("Cargando desde Databricks…")])
dcc.Dropdown(id='store-dropdown', options=[], placeholder="Esperando datos...", disabled=True)

# Callback that fires once, loads from UC, updates globals + dropdown + banner:
@app.callback(
    [Output('store-dropdown', 'options'),
     Output('store-dropdown', 'disabled'),
     Output('data-loading-banner', 'children')],
    [Input('uc-reload-interval', 'n_intervals')],
    prevent_initial_call=True
)
def reload_from_uc(n_intervals):
    global stores_df, items_df, store_options
    try:
        stores_df = _execute_sql(f"SELECT ... FROM {TABLE_STORES}", warehouse_id)
        items_df  = _execute_sql(f"SELECT ... FROM {TABLE_ITEMS}", warehouse_id)
        store_options = [{'label': ..., 'value': ...} for _, row in stores_df.iterrows()]
        return store_options, False, html.Span(f"✓ {len(stores_df)} tiendas — datos en vivo")
    except Exception as e:
        return [], True, html.Span(f"✗ Error: {e}")
```

---

## CONFIG Pattern — app.py

```python
# app.py — all table references and warehouse_id live here, never in data.py
import os

CONFIG = {
    "catalog":      "prod",
    "schema":       "gold",
    "warehouse_id": os.environ.get("DATABRICKS_WAREHOUSE_ID", ""),  # set in app.yaml env
    "tables": {
        "sales":     "sales_daily",
        "products":  "products",
        "customers": "customers_dim",
    },
    "defaults": {
        "lookback_days": 30,
        "top_n":         10,
    }
}
```

---

## APP.md Spec Template

Every app must have an `APP.md` before any code is written:

```markdown
# App: [Name]

## Purpose
One sentence — what decision or workflow does this app support?

## Audience
[Team / role — e.g. "Finance team, read-only"]

## Data Sources
| Layer | Table | Grain | Refresh |
|---|---|---|---|
| Gold | prod.gold.sales_daily | day × region × sku | hourly DLT |

## Filters
| Filter | Type | Default | Parameter |
|---|---|---|---|
| Date range | Date picker | last 30 days | start_date, end_date |
| Region | Dropdown | All | region |

## KPIs (Counter row)
| Label | Source field | Format | Comparison |
|---|---|---|---|
| Total Revenue | SUM(amount) | $M | vs prior period |
| Orders | COUNT(order_id) | K | vs prior period |

## Charts
| Title | Type | X | Y | Notes |
|---|---|---|---|---|
| Revenue Trend | Line area | order_date | total_revenue | 7d MA overlay |
| By Region | Horizontal bar | total_revenue | region | sorted desc |

## Framework
[ ] Dash  [ ] Streamlit
```

---

## Deployment Commands

```bash
# Install Databricks CLI if needed
pip install databricks-cli

# Authenticate
databricks configure --token

# Create the app (first time)
databricks apps create my-app-name

# Deploy / update
databricks apps deploy my-app-name --source-code-path ./my-app

# View logs (live tail)
databricks apps logs my-app-name --follow

# List all apps
databricks apps list

# Get app URL
databricks apps get my-app-name
```

---

## Debug Checklist

```
1. APP WON'T START
   □ Check app.yaml command matches framework (dash vs streamlit)
   □ Check requirements.txt — all packages installable?
   □ databricks apps logs my-app-name — look for ImportError or SyntaxError

2. TABLE NOT FOUND / QUERY FAILED
   □ Three-part name correct? catalog.schema.table
   □ DATABRICKS_WAREHOUSE_ID set in app.yaml? WorkspaceClient needs a warehouse
   □ Service principal has SELECT on that table?
   □ Table exists: run SHOW TABLES IN prod.gold in a notebook
   □ DataAccessError in logs? Check result.status.error.message
   □ Do NOT use spark.table() — it will raise NameError in Apps runtime

3. BLANK / BROKEN UI
   □ Callback returning correct types? (list for flex row, go.Figure for graph)
   □ _error_figure() showing? Means chart function failed — check logs for traceback
   □ CSS not loading? Check app.index_string has {%css%} in <head>

4. SLOW / TIMING OUT
   □ SELECT * on large tables — add WHERE clause or LIMIT in the SQL string before calling execute_statement
   □ Cold warehouse start — Serverless warehouses start faster than Classic; prefer Serverless
   □ wait_timeout="30s" — increase to "50s" for slow warehouses; max is "50s"

5. AUTH / PERMISSION ERROR
   □ Use WorkspaceClient() with NO arguments — it auto-configures in Apps runtime
   □ Do NOT pass token= to WorkspaceClient — DATABRICKS_TOKEN is not guaranteed in Apps
   □ DATABRICKS_HOST injected? It comes from valueFrom: "databricks" in app.yaml
   □ Service principal assigned to app in Databricks Apps settings?
   □ SP has USE CATALOG, USE SCHEMA, SELECT on required tables?
```

---

## Service Principal Permissions (One-time Setup)

```sql
-- Run as workspace admin or catalog owner
-- Grant SP access to the Gold catalog
GRANT USE CATALOG ON CATALOG prod TO `sp-my-app`;
GRANT USE SCHEMA  ON SCHEMA  prod.gold TO `sp-my-app`;
GRANT SELECT      ON TABLE   prod.gold.sales_daily TO `sp-my-app`;

-- Or grant to the app's service principal group
GRANT SELECT ON SCHEMA prod.gold TO `group:alpura-app-readers`;
```

---

## Forbidden

- `print()` — always `logger.info/error`
- `spark.table()` or `spark.sql()` in Databricks Apps — there is **no Spark session**; use `WorkspaceClient`
- `pyspark` or `databricks-connect` in `requirements.txt` for Apps
- `WorkspaceClient(token=...)` — do not pass a token; use `WorkspaceClient()` with no args
- `WorkspaceClient()` at module level — always inside a function or callback; module-level blocks the health check
- `geopandas`, `shapely`, or any package requiring native C libs (GDAL, etc.) — not available in Apps runtime
- Hardcoded catalog/schema/table strings or `warehouse_id` outside `CONFIG`
- `pd.read_csv()`, JDBC, or raw REST calls in `data.py`
- Business logic in `ui.py` — aggregations go in `logic.py`
- `debug=True` in production `app.run()`
- Credentials, tokens, or passwords in any source file
- Reading `bronze_*` or `silver_*` tables in UI-facing apps
