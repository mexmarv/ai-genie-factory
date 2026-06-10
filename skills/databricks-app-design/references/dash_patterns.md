# Dash App Shell Patterns — Databricks Apps

Full patterns for building Dash apps that run inside Databricks Apps.

## Imports

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

## App Initialization

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

## CSS Variables Injection

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

## App Header

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

## Full Layout

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

## Callback Pattern

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
