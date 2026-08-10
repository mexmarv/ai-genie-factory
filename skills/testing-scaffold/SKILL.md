---
name: testing-scaffold
description: >
  Unit test scaffolding for Databricks Apps at Alpura. Load when generating, reviewing,
  or adding tests to any app. Also load when the user asks about testing, test stubs,
  mocking WorkspaceClient calls, or why tests are failing. Enforces pytest, mocked
  WorkspaceClient Statement Execution calls, and pandas-based logic layer tests — never
  hitting Unity Catalog in unit tests.
---

# Testing Scaffold

Every generated app must include `tests/test_data.py` and `tests/test_logic.py`.
Tests must be present even if minimal — this enforces testability from day one.

## Rules

- Data layer tests mock `data.WorkspaceClient` — never hit Unity Catalog or the warehouse
- Logic layer tests use small hardcoded `pandas` DataFrames
- Always use `pytest` — no `unittest` directly
- Test function names: `test_<function>_<condition>`
- No Spark, no live Databricks SDK calls in any test

---

## tests/test_data.py

```python
"""Tests for data.py — all WorkspaceClient calls are mocked."""
import pytest
import pandas as pd
from unittest.mock import patch, MagicMock
from data import DataAccessError, load_orders


def _make_result(rows, cols, state="SUCCEEDED", error_message=None):
    """Helper: build a mock Statement Execution result."""
    result = MagicMock()
    result.status.state.value = state
    result.status.error.message = error_message
    result.manifest.schema.columns = [MagicMock(name=c) for c in cols]
    for column, name in zip(result.manifest.schema.columns, cols):
        column.name = name
    result.result.data_array = rows
    return result


@patch("data.WorkspaceClient")
def test_load_orders_returns_dataframe(mock_client_cls):
    mock_client = mock_client_cls.return_value
    mock_client.statement_execution.execute_statement.return_value = _make_result(
        rows=[["2024-01-01", "North", "100.0", "1", "1"]],
        cols=["order_date", "region", "amount", "order_id", "customer_id"],
    )

    config = {"table_name": "prod.gold.orders", "warehouse_id": "wh-1", "row_limit": 1000}
    df = load_orders(config, "2024-01-01", "2024-01-31")
    assert isinstance(df, pd.DataFrame)
    assert list(df.columns) == ["order_date", "region", "amount", "order_id", "customer_id"]
    assert len(df) == 1


@patch("data.WorkspaceClient")
def test_load_orders_raises_data_access_error_on_failure(mock_client_cls):
    mock_client = mock_client_cls.return_value
    mock_client.statement_execution.execute_statement.side_effect = Exception("Warehouse timeout")

    config = {"table_name": "prod.gold.orders", "warehouse_id": "wh-1", "row_limit": 1000}
    with pytest.raises(DataAccessError, match="unavailable"):
        load_orders(config, "2024-01-01", "2024-01-31")


@patch("data.WorkspaceClient")
def test_load_orders_raises_on_non_gold_schema(mock_client_cls):
    config = {"table_name": "prod.silver.orders", "warehouse_id": "wh-1", "row_limit": 1000}
    with pytest.raises(DataAccessError, match="Gold"):
        load_orders(config, "2024-01-01", "2024-01-31")
    mock_client_cls.return_value.statement_execution.execute_statement.assert_not_called()
```

---

## tests/test_logic.py

```python
"""Tests for logic.py — uses pandas DataFrames, no Spark, no Databricks SDK."""
import pytest
import pandas as pd

SAMPLE = pd.DataFrame({
    "order_date": ["2024-01-01", "2024-01-01", "2024-01-02"],
    "region":     ["North", "South", "North"],
    "amount":     [100.0, 200.0, 150.0],
})


def test_aggregate_returns_dataframe():
    from logic import aggregate_by_day
    result = aggregate_by_day(SAMPLE)
    assert isinstance(result, pd.DataFrame)


def test_aggregate_returns_correct_row_count():
    from logic import aggregate_by_day
    result = aggregate_by_day(SAMPLE)
    assert len(result) == 2  # 2 unique dates


def test_aggregate_totals_correctly():
    from logic import aggregate_by_day
    result = aggregate_by_day(SAMPLE)
    assert result["total_amount"].sum() == pytest.approx(450.0)


def test_empty_dataframe_returns_empty():
    from logic import aggregate_by_day
    empty = pd.DataFrame(columns=SAMPLE.columns)
    result = aggregate_by_day(empty)
    assert len(result) == 0
```

---

## Running Tests

```bash
# From app root
pip install pytest --break-system-packages
pytest tests/ -v

# With coverage
pip install pytest-cov --break-system-packages
pytest tests/ --cov=. --cov-report=term-missing
```
