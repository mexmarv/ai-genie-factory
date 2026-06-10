# Streamlit App Patterns — Databricks Apps

Use these patterns when the target is Streamlit on Databricks instead of Dash.
Same design tokens apply — inject them via st.markdown.

## CSS Injection

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

## KPI Card (Streamlit)

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

## Filter Bar (Streamlit)

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

## Chart Display (Streamlit)

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

## Data Table (Streamlit)

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

## Full App Structure (Streamlit)

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
