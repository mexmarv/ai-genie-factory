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
- `data.py` reads only — `spark.table()`, no SQL, no JDBC, no pandas reads
- `logic.py` transforms only — pandas DataFrames, no Spark, no UI imports
- `ui.py` renders only — Plotly figures, Dash/Streamlit components, no Spark
- `app.py` orchestrates — wires layers, defines layout and callbacks
- `_logger.py` is the only logging import — never use `print()` or raw `logging`
- All table names come from the `CONFIG` dict in `app.py` — never hardcoded in `data.py`
- OAuth token passthrough is the default auth — never hardcode credentials
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
"""Data layer — spark.table() reads and filters only. No transformations."""
from pyspark.sql import functions as F
from _logger import get_logger
logger = get_logger(__name__)

class DataAccessError(Exception):
    pass

def load_table(catalog: str, schema: str, table: str):
    full_name = f"{catalog}.{schema}.{table}"
    try:
        logger.info(f"Loading {full_name}")
        df = spark.table(full_name)
        logger.info(f"Loaded {df.count()} rows from {full_name}")
        return df
    except Exception as e:
        logger.error(f"Failed to load {full_name}: {e}")
        raise DataAccessError(f"Table unavailable: {full_name}") from e

def filter_by_date(df, col: str, start, end):
    return df.filter((F.col(col) >= start) & (F.col(col) <= end))

def filter_by_values(df, col: str, values: list):
    if not values or values == ["All"]:
        return df
    return df.filter(F.col(col).isin(values))
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
databricks-sdk>=0.30.0

# Streamlit alternative
# streamlit==1.41.0

# Utilities
python-dateutil>=2.9.0
numpy>=1.26.0
```

Pin major versions. Never use `>=` for `dash` or `streamlit` — breaking changes between minors.

---

## OAuth Token Passthrough

Databricks Apps automatically injects the end-user's OAuth token. Use it to call Databricks APIs:

```python
# app.py — use the injected token, never hardcode credentials
import os
from databricks.sdk import WorkspaceClient

def get_workspace_client() -> WorkspaceClient:
    return WorkspaceClient(
        host=os.environ["DATABRICKS_HOST"],
        token=os.environ.get("DATABRICKS_TOKEN"),  # injected at runtime
    )
```

For `spark.table()` reads, token passthrough is automatic — Databricks Apps runs under the
service principal assigned to the app. No additional auth code needed for Unity Catalog reads.

---

## CONFIG Pattern — app.py

```python
# app.py — all table references live here, never in data.py
CONFIG = {
    "catalog":  "prod",
    "schema":   "gold",
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

2. SPARK TABLE NOT FOUND
   □ Three-part name correct? catalog.schema.table
   □ Service principal has SELECT on that table?
   □ Table exists: SHOW TABLES IN prod.gold
   □ DataAccessError in logs?

3. BLANK / BROKEN UI
   □ Callback returning correct types? (list for flex row, go.Figure for graph)
   □ _error_figure() showing? Means chart function failed — check logs for traceback
   □ CSS not loading? Check app.index_string has {%css%} in <head>

4. SLOW / TIMING OUT
   □ df.count() in load_table() — remove for large tables, use df.limit(1).count() to verify
   □ toPandas() on unfiltered Spark DF — always filter before converting
   □ Use Serverless compute for the app's SQL warehouse

5. AUTH / PERMISSION ERROR
   □ DATABRICKS_HOST set? Check os.environ in app startup log
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
- `spark.sql("SELECT ...")` in data layer — use `spark.table()` + `.filter()`
- `df.toPandas()` in `data.py` or `logic.py` — only in `ui.py`
- Hardcoded catalog/schema/table strings outside `CONFIG`
- `pd.read_csv()`, JDBC, or REST calls in `data.py`
- Business logic in `ui.py` — aggregations go in `logic.py`
- `debug=True` in production `app.run()`
- Credentials, tokens, or passwords in any source file
- Reading `bronze_*` or `silver_*` tables in UI-facing apps
