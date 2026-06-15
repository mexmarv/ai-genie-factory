---
name: testing-scaffold
description: >
  Unit test scaffolding for Databricks Apps at Alpura. Load when generating, reviewing,
  or adding tests to any app. Also load when the user asks about testing, test stubs,
  mocking sql connector calls, or why tests are failing. Enforces pytest, mocked
  dbsql.connect() calls, and pandas-based logic layer tests — never hitting Unity Catalog
  in unit tests.
---

# Testing Scaffold

Every generated app must include `tests/test_data.py` and `tests/test_logic.py`.
Tests must be present even if minimal — this enforces testability from day one.

## Rules

- Data layer tests mock `dbsql.connect()` — never hit Unity Catalog or the warehouse
- Logic layer tests use small hardcoded `pandas` DataFrames
- Always use `pytest` — no `unittest` directly
- Test function names: `test_<function>_<condition>`
- No Spark, no Databricks SDK calls in any test

---

## tests/test_data.py

```python
"""Tests for data.py — all dbsql.connect() calls are mocked."""
import pytest
import pandas as pd
from unittest.mock import patch, MagicMock
from data import DataAccessError, load_table


def _make_cursor(rows, cols):
    """Helper: return a mock cursor that yields given rows and column names."""
    cursor = MagicMock()
    cursor.fetchall.return_value = rows
    cursor.description = [(c,) for c in cols]
    cursor.__enter__ = lambda s: s
    cursor.__exit__ = MagicMock(return_value=False)
    return cursor


def _make_conn(cursor):
    conn = MagicMock()
    conn.cursor.return_value = cursor
    conn.__enter__ = lambda s: s
    conn.__exit__ = MagicMock(return_value=False)
    return conn


@patch("data.dbsql.connect")
@patch("data.Config")
def test_load_table_returns_dataframe(mock_config, mock_connect):
    mock_config.return_value.host = "adb-123.azuredatabricks.net"
    mock_config.return_value.authenticate = lambda: {}
    cursor = _make_cursor([(1, "Store A"), (2, "Store B")], ["store_nbr", "store_nm"])
    mock_connect.return_value = _make_conn(cursor)

    df = load_table("prod", "gold", "stores")
    assert isinstance(df, pd.DataFrame)
    assert list(df.columns) == ["store_nbr", "store_nm"]
    assert len(df) == 2


@patch("data.dbsql.connect")
@patch("data.Config")
def test_load_table_raises_data_access_error_on_failure(mock_config, mock_connect):
    mock_config.return_value.host = "adb-123.azuredatabricks.net"
    mock_connect.side_effect = Exception("Warehouse timeout")

    with pytest.raises(DataAccessError, match="Table unavailable"):
        load_table("prod", "gold", "stores")


@patch("data.dbsql.connect")
@patch("data.Config")
def test_load_table_applies_where_clause(mock_config, mock_connect):
    mock_config.return_value.host = "adb-123.azuredatabricks.net"
    mock_config.return_value.authenticate = lambda: {}
    cursor = _make_cursor([], ["store_nbr"])
    conn = _make_conn(cursor)
    mock_connect.return_value = conn

    load_table("prod", "gold", "stores", where="fin_close_dt IS NULL")
    # Verify the executed query contains the WHERE clause
    executed = cursor.execute.call_args[0][0]
    assert "fin_close_dt IS NULL" in executed


def test_filter_by_values_excludes_non_matching():
    from data import filter_by_values
    df = pd.DataFrame({"region": ["North", "South", "East"], "amount": [100, 200, 300]})
    result = filter_by_values(df, "region", ["North", "South"])
    assert len(result) == 2
    assert "East" not in result["region"].values


def test_filter_by_values_returns_all_when_empty():
    from data import filter_by_values
    df = pd.DataFrame({"region": ["North", "South"], "amount": [100, 200]})
    result = filter_by_values(df, "region", [])
    assert len(result) == 2
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
