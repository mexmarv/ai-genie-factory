---
name: ui-patterns
description: >
  Plotly chart patterns and UI layer rules for Databricks Apps at Alpura. Load when
  writing or reviewing ui.py, any Plotly figure, chart function, or pandas conversion.
  Also load when the user asks which chart type to use, how to structure a chart function,
  or why a chart looks wrong. Enforces pure chart functions, styled hover templates,
  gradient fills, correct pandas conversion location, and chart type selection rules.
  Works alongside @databricks-app-design which provides color tokens, shadow system,
  and BASE_LAYOUT theme settings.
---

# UI Patterns — Plotly Chart Layer

Apply to every `ui.py` file. The UI layer does ONE thing: take a pandas DataFrame and return a Plotly figure.

## Rules

- All chart functions are **pure**: accept `pd.DataFrame`, return `go.Figure`
- `df.toPandas()` conversion happens HERE — never in `data.py` or `logic.py`
- No `spark.table()` calls — no Spark in the UI layer
- No business logic — aggregations and groupBy belong in `logic.py`
- Call `apply_base_layout(fig)` from `@databricks-app-design` on every figure
- Always set a styled `hovertemplate` — never leave the default Plotly tooltip
- One function per chart — never build two charts in the same function
- Always wrap chart functions in `try/except` and return `_error_figure()` on failure

---

## Standard Imports

```python
"""UI layer — Plotly figures and pandas conversion only. No Spark, no business logic."""
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd
from _logger import get_logger

logger = get_logger(__name__)

# From @databricks-app-design
SEQ        = ["#00bcd4","#00a8c0","#0094a8","#008090","#006c78"]
CATEGORICAL = ["#00bcd4","#7c4dff","#22c55e","#f59e0b","#f43f5e"]
FILL_CYAN   = "rgba(0,188,212,0.08)"
FILL_PURPLE = "rgba(124,77,255,0.08)"
```

---

## Trend Line Chart

```python
def build_trend_chart(df: pd.DataFrame, x: str, y: str, title: str) -> go.Figure:
    """Smooth line chart with gradient fill — for any metric over time."""
    try:
        fig = px.line(
            df, x=x, y=y,
            title=title,
            color_discrete_sequence=SEQ,
        )
        fig.update_traces(
            line=dict(width=2, color="#00bcd4"),
            fill="tozeroy",
            fillcolor=FILL_CYAN,
            mode="lines",
            hovertemplate=(
                "<b>%{x}</b><br>"
                f"{y}: <b>%{{y:,.0f}}</b><extra></extra>"
            ),
        )
        fig.update_layout(
            title_text=title,
            hovermode="x unified",
        )
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_trend_chart failed: {e}")
        return _error_figure(str(e))
```

---

## Horizontal Bar Chart

```python
def build_category_chart(df: pd.DataFrame, x: str, y: str, title: str) -> go.Figure:
    """Ranked horizontal bar chart — category comparisons, sorted descending."""
    try:
        df_sorted = df.sort_values(x, ascending=True)  # ascending=True flips to desc on horizontal
        fig = px.bar(
            df_sorted, x=x, y=y,
            orientation="h",
            title=title,
            color_discrete_sequence=SEQ,
        )
        fig.update_traces(
            marker=dict(
                color="#00bcd4",
                opacity=0.85,
                line=dict(width=0),
            ),
            hovertemplate=(
                "<b>%{y}</b><br>"
                f"{x}: <b>%{{x:,.0f}}</b><extra></extra>"
            ),
        )
        fig.update_layout(
            title_text=title,
            yaxis=dict(categoryorder="total ascending"),
            bargap=0.35,
        )
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_category_chart failed: {e}")
        return _error_figure(str(e))
```

---

## Multi-Metric Dual-Axis Chart

```python
def build_dual_axis_chart(
    df: pd.DataFrame,
    x: str, y1: str, y2: str,
    label1: str, label2: str,
    title: str,
) -> go.Figure:
    """Two metrics sharing the same x-axis with independent y-axes."""
    try:
        fig = make_subplots(specs=[[{"secondary_y": True}]])
        fig.add_trace(
            go.Scatter(
                x=df[x], y=df[y1], name=label1,
                line=dict(color="#00bcd4", width=2),
                fill="tozeroy", fillcolor=FILL_CYAN,
                hovertemplate=f"<b>%{{x}}</b><br>{label1}: <b>%{{y:,.0f}}</b><extra></extra>",
            ),
            secondary_y=False,
        )
        fig.add_trace(
            go.Scatter(
                x=df[x], y=df[y2], name=label2,
                line=dict(color="#7c4dff", width=2),
                fill="tozeroy", fillcolor=FILL_PURPLE,
                hovertemplate=f"<b>%{{x}}</b><br>{label2}: <b>%{{y:,.0f}}</b><extra></extra>",
            ),
            secondary_y=True,
        )
        fig.update_layout(
            title_text=title,
            hovermode="x unified",
            yaxis=dict(title=label1, titlefont=dict(color="#00bcd4", size=11)),
            yaxis2=dict(title=label2, titlefont=dict(color="#7c4dff", size=11)),
        )
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_dual_axis_chart failed: {e}")
        return _error_figure(str(e))
```

---

## Treemap (Part of Whole)

```python
def build_treemap(df: pd.DataFrame, path: list[str], values: str, title: str) -> go.Figure:
    """Hierarchical treemap — use instead of pie charts."""
    try:
        fig = px.treemap(
            df,
            path=path,
            values=values,
            title=title,
            color_continuous_scale=[[0, "#0d1117"], [0.3, "#003087"], [0.7, "#0070e0"], [1.0, "#00bcd4"]],
            color=values,
        )
        fig.update_traces(
            marker=dict(
                cornerradius=4,
                line=dict(width=1.5, color="#080d14"),
            ),
            hovertemplate="<b>%{label}</b><br>%{value:,.0f}<extra></extra>",
            textfont=dict(family="Inter, system-ui", size=12, color="#e8edf4"),
        )
        fig.update_layout(title_text=title, margin=dict(l=0, r=0, t=40, b=0))
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_treemap failed: {e}")
        return _error_figure(str(e))
```

---

## Scatter Plot

```python
def build_scatter(
    df: pd.DataFrame,
    x: str, y: str,
    size: str = None, color: str = None,
    title: str = "",
) -> go.Figure:
    """Scatter — correlation or distribution with optional bubble size."""
    try:
        fig = px.scatter(
            df, x=x, y=y,
            size=size,
            color=color,
            title=title,
            color_discrete_sequence=CATEGORICAL,
            opacity=0.75,
        )
        fig.update_traces(
            marker=dict(line=dict(width=0.5, color="rgba(0,0,0,0.3)")),
            hovertemplate=(
                f"<b>{x}:</b> %{{x:,.2f}}<br>"
                f"<b>{y}:</b> %{{y:,.2f}}<extra></extra>"
            ),
        )
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_scatter failed: {e}")
        return _error_figure(str(e))
```

---

## Histogram

```python
def build_histogram(df: pd.DataFrame, x: str, title: str, nbins: int = 30) -> go.Figure:
    """Distribution histogram."""
    try:
        fig = px.histogram(df, x=x, nbins=nbins, title=title, color_discrete_sequence=SEQ)
        fig.update_traces(
            marker=dict(color="#00bcd4", opacity=0.8, line=dict(width=0)),
            hovertemplate=f"Range: <b>%{{x}}</b><br>Count: <b>%{{y}}</b><extra></extra>",
        )
        fig.update_layout(bargap=0.05)
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_histogram failed: {e}")
        return _error_figure(str(e))
```

---

## Error Figure

```python
def _error_figure(message: str) -> go.Figure:
    """Blank figure with error annotation — never crash the UI, always return a figure."""
    fig = go.Figure()
    fig.add_annotation(
        text=f"⚠ Chart unavailable",
        showarrow=False,
        font=dict(color="#f43f5e", size=14, family="Inter, system-ui"),
        xref="paper", yref="paper", x=0.5, y=0.55,
    )
    fig.add_annotation(
        text=message,
        showarrow=False,
        font=dict(color="#4a5568", size=11, family="Inter, system-ui"),
        xref="paper", yref="paper", x=0.5, y=0.42,
    )
    return apply_base_layout(fig)
```

---

## Pandas Conversion — Always in UI Layer

```python
# ui.py — CORRECT: convert here, pass pandas to chart functions
def build_chart_from_spark(spark_df) -> go.Figure:
    df = spark_df.toPandas()          # ← conversion happens in UI layer
    return build_trend_chart(df, x="date", y="amount", title="Trend")

# logic.py — WRONG
def compute_trend(df):
    return df.groupBy(...).agg(...).toPandas()  # ← never convert in logic layer
```

---

## Chart Type Selection

| User asks for | Use | Never |
|---|---|---|
| Trend, over time, history | `build_trend_chart` — `px.line` + fill | `px.bar` for time |
| Compare, ranking, top N | `build_category_chart` — `px.bar` horizontal | Vertical bars for long labels |
| Share, breakdown, composition | `build_treemap` — `px.treemap` | `px.pie` anywhere |
| Distribution, spread, frequency | `build_histogram` — `px.histogram` | — |
| Two metrics over time | `build_dual_axis_chart` — `make_subplots` | Two separate charts |
| Correlation, two continuous vars | `build_scatter` — `px.scatter` | Line chart |
| Geographic / map | `px.choropleth_mapbox` | — |

Never `px.pie`. Never 3D. Never default Plotly blue `#636efa`.

---

## Hover Template Quick Reference

```python
# Currency
hovertemplate="<b>%{x}</b><br>Revenue: <b>$%{y:,.0f}</b><extra></extra>"

# Percentage
hovertemplate="<b>%{x}</b><br>Rate: <b>%{y:.1f}%</b><extra></extra>"

# Count
hovertemplate="<b>%{label}</b><br>Count: <b>%{value:,}</b><extra></extra>"

# Date + value (unified hover)
fig.update_layout(hovermode="x unified")
hovertemplate="<b>%{y:,.0f}</b><extra></extra>"
```

Always use `<extra></extra>` to suppress the trace name box. Always bold the value with `<b>`.
