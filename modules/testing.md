TESTING

Every generated app must include a tests/ directory with unit test stubs. Stubs must be present even if minimal — this enforces testability from day one.

Rules:
- test stubs are required for data.py and logic.py in every app
- Data layer tests mock spark.table() — never hit Unity Catalog in unit tests
- Logic layer tests use small hardcoded pandas DataFrames as input
- UI layer tests are optional (visual regression is handled separately)
- All test files must import and use pytest
- Test function names must describe what they verify: test_<function>_<condition>

Required test files:
- tests/test_data.py
- tests/test_logic.py

Minimum stub — tests/test_data.py:
import pytest
from unittest.mock import patch, MagicMock

def test_load_table_called_with_correct_name():
    with patch("data.spark") as mock_spark:
        mock_spark.table.return_value = MagicMock()
        from data import load_table
        load_table()
        mock_spark.table.assert_called_once()

def test_load_table_raises_data_access_error_on_failure():
    with patch("data.spark") as mock_spark:
        mock_spark.table.side_effect = Exception("table not found")
        from data import load_table, DataAccessError
        with pytest.raises(DataAccessError):
            load_table()

Minimum stub — tests/test_logic.py:
import pytest
import pandas as pd

def test_transform_returns_dataframe():
    from logic import transform  # replace with actual function name
    sample = pd.DataFrame({"date": ["2024-01-01", "2024-01-02"], "value": [100, 200]})
    result = transform(sample)
    assert isinstance(result, pd.DataFrame)

def test_transform_returns_nonempty():
    from logic import transform
    sample = pd.DataFrame({"date": ["2024-01-01"], "value": [100]})
    result = transform(sample)
    assert len(result) > 0
