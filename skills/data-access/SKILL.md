---
name: data-access
description: >
  Governed data access patterns for Databricks workloads at Alpura. Load when writing or
  reviewing data.py, SQL, Unity Catalog references, table reads, filters, or query failures.
  Enforces three-part names, Gold-only reads for UI apps, WorkspaceClient Statement Execution
  in Databricks Apps, spark.table() in notebooks and Lakeflow pipelines, parameter binding,
  structured logging, and DataAccessError boundaries.
---

# Governed Data Access

Apply this skill whenever code reads Databricks data. `AGENTS.md` and workspace instructions
have higher priority than examples in this skill.

## Runtime decision

| Runtime | Required API | Forbidden |
|---|---|---|
| Databricks Apps | `databricks.sdk.WorkspaceClient` + Statement Execution API | Spark sessions, JDBC, SQL in UI/logic modules |
| Notebook | `spark.table("catalog.schema.table")` | Two-part or unqualified names |
| Lakeflow/DLT pipeline | `spark.table("catalog.schema.table")` and declarative pipeline APIs | UI-facing reads from Bronze/Silver |

## Non-negotiable rules

- UI-facing apps read Gold Unity Catalog tables only.
- Every table reference is `catalog.schema.table` and comes from configuration.
- SQL exists only in `data.py`; logic and UI modules never contain SQL.
- Never concatenate user-provided values into SQL. Bind Statement Execution parameters.
- Validate catalog, schema, table, and column identifiers against configuration allowlists.
- Catch `Exception as e`, log it, and raise `DataAccessError` with a safe message.
- Preserve Unity Catalog authorization. Never elevate or bypass the app identity.
- Do not fetch an unbounded table for client-side filtering. Push filters and limits to SQL.

## Databricks Apps standard pattern

```python
"""Data layer — governed SQL reads only; no business transformations."""
import re
from typing import Any

import pandas as pd
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.sql import StatementParameterListItem

from _logger import get_logger

logger = get_logger(__name__)


class DataAccessError(Exception):
    pass


class LogicError(Exception):
    pass


_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def _identifier(value: str, allowed: set[str] | None = None) -> str:
    if not _IDENTIFIER.fullmatch(value) or (allowed is not None and value not in allowed):
        raise DataAccessError("Invalid configured identifier")
    return value


def _full_name(config: dict[str, Any]) -> str:
    parts = config["table_name"].split(".")
    if len(parts) != 3:
        raise DataAccessError("A three-part table name is required")
    catalog, schema, table = (_identifier(part) for part in parts)
    if schema.lower() != "gold":
        raise DataAccessError("UI applications may read only from the Gold schema")
    return f"{catalog}.{schema}.{table}"


def _execute(
    warehouse_id: str,
    statement: str,
    parameters: list[StatementParameterListItem] | None = None,
) -> pd.DataFrame:
    try:
        client = WorkspaceClient()
        result = client.statement_execution.execute_statement(
            warehouse_id=warehouse_id,
            statement=statement,
            parameters=parameters,
            wait_timeout="30s",
        )
        state = result.status.state.value
        if state != "SUCCEEDED":
            message = result.status.error.message if result.status.error else state
            raise DataAccessError(f"Query failed: {message}")

        columns = [column.name for column in result.manifest.schema.columns]
        rows = result.result.data_array or []
        frame = pd.DataFrame(rows, columns=columns)
        logger.info(f"Statement returned {len(frame)} rows")
        return frame
    except DataAccessError:
        raise
    except Exception as e:
        logger.error(f"Data access failed: {e}")
        raise DataAccessError("The requested data is unavailable") from e


def load_orders(config: dict[str, Any], start_date: str, end_date: str) -> pd.DataFrame:
    full_name = _full_name(config)
    warehouse_id = config["warehouse_id"]
    statement = f"""
        SELECT order_date, region, amount, order_id, customer_id
        FROM {full_name}
        WHERE order_date BETWEEN :start_date AND :end_date
        ORDER BY order_date
        LIMIT :row_limit
    """
    parameters = [
        StatementParameterListItem(name="start_date", value=start_date, type="DATE"),
        StatementParameterListItem(name="end_date", value=end_date, type="DATE"),
        StatementParameterListItem(name="row_limit", value=str(config["row_limit"]), type="INT"),
    ]
    logger.info(f"Loading: {full_name}")
    try:
        frame = _execute(warehouse_id, statement, parameters)
        logger.info(f"Loaded {len(frame)} rows from {full_name}")
        return frame
    except Exception as e:
        logger.error(f"Failed to load {full_name}: {e}")
        if isinstance(e, DataAccessError):
            raise
        raise DataAccessError(f"Table unavailable: {full_name}") from e
```

## Notebook pattern

```python
from _logger import get_logger

logger = get_logger(__name__)


class DataAccessError(Exception):
    pass


try:
    table_name = "prod.gold.sales_daily"  # supplied by validated notebook configuration
    logger.info(f"Loading: {table_name}")
    df = spark.table(table_name)
    logger.info(f"Loaded table: {table_name} ({df.count()} rows)")
except Exception as e:
    logger.error(f"Failed to load {table_name}: {e}")
    raise DataAccessError(f"Table unavailable: {table_name}") from e
```

## Layer boundary

- `data.py`: identifiers, SQL, parameters, execution, access-boundary type normalization.
- `logic.py`: aggregations, KPI application, joins already approved for the app.
- `ui.py`: pandas-to-visual conversion and formatting only.
- `app.py`: configuration and orchestration; no SQL.

## Review checklist

- [ ] Gold-only table for UI-facing workloads.
- [ ] Three-part name assembled from validated configuration.
- [ ] Statement Execution used in Apps; `spark.table()` used in notebooks/pipelines.
- [ ] User values are bound parameters.
- [ ] Query has bounded date predicates and/or a configured limit.
- [ ] Exceptions are logged and converted to `DataAccessError`.
- [ ] No SQL appears outside `data.py`.
- [ ] No service principal is used to bypass the viewer/app identity's UC permissions.

## Forbidden

- `spark` or `SparkSession` in Databricks Apps.
- SQL strings in `logic.py`, `ui.py`, callbacks, or notebooks that back UI components directly.
- Bronze or Silver reads from UI-facing apps.
- `SELECT *` in production UI queries.
- Unvalidated dynamic identifiers.
- String interpolation of filter values.
- Raw tracebacks or warehouse error details shown to end users.
