---
name: ui-patterns
description: >
  Plotly chart patterns and UI layer rules for Databricks Apps at Alpura. Load when
  writing or reviewing ui.py, any Plotly figure, chart function, or pandas conversion.
  Also load when the user asks which chart type to use, how to structure a chart function,
  or why a chart looks wrong. Enforces pure chart functions, correct pandas conversion
  location, and chart type selection rules. Works alongside @databricks-app-design
  which provides the color tokens and theme settings.
---

# UI Patterns — Plotly Chart Layer

Apply to every `ui.py` file. The UI layer does ONE thing: take a pandas DataFrame and return a Plotly figure.

## Rules

- All chart functions are **pure**: accept `pd.DataFrame`, return `plotly.Figure`
- `df.toPandas()` conversion happens HERE — never in `data.py` or `logic.py`
- No `spark.table()` calls — no Spark in the UI layer
- No business logic — aggregations belong in `logic.py`
- Use `apply_base_layout(fig)` from `@databricks-app-design` on every figure
- One function per chart — never build two charts in the same function

## Standard Chart Function Shape

```python
"""UI layer — Plotly figures and pandas conversion only. No Spark, no business logic."""
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
from _logger import get_logger
logger = get_logger(__name__)

def build_trend_chart(df: pd.DataFrame) -> go.Figure:
    """Line chart: metric over time."""
    try:
        fig = px.line(
            df, x="date_col", y="metric_col",
            title="Metric Over Time",
            color_discrete_sequence=["#00bcd4"]
        )
        fig.update_traces(fill="tozeroy", fillcolor="rgba(0,188,212,0.1)")
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_trend_chart failed: {e}")
        return _error_figure(str(e))

def build_category_chart(df: pd.DataFrame) -> go.Figure:
    """Horizontal bar: category comparison, sorted descending."""
    try:
        df_sorted = df.sort_values("metric_col", ascending=True)
        fig = px.bar(
            df_sorted, x="metric_col", y="category_col",
            orientation="h", title="By Category",
            color_discrete_sequence=["#00bcd4"]
        )
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_category_chart failed: {e}")
        return _error_figure(str(e))

def _error_figure(message: str) -> go.Figure:
    """Return a blank figure with an error annotation — never crash the UI."""
    fig = go.Figure()
    fig.add_annotation(
        text=f"Chart unavailable: {message}",
        showarrow=False,
        font=dict(color="#f85149", size=13)
    )
    return apply_base_layout(fig)
```

## Pandas Conversion — Always in UI Layer

```python
# In ui.py — CORRECT
def build_chart(spark_df) -> go.Figure:
    df = spark_df.toPandas()   # ← conversion here
    return px.line(df, ...)

# In logic.py — WRONG
def transform(spark_df):
    return spark_df.toPandas()  # ← never here
```

## Chart Type Selection

| User asks for | Use |
|---|---|
| Trend, over time, history | `px.line` with `fill="tozeroy"` |
| Compare, ranking, top N | `px.bar` horizontal, sorted |
| Share, breakdown, composition | `px.treemap` |
| Distribution, spread | `px.histogram` |
| Two metrics over time | `make_subplots` with shared x-axis |
| Map, geographic | `px.choropleth_mapbox` |

Never use `px.pie`. Never use 3D charts.
