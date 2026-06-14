---
name: databricks-app-design
description: >
  UX/UI design system for all Databricks Apps at Alpura. Load this skill whenever building,
  reviewing, or debugging any app UI — including ui.py, app.py, Plotly charts, KPI cards,
  filter panels, dark-theme dashboards, or layout structure. Also @mention this skill when
  the user asks about colors, theme, design tokens, chart styling, or "making the app look right".
  Enforces the full Alpura visual identity: color tokens, Plotly dark theme, layout order,
  component patterns for Dash and Streamlit, and number formatting utilities.
---

# Databricks App Design — Alpura UX/UI System

Apply this skill to every `ui.py` and `app.py` file generated or reviewed.

## Design Tokens

Use these exact hex values. Never invent colors per app.

| Token | Hex | Use |
|---|---|---|
| Background | `#0d1117` | App canvas, outermost container |
| Card | `#161b22` | Panels, chart containers, KPI cards |
| Elevated | `#1c2128` | Dropdowns, hover states, modals |
| Border | `#30363d` | Card edges, dividers, input borders |
| Text primary | `#e6edf3` | Headlines, KPI values, titles |
| Text secondary | `#8b949e` | Labels, axis text, subtitles |
| Text muted | `#484f58` | Placeholders, disabled |
| Accent blue | `#00bcd4` | Primary CTA, active filters, links |
| Accent purple | `#7c4dff` | Secondary metrics, secondary charts |
| Positive green | `#26a641` | Positive deltas, success states |
| Negative red | `#f85149` | Negative deltas, errors |
| Warning orange | `#e3b341` | Warnings, neutral-negative |
| Alpura brand | `#003087` | Headers only — use sparingly |

## Plotly Theme — Apply to Every Figure

```python
BASE_LAYOUT = dict(
    template="plotly_dark",
    paper_bgcolor="#161b22",
    plot_bgcolor="#161b22",
    font=dict(family="Inter, system-ui", color="#8b949e", size=11),
    margin=dict(l=40, r=20, t=40, b=40),
    title_font=dict(size=13, color="#e6edf3"),
    xaxis=dict(gridcolor="#30363d", linecolor="#30363d"),
    yaxis=dict(gridcolor="#30363d", linecolor="#30363d"),
    legend=dict(bgcolor="rgba(0,0,0,0)", bordercolor="#30363d"),
)

def apply_base_layout(fig):
    fig.update_layout(**BASE_LAYOUT)
    return fig
```

## Chart Color Sequences

```python
SEQ        = ["#00bcd4","#00a8bb","#0094a3","#00808b","#006c74"]  # single metric
CATEGORICAL = ["#00bcd4","#7c4dff","#26a641","#e3b341","#f85149"] # multi-series
DIVERGING   = ["#f85149","#e3b341","#26a641"]                      # pos/neg
```

Never use default Plotly blue `#636efa`.

## Chart Type Rules

| Data | Use | Never |
|---|---|---|
| Trend over time | `px.line`, `fill="tozeroy"`, `#00bcd4` | Bar chart for time series |
| Category comparison | `px.bar` horizontal, sorted desc | Vertical bars for long labels |
| Part of whole | `px.treemap` | `px.pie` — unreadable on dark bg |
| Distribution | `px.histogram`, `#00bcd4` | — |
| Multi-metric | `go.Figure` + `make_subplots`, shared x | Separate unlinked charts |

## App Layout Order

Always this sequence — never reorder:

```
1. App header       (title + data source subtitle)
2. Filter bar       (horizontal, date range + dropdowns)
3. KPI row          (3–4 metric cards, flex row, full width)
4. Chart row(s)     (max 2 per row, side by side)
5. Data table       (optional, always last)
```

## KPI Card Pattern

```python
def kpi_card(label, value, delta=None, positive=True):
    delta_color = "#26a641" if positive else "#f85149"
    children = [
        html.Div(label, style={"color":"#8b949e","fontSize":"12px","marginBottom":"4px"}),
        html.Div(value, style={"color":"#e6edf3","fontSize":"40px","fontWeight":"700","lineHeight":"1"}),
    ]
    if delta:
        children.append(html.Div(delta, style={"color":delta_color,"fontSize":"12px","marginTop":"4px"}))
    return html.Div(children, style={
        "background":"#161b22","border":"1px solid #30363d",
        "borderRadius":"8px","padding":"16px","flex":"1"
    })
```

## Number Formatting

```python
def fmt_number(n):
    if n >= 1_000_000_000: return f"{n/1_000_000_000:.1f}B"
    if n >= 1_000_000:     return f"{n/1_000_000:.1f}M"
    if n >= 1_000:         return f"{n/1_000:.1f}K"
    return f"{n:,.0f}"

def fmt_currency(n): return f"${fmt_number(n)}"
def fmt_pct(n):      return f"{n:.1f}%"

def fmt_delta(current, previous):
    if previous == 0: return "N/A", True
    pct = ((current - previous) / previous) * 100
    sign = "▲" if pct >= 0 else "▼"
    return f"{sign} {abs(pct):.1f}% vs prior period", pct >= 0
```

## App Shell Background

```python
# Outermost container — always:
style={"background":"#0d1117","minHeight":"100vh","padding":"24px","fontFamily":"Inter, system-ui"}
```

## Forbidden

- Light/white backgrounds
- `px.pie` — use `px.treemap`
- Default Plotly blue `#636efa`
- Per-app invented colors outside the token set
- Raw hex values without a comment naming the token

---

## Dash App Shell Patterns

Full patterns for building Dash apps that run inside Databricks Apps.

### Imports

```python
# app.py — standard imports for Databricks Apps (Dash)
import dash
from dash import html, dcc, Input, Output, dash_table
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from datetime import datetime, timedelta
import pandas as pd
from _logger import get_logger

from data import load_<entity>          # import your data functions
from logic import transform_<entity>    # import your logic functions
from ui import (                        # import your UI functions
    kpi_card, date_filter, data_table,
    apply_base_layout, fmt_number
)

logger = get_logger(__name__)
```

### App Initialization

```python
# app.py
app = dash.Dash(
    __name__,
    title="App Name — Alpura",
    suppress_callback_exceptions=True
)

CONFIG = {
    "catalog": "prod",
    "schema": "gold",
    "table": "your_table_name"
}
```

### CSS Variables Injection

Inject design tokens as CSS variables at app startup:

```python
# app.py — inject design tokens
app.index_string = '''
<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <title>{%title%}</title>
        {%favicon%}
        {%css%}
        <style>
            :root {
                --bg-primary:    #0d1117;
                --bg-card:       #161b22;
                --bg-elevated:   #1c2128;
                --border:        #30363d;
                --text-primary:  #e6edf3;
                --text-secondary:#8b949e;
                --text-muted:    #484f58;
                --accent-blue:   #00bcd4;
                --accent-purple: #7c4dff;
                --accent-green:  #26a641;
                --accent-red:    #f85149;
                --accent-orange: #e3b341;
                --alpura-blue:   #003087;
            }
            body {
                background: var(--bg-primary);
                color: var(--text-primary);
                font-family: Inter, system-ui, sans-serif;
                margin: 0;
            }
            * { box-sizing: border-box; }
        </style>
    </head>
    <body>
        {%app_entry%}
        <footer>{%config%}{%scripts%}{%renderer%}</footer>
    </body>
</html>
'''
```

### App Header

```python
def app_header(title: str, subtitle: str) -> html.Div:
    return html.Div([
        html.Div([
            html.H1(title, style={
                "color": "var(--text-primary)", "fontSize": "20px",
                "fontWeight": "600", "margin": "0"
            }),
            html.Div(subtitle, style={
                "color": "var(--text-secondary)", "fontSize": "12px", "marginTop": "2px"
            })
        ]),
    ], style={
        "padding": "16px 24px",
        "borderBottom": "1px solid var(--border)",
        "background": "var(--bg-card)",
        "marginBottom": "16px"
    })
```

### Full Layout

```python
# app.py — complete layout
app.layout = html.Div([
    app_header("App Title", "Powered by catalog.schema.table"),

    # Filter bar
    html.Div([
        date_filter("main"),
        # add more filters here
    ], style={
        "display": "flex", "gap": "16px", "alignItems": "flex-end",
        "padding": "12px 24px",
        "background": "var(--bg-card)",
        "border": "1px solid var(--border)",
        "borderRadius": "8px",
        "marginBottom": "16px"
    }),

    # KPI row
    html.Div(id="kpi-row", style={
        "display": "flex", "gap": "12px", "marginBottom": "16px"
    }),

    # Chart row
    html.Div([
        html.Div(dcc.Graph(id="chart-1"), style={"flex": "1", "background": "var(--bg-card)", "border": "1px solid var(--border)", "borderRadius": "8px", "padding": "16px"}),
        html.Div(dcc.Graph(id="chart-2"), style={"flex": "1", "background": "var(--bg-card)", "border": "1px solid var(--border)", "borderRadius": "8px", "padding": "16px"}),
    ], style={"display": "flex", "gap": "12px", "marginBottom": "16px"}),

    # Data table
    html.Div(id="data-table-container", style={
        "background": "var(--bg-card)",
        "border": "1px solid var(--border)",
        "borderRadius": "8px",
        "padding": "16px"
    }),

], style={"padding": "24px", "background": "var(--bg-primary)", "minHeight": "100vh"})
```

### Callback Pattern

```python
# app.py — standard callback
@app.callback(
    Output("kpi-row", "children"),
    Output("chart-1", "figure"),
    Output("chart-2", "figure"),
    Output("data-table-container", "children"),
    Input("main-date-range", "start_date"),
    Input("main-date-range", "end_date"),
)
def update_dashboard(start_date, end_date):
    try:
        # Data layer
        df_raw = load_entity(CONFIG)

        # Logic layer
        df_kpis = compute_kpis(df_raw, start_date, end_date)
        df_trend = compute_trend(df_raw, start_date, end_date)
        df_by_cat = compute_by_category(df_raw, start_date, end_date)

        # UI layer — pandas conversion happens here
        kpis = [
            kpi_card("Total Revenue", fmt_currency(df_kpis["revenue"]), f"▲ 12.3% vs prior", True),
            kpi_card("Orders", fmt_number(df_kpis["orders"]), f"▼ 2.1% vs prior", False),
        ]

        fig_trend = build_trend_chart(df_trend.toPandas())
        fig_by_cat = build_category_chart(df_by_cat.toPandas())
        table = data_table(df_by_cat.toPandas(), "main-table")

        return kpis, fig_trend, fig_by_cat, table

    except Exception as e:
        logger.error(f"Dashboard update failed: {e}")
        empty_fig = go.Figure()
        empty_fig.update_layout(
            **BASE_LAYOUT,
            annotations=[{"text": f"Error: {str(e)}", "showarrow": False,
                          "font": {"color": "var(--accent-red)", "size": 14}}]
        )
        return [], empty_fig, empty_fig, html.Div(f"Error: {e}", style={"color": "var(--accent-red)"})

if __name__ == "__main__":
    app.run(debug=False)
```

---

## Streamlit App Patterns

Use these patterns when the target is Streamlit on Databricks instead of Dash.
Same design tokens apply — inject them via st.markdown.

### CSS Injection

```python
# app.py — inject design tokens into Streamlit
st.markdown("""
<style>
    :root {
        --bg-primary:     #0d1117;
        --bg-card:        #161b22;
        --bg-elevated:    #1c2128;
        --border:         #30363d;
        --text-primary:   #e6edf3;
        --text-secondary: #8b949e;
        --accent-blue:    #00bcd4;
        --accent-purple:  #7c4dff;
        --accent-green:   #26a641;
        --accent-red:     #f85149;
        --accent-orange:  #e3b341;
    }
    .main { background: var(--bg-primary) !important; }
    .stApp { background: var(--bg-primary) !important; }
    h1, h2, h3 { color: var(--text-primary) !important; }
    p, label { color: var(--text-secondary) !important; }
</style>
""", unsafe_allow_html=True)
```

### KPI Card (Streamlit)

```python
# ui.py — KPI card for Streamlit using st.metric
def render_kpi_row(metrics: list[dict]):
    """metrics = [{"label": str, "value": str, "delta": str}]"""
    cols = st.columns(len(metrics))
    for col, m in zip(cols, metrics):
        with col:
            st.metric(
                label=m["label"],
                value=m["value"],
                delta=m.get("delta")
            )
```

### Filter Bar (Streamlit)

```python
# app.py — sidebar filters
with st.sidebar:
    st.markdown("### Filters")
    end_date = datetime.today().date()
    start_date = end_date - timedelta(days=30)
    date_range = st.date_input(
        "Date Range",
        value=(start_date, end_date),
        max_value=end_date
    )
    region = st.selectbox("Region", options=["All"] + regions)
```

### Chart Display (Streamlit)

```python
# ui.py — chart display with consistent config
def render_chart(fig, key: str = None):
    st.plotly_chart(
        fig,
        use_container_width=True,
        config={"displayModeBar": False},
        key=key
    )
```

### Data Table (Streamlit)

```python
# ui.py — data table
def render_table(df: pd.DataFrame, title: str = None):
    if title:
        st.markdown(f"**{title}**")
    st.dataframe(
        df,
        use_container_width=True,
        hide_index=True
    )
```

### Full App Structure (Streamlit)

```python
# app.py
import streamlit as st
from datetime import datetime, timedelta
import pandas as pd
from _logger import get_logger
from data import load_entity
from logic import transform_entity
from ui import render_kpi_row, render_chart, render_table, build_trend_chart, build_category_chart

logger = get_logger(__name__)

st.set_page_config(
    page_title="App Name — Alpura",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Inject design tokens
st.markdown("""<style>...</style>""", unsafe_allow_html=True)

# Header
st.title("App Name")
st.caption("Powered by catalog.schema.table")
st.divider()

# Filters
with st.sidebar:
    st.markdown("### Filters")
    date_range = st.date_input("Date Range", value=(datetime.today().date() - timedelta(30), datetime.today().date()))

# Load and transform
try:
    df_raw = load_entity()
    df_kpis = compute_kpis(df_raw, *date_range)
    df_trend = compute_trend(df_raw, *date_range).toPandas()
    df_by_cat = compute_by_category(df_raw, *date_range).toPandas()
except Exception as e:
    logger.error(f"Load failed: {e}")
    st.error(f"Data unavailable: {e}")
    st.stop()

# KPI row
render_kpi_row([
    {"label": "Total Revenue", "value": fmt_currency(df_kpis["revenue"]), "delta": "+12.3%"},
    {"label": "Orders", "value": fmt_number(df_kpis["orders"]), "delta": "-2.1%"},
])

# Charts
col1, col2 = st.columns(2)
with col1:
    render_chart(build_trend_chart(df_trend))
with col2:
    render_chart(build_category_chart(df_by_cat))

# Table
st.divider()
render_table(df_by_cat, title="Detail View")
```
