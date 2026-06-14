---
name: testing-scaffold
description: >
  Unit test scaffolding for Databricks Apps at Alpura. Load when generating, reviewing,
  or adding tests to any app. Also load when the user asks about testing, test stubs,
  mocking spark, or why tests are failing. Enforces pytest, mocked spark.table() calls,
  and pandas-based logic layer tests — never hitting Unity Catalog in unit tests.
---

# Testing Scaffold

Every generated app must include `tests/test_data.py` and `tests/test_logic.py`.
Tests must be present even if minimal — this enforces testability from day one.

## Rules

- Data layer tests mock `spark.table()` — never hit Unity Catalog
- Logic layer tests use small hardcoded `pandas` DataFrames
- Always use `pytest` — no `unittest` directly
- Test function names: `test_<function>_<condition>`
- Never put Spark or Databricks calls in logic tests

## tests/test_data.py

```python
"""Tests for data.py — all spark.table() calls are mocked."""
import pytest
from unittest.mock import patch, MagicMock
from data import DataAccessError

def test_load_table_calls_correct_table_name():
    with patch("data.spark") as mock_spark:
        mock_spark.table.return_value = MagicMock()
        from data import load_table
        load_table("prod", "gold", "sales_daily")
        mock_spark.table.assert_called_once_with("prod.gold.sales_daily")

def test_load_table_raises_data_access_error_on_failure():
    with patch("data.spark") as mock_spark:
        mock_spark.table.side_effect = Exception("table not found")
        from data import load_table
        with pytest.raises(DataAccessError):
            load_table("prod", "gold", "sales_daily")

def test_filter_by_date_reduces_rows():
    import pandas as pd
    from pyspark.sql import SparkSession
    # Use a small local Spark session for filter tests
    spark_local = SparkSession.builder.master("local").getOrCreate()
    df = spark_local.createDataFrame(
        [("2024-01-01", 100), ("2024-06-01", 200), ("2024-12-01", 300)],
        ["order_date", "amount"]
    )
    from data import filter_by_date
    result = filter_by_date(df, "order_date", "2024-01-01", "2024-06-30")
    assert result.count() == 2
```

## tests/test_logic.py

```python
"""Tests for logic.py — uses pandas DataFrames, no Spark."""
import pytest
import pandas as pd

SAMPLE = pd.DataFrame({
    "order_date": ["2024-01-01", "2024-01-01", "2024-01-02"],
    "region":     ["North", "South", "North"],
    "amount":     [100.0, 200.0, 150.0],
})

def test_aggregate_returns_dataframe():
    from logic import aggregate_by_day  # replace with actual function
    result = aggregate_by_day(SAMPLE)
    assert isinstance(result, pd.DataFrame)

def test_aggregate_returns_correct_row_count():
    from logic import aggregate_by_day
    result = aggregate_by_day(SAMPLE)
    assert len(result) == 2  # 2 unique dates

def test_aggregate_totals_correctly():
    from logic import aggregate_by_day
    result = aggregate_by_day(SAMPLE)
    total = result["total_amount"].sum()
    assert total == 450.0

def test_empty_dataframe_returns_empty():
    from logic import aggregate_by_day
    empty = pd.DataFrame(columns=SAMPLE.columns)
    result = aggregate_by_day(empty)
    assert len(result) == 0
```

## Running Tests

```bash
# From app root
pip install pytest --break-system-packages
pytest tests/ -v

# With coverage
pip install pytest-cov --break-system-packages
pytest tests/ --cov=. --cov-report=term-missing
```
