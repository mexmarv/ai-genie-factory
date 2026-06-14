---
name: data-access
description: >
  Data access patterns for Databricks Apps at Alpura. Load when writing or reviewing data.py,
  any spark.table() call, Unity Catalog table references, or data layer code. Also load when
  the user asks about reading tables, filtering data, or why a table isn't loading.
  Enforces three-part Unity Catalog naming, Gold-layer-only reads in UI apps,
  and the DataAccessError exception pattern.
---

# Data Access Patterns

Apply to every `data.py` file. The data layer does ONE thing: read and filter Spark DataFrames.

## Rules

- `spark.table()` is the only way to read data — no SQL, no JDBC, no pandas `read_csv`
- Always three-part Unity Catalog names: `catalog.schema.table`
- UI-facing apps read from Gold layer only — never Bronze or Silver
- All filtering happens here, before passing to logic layer
- No aggregations, groupBy, or business logic in this layer
- No imports from `logic.py` or `ui.py`

## Standard Pattern

```python
"""Data layer — spark.table() reads and filters only. No transformation logic."""
from pyspark.sql import functions as F
from _logger import get_logger
logger = get_logger(__name__)

class DataAccessError(Exception):
    pass

def load_table(catalog: str, schema: str, table: str):
    full_name = f"{catalog}.{schema}.{table}"
    try:
        logger.info(f"Loading: {full_name}")
        df = spark.table(full_name)
        logger.info(f"Loaded {df.count()} rows from {full_name}")
        return df
    except Exception as e:
        logger.error(f"Failed to load {full_name}: {e}")
        raise DataAccessError(f"Table unavailable: {full_name}") from e

def filter_by_date(df, date_col: str, start_date, end_date):
    return df.filter(
        (F.col(date_col) >= start_date) & (F.col(date_col) <= end_date)
    )
```

## Config Pattern

Table names live in `app.py` config dict — never hardcoded in `data.py`:

```python
# app.py
CONFIG = {
    "catalog": "prod",
    "schema":  "gold",
    "table":   "sales_daily",
}

# data.py receives config, not strings
def load_sales(config: dict):
    return load_table(config["catalog"], config["schema"], config["table"])
```

## Examples

```python
# Gold table
df = spark.table("prod.gold.sales_daily")

# System catalog (available in every workspace)
df = spark.table("system.billing.usage")

# Filter before passing to logic layer
df_filtered = spark.table("prod.gold.orders") \
    .filter("status = 'COMPLETED'") \
    .filter(F.col("order_date") >= "2024-01-01")
```

## Forbidden

- `spark.sql("SELECT ...")` in data layer — use `spark.table()` + `.filter()`
- Reading from `bronze_*` or `silver_*` tables in UI-facing apps
- Hardcoded catalog/schema/table strings — always from config dict
- Aggregations or business logic — those go in `logic.py`
