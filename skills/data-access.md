---
name: data-access
description: >
  Data access patterns for Databricks Apps at Alpura. Load when writing or reviewing data.py,
  any SQL query, Unity Catalog table references, or data layer code. Also load when
  the user asks about reading tables, filtering data, or why a table isn't loading.
  Enforces three-part Unity Catalog naming, sql-connector + Config() auth for Apps,
  Gold-layer-only reads in UI apps, and the DataAccessError exception pattern.
---

# Data Access Patterns

Apply to every `data.py` file. The data layer does ONE thing: query UC tables and return pandas DataFrames.

> **No Spark in Databricks Apps.** Apps run in a container with no Spark session. Use
> `databricks-sql-connector` + `Config()` for all SQL queries. See `@databricks-app` for
> the full startup and auth patterns.

---

## Rules

- `databricks-sql-connector` + `Config()` is the only way to read data — no `spark.table()`, no JDBC
- Always three-part Unity Catalog names: `catalog.schema.table`
- UI-facing apps read from Gold layer only — never Bronze or Silver
- All filtering happens here, before passing to logic layer — SQL WHERE clauses preferred
- No aggregations, groupBy, or business logic in this layer
- No imports from `logic.py` or `ui.py`
- Batch multiple queries through a single `dbsql.connect()` — never one connection per query

---

## Standard Pattern

```python
"""Data layer — sql-connector queries and filters only. No transformation logic."""
import os
import pandas as pd
from databricks.sdk.core import Config
from databricks import sql as dbsql
from _logger import get_logger

logger = get_logger(__name__)

# Full HTTP path injected by app.yaml: value: /sql/1.0/warehouses/your-id
# Do NOT use DATABRICKS_WAREHOUSE_ID — that env var is never set by the App runtime.
HTTP_PATH = os.environ.get("DATABRICKS_HTTP_PATH", "")


class DataAccessError(Exception):
    pass


def _execute_sql(query: str) -> pd.DataFrame:
    """Query UC via sql-connector + Config() SP credentials.
    Returns pandas DataFrame with correct Python types (int, float, str)."""
    cfg = Config()  # auto-detects DATABRICKS_CLIENT_ID / SECRET injected by App runtime
    with dbsql.connect(
        server_hostname=cfg.host,
        http_path=HTTP_PATH,          # full path from env — NOT f"/sql/1.0/warehouses/{id}"
        credentials_provider=lambda: cfg.authenticate,
    ) as conn:
        with conn.cursor() as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()
            cols = [d[0] for d in cursor.description]
    return pd.DataFrame(rows, columns=cols)


def load_table(catalog: str, schema: str, table: str, where: str = "") -> pd.DataFrame:
    full_name = f"{catalog}.{schema}.{table}"
    sql = f"SELECT * FROM {full_name}"
    if where:
        sql += f" WHERE {where}"
    try:
        logger.info(f"Loading {full_name}")
        df = _execute_sql(sql)
        logger.info(f"Loaded {len(df)} rows from {full_name}")
        return df
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

---

## Batching Multiple Queries (Performance)

Open **one connection** and run all queries through it. Each `dbsql.connect()` call creates
a new HTTP session to the warehouse — this is slow (1–3 s overhead per call).

```python
def _batch_queries(queries: dict) -> dict:
    """Run multiple SQL queries in a single connection. Returns {key: DataFrame}."""
    cfg = Config()
    results = {}
    with dbsql.connect(
        server_hostname=cfg.host,
        http_path=HTTP_PATH,
        credentials_provider=lambda: cfg.authenticate,
    ) as conn:
        for key, query in queries.items():
            with conn.cursor() as cursor:
                cursor.execute(query)
                rows = cursor.fetchall()
                cols = [d[0] for d in cursor.description]
            results[key] = pd.DataFrame(rows, columns=cols)
            logger.info(f"[{key}] returned {len(results[key])} rows")
    return results

# Usage:
data = _batch_queries({
    'stores': "SELECT * FROM prod.gold.stores WHERE active = TRUE",
    'items':  "SELECT * FROM prod.gold.items  WHERE status = 'A'",
})
stores_df = data['stores']
items_df  = data['items']
```

---

## Decimal / Numeric Type Safety

sql-connector returns `DECIMAL` schema columns as Python `decimal.Decimal` objects.
Plotly mapbox and most numeric operations expect Python `float`.
**Always cast numeric columns explicitly in SQL** or coerce after loading:

```python
# Preferred: CAST in SQL (cleanest)
"SELECT CAST(lat_dgr AS DOUBLE) AS lat_dgr, CAST(long_dgr AS DOUBLE) AS long_dgr ..."

# Fallback: coerce after load
df['lat_dgr'] = pd.to_numeric(df['lat_dgr'], errors='coerce')
```

---

## Config Pattern

Table names and HTTP path live in `app.py` — never hardcoded in `data.py`:

```python
# app.py
import os
HTTP_PATH = os.environ.get("DATABRICKS_HTTP_PATH", "")  # full path from app.yaml
CATALOG  = "prod"
SCHEMA   = "gold"
TABLES = {
    "sales":    f"{CATALOG}.{SCHEMA}.sales_daily",
    "products": f"{CATALOG}.{SCHEMA}.products",
}

# data.py receives config, not strings
def load_sales(catalog: str, schema: str, table: str) -> pd.DataFrame:
    return load_table(catalog, schema, table, where="order_date >= current_date() - 30")
```

---

## Active Records Filters (Alpura Standards)

```python
# Active stores — both financial and operational close dates must be NULL
WHERE fin_close_dt IS NULL AND op_close_dt IS NULL

# Active items — use exact case 'A' (confirmed in Scintilla silver tables)
WHERE item_status_cd = 'A'

# Active with geo coordinates (for maps)
WHERE lat_dgr IS NOT NULL AND long_dgr IS NOT NULL
  AND fin_close_dt IS NULL AND op_close_dt IS NULL
```

---

## Service Principal Permissions (One-time Setup)

The App's SP `applicationId` UUID comes from `databricks apps get <name>` →
`service_principal_client_id`.

```sql
-- Run as catalog owner or workspace admin — use UUID, NOT display name
GRANT USE CATALOG ON CATALOG my_catalog TO `<sp-uuid>`;
GRANT USE SCHEMA  ON SCHEMA  my_catalog.my_schema TO `<sp-uuid>`;
GRANT SELECT      ON TABLE   my_catalog.my_schema.my_table TO `<sp-uuid>`;
```

---

## Forbidden

- `spark.table()` or `spark.sql()` — no Spark session in Apps runtime
- `WorkspaceClient().statement_execution` for SQL queries — returns ALL values as strings
  (breaks lat/lon, costs, quantities); use sql-connector instead
- `Config()` or `dbsql.connect()` at module level — always inside a function/callback
- One `dbsql.connect()` per query — batch all queries in a single connection
- `bronze_*` or `silver_*` tables in UI-facing apps — use Gold layer only
- Hardcoded catalog/schema/table strings in `data.py` — always from config dict
- Aggregations or business logic — those go in `logic.py`
