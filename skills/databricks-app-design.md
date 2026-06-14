---
name: databricks-app-design
description: >
  UX/UI design system for all Databricks Apps at Alpura. Load this skill whenever building,
  reviewing, or debugging any app UI — including ui.py, app.py, Plotly charts, KPI cards,
  filter panels, dark-theme dashboards, or layout structure. Also @mention this skill when
  the user asks about colors, theme, design tokens, chart styling, or "making the app look right".
  Enforces the full Alpura visual identity: color tokens, shadow/elevation system, typography
  scale, Plotly dark theme, layout order, component patterns for Dash and Streamlit, and
  number formatting utilities.
---

# Databricks App Design — Alpura UX/UI System

Apply this skill to every `ui.py` and `app.py` file generated or reviewed.

---

## Design Tokens

Use these exact hex values. Never invent colors per app.

| Token | Hex | Use |
|---|---|---|
| Background | `#080d14` | App canvas — deepest layer |
| Surface | `#0d1117` | Page body, section areas |
| Card | `#111820` | Panels, chart containers |
| Card hover | `#161d27` | Card hover / active state |
| Elevated | `#1a2332` | Dropdowns, modals, tooltips |
| Border subtle | `#1e2a3a` | Dividers, inner separators |
| Border default | `#253040` | Card edges, input borders |
| Border active | `#00bcd4` | Focused inputs, selected filters |
| Text primary | `#e8edf4` | Headlines, KPI values |
| Text secondary | `#8b96a8` | Labels, axis text, subtitles |
| Text muted | `#4a5568` | Placeholders, disabled |
| Accent cyan | `#00bcd4` | Primary CTA, active state, links |
| Accent cyan dim | `#008fa3` | Secondary cyan, hover state |
| Accent purple | `#7c4dff` | Secondary metrics, alt charts |
| Positive | `#22c55e` | Positive deltas, success |
| Negative | `#f43f5e` | Negative deltas, errors |
| Warning | `#f59e0b` | Warnings, neutral-alert |
| Alpura navy | `#003087` | App header bar only |
| Alpura blue glow | `rgba(0,48,135,0.15)` | Diffused header shadow |
| Cyan glow | `rgba(0,188,212,0.12)` | Active element halo |
| Cyan glow strong | `rgba(0,188,212,0.25)` | Focus rings, selected KPI |

---

## Shadow & Elevation System

Every surface has a depth. Never use flat unshadowed cards.

```python
# Shadow tokens — use as CSS box-shadow values
SHADOW = {
    # Subtle lift — default cards, chart containers
    "card":    "0 1px 3px rgba(0,0,0,0.4), 0 4px 16px rgba(0,0,0,0.3), 0 0 0 1px rgba(37,48,64,0.6)",
    # Medium lift — filter bar, KPI row
    "raised":  "0 4px 12px rgba(0,0,0,0.5), 0 8px 32px rgba(0,0,0,0.3), 0 0 0 1px rgba(37,48,64,0.5)",
    # Alpura brand header — diffused deep blue glow
    "header":  "0 2px 0px rgba(0,188,212,0.15), 0 8px 32px rgba(0,48,135,0.4), 0 1px 0 rgba(0,188,212,0.2)",
    # KPI card active / selected state
    "kpi_active": "0 0 0 1px rgba(0,188,212,0.4), 0 4px 20px rgba(0,188,212,0.15), 0 8px 32px rgba(0,0,0,0.4)",
    # Chart hover / focused
    "chart_focus": "0 0 0 1px rgba(0,188,212,0.2), 0 8px 40px rgba(0,0,0,0.5)",
}
```

---

## Typography Scale

Inter is mandatory. Load via Google Fonts or use system fallback.

```python
TYPE = {
    "font":         "Inter, -apple-system, BlinkMacSystemFont, system-ui, sans-serif",
    # Display — app title
    "display":      {"fontSize": "22px", "fontWeight": "700", "letterSpacing": "-0.3px", "lineHeight": "1.2"},
    # Heading — section titles, card headers
    "heading":      {"fontSize": "14px", "fontWeight": "600", "letterSpacing": "0.02em"},
    # KPI value — large metric number
    "kpi_value":    {"fontSize": "36px", "fontWeight": "700", "letterSpacing": "-0.5px", "lineHeight": "1"},
    # KPI label — small uppercase label
    "kpi_label":    {"fontSize": "11px", "fontWeight": "500", "letterSpacing": "0.08em", "textTransform": "uppercase"},
    # Body — general text
    "body":         {"fontSize": "13px", "fontWeight": "400", "lineHeight": "1.5"},
    # Caption — axis labels, hints, timestamps
    "caption":      {"fontSize": "11px", "fontWeight": "400", "letterSpacing": "0.01em"},
    # Code — monospace inline
    "mono":         {"fontFamily": "'JetBrains Mono', 'Fira Code', monospace", "fontSize": "12px"},
}
```

---

## Plotly Theme — Apply to Every Figure

```python
BASE_LAYOUT = dict(
    template="plotly_dark",
    paper_bgcolor="#111820",
    plot_bgcolor="#111820",
    font=dict(
        family="Inter, -apple-system, system-ui, sans-serif",
        color="#8b96a8",
        size=11
    ),
    title_font=dict(
        family="Inter, system-ui, sans-serif",
        size=13,
        color="#e8edf4"
    ),
    margin=dict(l=48, r=24, t=44, b=44),
    xaxis=dict(
        gridcolor="rgba(37,48,64,0.8)",
        linecolor="rgba(37,48,64,0.6)",
        tickfont=dict(size=10, color="#4a5568"),
        zeroline=False,
    ),
    yaxis=dict(
        gridcolor="rgba(37,48,64,0.8)",
        linecolor="rgba(37,48,64,0.6)",
        tickfont=dict(size=10, color="#4a5568"),
        zeroline=False,
    ),
    legend=dict(
        bgcolor="rgba(0,0,0,0)",
        bordercolor="rgba(37,48,64,0.5)",
        borderwidth=1,
        font=dict(size=11, color="#8b96a8"),
    ),
    hoverlabel=dict(
        bgcolor="#1a2332",
        bordercolor="rgba(0,188,212,0.3)",
        font=dict(family="Inter, system-ui", size=12, color="#e8edf4"),
    ),
    modebar=dict(
        bgcolor="rgba(0,0,0,0)",
        color="#4a5568",
        activecolor="#00bcd4",
    ),
)

def apply_base_layout(fig) -> go.Figure:
    fig.update_layout(**BASE_LAYOUT)
    return fig
```

---

## Chart Color Sequences

```python
SEQ        = ["#00bcd4","#00a8c0","#0094a8","#008090","#006c78"]  # single metric — cyan ramp
CATEGORICAL = ["#00bcd4","#7c4dff","#22c55e","#f59e0b","#f43f5e"] # multi-series
DIVERGING   = ["#f43f5e","#f59e0b","#22c55e"]                      # neg → neutral → pos
BLUES       = ["#003087","#004db3","#0070e0","#00a8c0","#00bcd4"]  # Alpura brand ramp

# Gradient fill for line charts — always use with fill="tozeroy"
FILL_CYAN   = "rgba(0,188,212,0.08)"   # subtle area under line
FILL_PURPLE = "rgba(124,77,255,0.08)"
```

Never use default Plotly blue `#636efa`. Never use opaque fills.

---

## Chart Type Rules

| Data shape | Chart | Key options |
|---|---|---|
| Trend over time | `px.line` | `fill="tozeroy"`, `color_discrete_sequence=SEQ` |
| Category comparison | `px.bar` horizontal | `orientation="h"`, sorted ascending for visual rank |
| Part of whole | `px.treemap` | `color_continuous_scale=BLUES` |
| Distribution | `px.histogram` | `nbins=30`, cyan bars |
| Multi-metric dual-axis | `make_subplots(specs=[[{"secondary_y":True}]])` | shared x |
| Scatter / correlation | `px.scatter` | `opacity=0.7`, size by third metric |
| Heatmap / calendar | `go.Heatmap` | `colorscale=[[0,"#111820"],[1,"#00bcd4"]]` |

Never `px.pie`. Never 3D charts. Never vertical bars for labels > 8 chars.

---

## App Layout Order

Always this sequence — never reorder:

```
1. App header     — branded bar: Alpura navy bg, title, data source caption
2. Filter bar     — horizontal row, card surface, date range + dropdowns
3. KPI row        — 3–4 metric cards, equal width flex, full page width
4. Chart row(s)   — max 2 charts per row, equal flex, card surface
5. Data table     — optional, always last, full width
```

Spacing: `24px` page padding, `12px` gap between cards, `16px` inner card padding.

---

## KPI Card — Enhanced Pattern

```python
def kpi_card(label: str, value: str, delta: str = None, positive: bool = True) -> html.Div:
    delta_color  = "#22c55e" if positive else "#f43f5e"
    delta_bg     = "rgba(34,197,94,0.08)" if positive else "rgba(244,63,94,0.08)"
    delta_symbol = "▲" if positive else "▼"

    children = [
        html.Div(label, style={
            "color": "#8b96a8",
            "fontSize": "11px",
            "fontWeight": "500",
            "letterSpacing": "0.08em",
            "textTransform": "uppercase",
            "marginBottom": "10px",
        }),
        html.Div(value, style={
            "color": "#e8edf4",
            "fontSize": "36px",
            "fontWeight": "700",
            "letterSpacing": "-0.5px",
            "lineHeight": "1",
            "fontFamily": "Inter, system-ui, sans-serif",
        }),
    ]
    if delta:
        children.append(
            html.Div([
                html.Span(delta_symbol + " ", style={"fontSize": "10px"}),
                html.Span(delta),
            ], style={
                "color": delta_color,
                "background": delta_bg,
                "fontSize": "11px",
                "fontWeight": "500",
                "marginTop": "10px",
                "padding": "3px 8px",
                "borderRadius": "4px",
                "display": "inline-block",
            })
        )

    return html.Div(children, style={
        "background":    "linear-gradient(145deg, #111820 0%, #0f1a26 100%)",
        "border":        "1px solid #253040",
        "borderRadius":  "10px",
        "padding":       "20px",
        "flex":          "1",
        "boxShadow":     "0 1px 3px rgba(0,0,0,0.4), 0 4px 16px rgba(0,0,0,0.3), 0 0 0 1px rgba(37,48,64,0.6)",
        "transition":    "box-shadow 0.2s ease, border-color 0.2s ease",
        "fontFamily":    "Inter, system-ui, sans-serif",
    })
```

---

## App Header — Branded Bar

```python
def app_header(title: str, subtitle: str) -> html.Div:
    return html.Div([
        html.Div(style={
            "width": "3px",
            "height": "32px",
            "background": "linear-gradient(180deg, #00bcd4 0%, #003087 100%)",
            "borderRadius": "2px",
            "marginRight": "14px",
            "flexShrink": "0",
        }),
        html.Div([
            html.Div(title, style={
                "color": "#e8edf4",
                "fontSize": "18px",
                "fontWeight": "700",
                "letterSpacing": "-0.2px",
                "lineHeight": "1.2",
                "fontFamily": "Inter, system-ui, sans-serif",
            }),
            html.Div(subtitle, style={
                "color": "#8b96a8",
                "fontSize": "11px",
                "fontWeight": "400",
                "marginTop": "2px",
                "letterSpacing": "0.01em",
            }),
        ]),
    ], style={
        "display":       "flex",
        "alignItems":    "center",
        "padding":       "16px 24px",
        "background":    "linear-gradient(135deg, #0a1628 0%, #0d1117 60%, #080d14 100%)",
        "borderBottom":  "1px solid #1e2a3a",
        "boxShadow":     "0 2px 0px rgba(0,188,212,0.15), 0 8px 32px rgba(0,48,135,0.4), 0 1px 0 rgba(0,188,212,0.2)",
        "marginBottom":  "24px",
    })
```

---

## Filter Bar

```python
# Shared filter bar style
FILTER_BAR_STYLE = {
    "display":       "flex",
    "gap":           "16px",
    "alignItems":    "flex-end",
    "padding":       "14px 20px",
    "background":    "linear-gradient(135deg, #111820 0%, #0f1822 100%)",
    "border":        "1px solid #1e2a3a",
    "borderRadius":  "10px",
    "boxShadow":     "0 4px 12px rgba(0,0,0,0.4), 0 1px 0 rgba(37,48,64,0.5)",
    "marginBottom":  "20px",
}

FILTER_LABEL_STYLE = {
    "color":         "#8b96a8",
    "fontSize":      "11px",
    "fontWeight":    "500",
    "letterSpacing": "0.06em",
    "textTransform": "uppercase",
    "marginBottom":  "6px",
}
```

---

## Card Container — Reusable Style

```python
CARD_STYLE = {
    "background":   "linear-gradient(145deg, #111820 0%, #0f1a26 100%)",
    "border":       "1px solid #253040",
    "borderRadius": "10px",
    "padding":      "20px",
    "boxShadow":    "0 1px 3px rgba(0,0,0,0.4), 0 4px 16px rgba(0,0,0,0.3)",
    "flex":         "1",
}

CHART_CARD_STYLE = {
    **CARD_STYLE,
    "padding": "16px",
    "transition": "box-shadow 0.2s ease",
}
```

---

## Number Formatting

```python
def fmt_number(n: float) -> str:
    if n is None: return "—"
    if n >= 1_000_000_000: return f"{n/1_000_000_000:.1f}B"
    if n >= 1_000_000:     return f"{n/1_000_000:.1f}M"
    if n >= 1_000:         return f"{n/1_000:.1f}K"
    return f"{n:,.0f}"

def fmt_currency(n: float) -> str: return f"${fmt_number(n)}"
def fmt_pct(n: float) -> str:      return f"{n:.1f}%"

def fmt_delta(current: float, previous: float) -> tuple[str, bool]:
    if previous == 0: return "N/A", True
    pct = ((current - previous) / previous) * 100
    sign = "▲" if pct >= 0 else "▼"
    return f"{sign} {abs(pct):.1f}% vs prior period", pct >= 0
```

---

## Forbidden

- Light or white backgrounds anywhere
- `px.pie` — always `px.treemap`
- Default Plotly blue `#636efa` — always `#00bcd4`
- Flat unshadowed cards — every surface must have `boxShadow`
- Per-app invented colors outside the token set
- Inline hex values without a token reference comment
- Vertical bar charts for category labels > 8 characters
- `font-family` other than Inter or the mono fallback

---

## Dash App Shell Patterns

### Imports

```python
import dash
from dash import html, dcc, Input, Output, dash_table
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from datetime import datetime, timedelta
import pandas as pd
from _logger import get_logger

from data import load_<entity>
from logic import transform_<entity>
from ui import kpi_card, apply_base_layout, fmt_number, fmt_currency, fmt_delta

logger = get_logger(__name__)
```

### App Init

```python
app = dash.Dash(
    __name__,
    title="App Name — Alpura",
    suppress_callback_exceptions=True,
)

CONFIG = {
    "catalog": "prod",
    "schema":  "gold",
    "table":   "your_table_name",
}
```

### CSS Variables Injection

```python
app.index_string = '''
<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <title>{%title%}</title>
        {%favicon%}
        {%css%}
        <style>
            @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap");

            :root {
                --bg-deep:         #080d14;
                --bg-surface:      #0d1117;
                --bg-card:         #111820;
                --bg-elevated:     #1a2332;
                --border-subtle:   #1e2a3a;
                --border:          #253040;
                --border-active:   #00bcd4;
                --text-primary:    #e8edf4;
                --text-secondary:  #8b96a8;
                --text-muted:      #4a5568;
                --accent-cyan:     #00bcd4;
                --accent-cyan-dim: #008fa3;
                --accent-purple:   #7c4dff;
                --positive:        #22c55e;
                --negative:        #f43f5e;
                --warning:         #f59e0b;
                --alpura-navy:     #003087;
                --shadow-card:     0 1px 3px rgba(0,0,0,.4), 0 4px 16px rgba(0,0,0,.3);
                --shadow-raised:   0 4px 12px rgba(0,0,0,.5), 0 8px 32px rgba(0,0,0,.3);
                --shadow-header:   0 2px 0 rgba(0,188,212,.15), 0 8px 32px rgba(0,48,135,.4);
            }

            * { box-sizing: border-box; margin: 0; padding: 0; }

            body {
                background:  var(--bg-deep);
                color:       var(--text-primary);
                font-family: Inter, -apple-system, system-ui, sans-serif;
                font-size:   13px;
                line-height: 1.5;
                -webkit-font-smoothing: antialiased;
            }

            ::-webkit-scrollbar { width: 6px; height: 6px; }
            ::-webkit-scrollbar-track { background: var(--bg-surface); }
            ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
            ::-webkit-scrollbar-thumb:hover { background: var(--text-muted); }

            .Select-control {
                background: var(--bg-elevated) !important;
                border-color: var(--border) !important;
                color: var(--text-primary) !important;
                border-radius: 6px !important;
            }
            .Select-menu-outer {
                background: var(--bg-elevated) !important;
                border-color: var(--border) !important;
                box-shadow: var(--shadow-raised) !important;
            }
            .Select-option:hover { background: rgba(0,188,212,0.08) !important; }
            input[type="text"], input[type="date"] {
                background: var(--bg-elevated) !important;
                border: 1px solid var(--border) !important;
                color: var(--text-primary) !important;
                border-radius: 6px !important;
                padding: 6px 10px !important;
            }
            input:focus, .Select-control:focus-within {
                border-color: var(--border-active) !important;
                box-shadow: 0 0 0 3px rgba(0,188,212,0.12) !important;
                outline: none;
            }
        </style>
    </head>
    <body>
        {%app_entry%}
        <footer>{%config%}{%scripts%}{%renderer%}</footer>
    </body>
</html>
'''
```

### Full Layout

```python
app.layout = html.Div([
    app_header("App Title", "Powered by prod.gold.table_name"),

    html.Div([  # Page body
        # Filter bar
        html.Div([
            date_filter("main"),
        ], style=FILTER_BAR_STYLE),

        # KPI row
        html.Div(id="kpi-row", style={
            "display": "flex", "gap": "12px", "marginBottom": "20px",
        }),

        # Chart row
        html.Div([
            html.Div(dcc.Graph(id="chart-1", config={"displayModeBar": False}), style=CHART_CARD_STYLE),
            html.Div(dcc.Graph(id="chart-2", config={"displayModeBar": False}), style=CHART_CARD_STYLE),
        ], style={"display": "flex", "gap": "12px", "marginBottom": "20px"}),

        # Data table
        html.Div(id="data-table-container", style=CARD_STYLE),
    ], style={"padding": "0 24px 24px 24px"}),

], style={"background": "#080d14", "minHeight": "100vh"})
```

### Callback Pattern

```python
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
        df_raw   = load_entity(CONFIG)
        df_kpis  = compute_kpis(df_raw, start_date, end_date)
        df_trend = compute_trend(df_raw, start_date, end_date)
        df_by_cat= compute_by_category(df_raw, start_date, end_date)

        delta_txt, is_pos = fmt_delta(df_kpis["revenue"], df_kpis["revenue_prior"])
        kpis = [
            kpi_card("Total Revenue", fmt_currency(df_kpis["revenue"]), delta_txt, is_pos),
            kpi_card("Orders",        fmt_number(df_kpis["orders"]),    "▲ 3.2% vs prior", True),
        ]
        fig_trend  = build_trend_chart(df_trend.toPandas())
        fig_by_cat = build_category_chart(df_by_cat.toPandas())
        table      = data_table(df_by_cat.toPandas(), "main-table")
        return kpis, fig_trend, fig_by_cat, table

    except Exception as e:
        logger.error(f"Dashboard update failed: {e}")
        err_fig = _error_figure(str(e))
        return [], err_fig, err_fig, html.Div(
            f"Data unavailable — {e}",
            style={"color": "#f43f5e", "padding": "16px", "fontSize": "13px"}
        )

if __name__ == "__main__":
    app.run(debug=False)
```

---

## Streamlit App Patterns

### CSS Injection

```python
st.markdown("""
<style>
    @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap");

    :root {
        --bg-deep:        #080d14;
        --bg-surface:     #0d1117;
        --bg-card:        #111820;
        --bg-elevated:    #1a2332;
        --border:         #253040;
        --border-active:  #00bcd4;
        --text-primary:   #e8edf4;
        --text-secondary: #8b96a8;
        --text-muted:     #4a5568;
        --accent-cyan:    #00bcd4;
        --accent-purple:  #7c4dff;
        --positive:       #22c55e;
        --negative:       #f43f5e;
        --shadow-card:    0 1px 3px rgba(0,0,0,.4), 0 4px 16px rgba(0,0,0,.3);
    }

    html, body, .stApp, [data-testid="stAppViewContainer"] {
        background: var(--bg-deep) !important;
        font-family: Inter, system-ui, sans-serif !important;
        -webkit-font-smoothing: antialiased;
    }
    [data-testid="stSidebar"] {
        background: var(--bg-surface) !important;
        border-right: 1px solid var(--border) !important;
    }
    h1 { color: var(--text-primary) !important; font-size: 20px !important; font-weight: 700 !important; letter-spacing: -0.3px !important; }
    h2, h3 { color: var(--text-primary) !important; font-weight: 600 !important; }
    p, label, .stMarkdown { color: var(--text-secondary) !important; font-size: 13px !important; }
    .stMetric { background: var(--bg-card); border: 1px solid var(--border); border-radius: 10px; padding: 16px; box-shadow: var(--shadow-card); }
    .stMetric label { color: var(--text-secondary) !important; font-size: 11px !important; text-transform: uppercase; letter-spacing: 0.06em; }
    .stMetric [data-testid="metric-container"] > div:nth-child(2) { color: var(--text-primary) !important; font-size: 32px !important; font-weight: 700 !important; }
    .stDataFrame, .stTable { background: var(--bg-card) !important; border: 1px solid var(--border) !important; border-radius: 10px !important; }
    .stSelectbox > div > div { background: var(--bg-elevated) !important; border-color: var(--border) !important; border-radius: 6px !important; }
    .stDateInput > div > div { background: var(--bg-elevated) !important; border-color: var(--border) !important; border-radius: 6px !important; }
    ::-webkit-scrollbar { width: 5px; } ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
</style>
""", unsafe_allow_html=True)
```

### KPI Row (Streamlit)

```python
def render_kpi_row(metrics: list[dict]):
    """metrics = [{"label": str, "value": str, "delta": str, "positive": bool}]"""
    cols = st.columns(len(metrics))
    for col, m in zip(cols, metrics):
        with col:
            delta_val = m.get("delta")
            # st.metric shows green for positive delta strings, red for negative
            st.metric(
                label=m["label"],
                value=m["value"],
                delta=delta_val,
                delta_color="normal" if m.get("positive", True) else "inverse",
            )
```

### Filter Bar (Streamlit)

```python
with st.sidebar:
    st.markdown("""
    <div style="padding:12px 0 8px; font-size:11px; font-weight:600;
                letter-spacing:0.08em; text-transform:uppercase; color:#8b96a8;">
        Filters
    </div>
    """, unsafe_allow_html=True)
    end_date   = datetime.today().date()
    start_date = end_date - timedelta(days=30)
    date_range = st.date_input("Date Range", value=(start_date, end_date), max_value=end_date)
    region     = st.selectbox("Region", options=["All"] + regions)
```

### Chart & Table Helpers (Streamlit)

```python
def render_chart(fig, key: str = None):
    st.plotly_chart(fig, use_container_width=True, config={"displayModeBar": False}, key=key)

def render_table(df: pd.DataFrame, title: str = None):
    if title:
        st.markdown(f"<p style='font-size:11px;font-weight:600;letter-spacing:.06em;"
                    f"text-transform:uppercase;color:#8b96a8;margin-bottom:8px'>{title}</p>",
                    unsafe_allow_html=True)
    st.dataframe(df, use_container_width=True, hide_index=True)
```

### Full App Structure (Streamlit)

```python
import streamlit as st
from datetime import datetime, timedelta
import pandas as pd
from _logger import get_logger
from data import load_entity
from logic import compute_kpis, compute_trend, compute_by_category
from ui import render_kpi_row, render_chart, render_table, build_trend_chart, build_category_chart
from ui import fmt_currency, fmt_number, fmt_delta

logger = get_logger(__name__)

st.set_page_config(page_title="App Name — Alpura", layout="wide", initial_sidebar_state="expanded")

# Inject CSS (full block from CSS Injection section above)
st.markdown("""<style>...</style>""", unsafe_allow_html=True)

# Header
st.markdown("""
<div style="display:flex;align-items:center;padding:0 0 20px;border-bottom:1px solid #1e2a3a;margin-bottom:24px">
    <div style="width:3px;height:28px;background:linear-gradient(180deg,#00bcd4,#003087);border-radius:2px;margin-right:12px"></div>
    <div>
        <div style="font-size:18px;font-weight:700;color:#e8edf4;letter-spacing:-0.2px">App Name</div>
        <div style="font-size:11px;color:#8b96a8;margin-top:2px">Powered by prod.gold.table_name</div>
    </div>
</div>
""", unsafe_allow_html=True)

with st.sidebar:
    date_range = st.date_input("Date Range", value=(datetime.today().date() - timedelta(30), datetime.today().date()))

try:
    df_raw   = load_entity()
    df_kpis  = compute_kpis(df_raw, *date_range)
    df_trend = compute_trend(df_raw, *date_range).toPandas()
    df_by_cat= compute_by_category(df_raw, *date_range).toPandas()
except Exception as e:
    logger.error(f"Load failed: {e}")
    st.error(f"Data unavailable: {e}")
    st.stop()

delta_txt, is_pos = fmt_delta(df_kpis["revenue"], df_kpis["revenue_prior"])
render_kpi_row([
    {"label": "Total Revenue", "value": fmt_currency(df_kpis["revenue"]), "delta": delta_txt, "positive": is_pos},
    {"label": "Orders",        "value": fmt_number(df_kpis["orders"]),    "delta": "+3.2%",   "positive": True},
])

col1, col2 = st.columns(2)
with col1: render_chart(build_trend_chart(df_trend),    key="trend")
with col2: render_chart(build_category_chart(df_by_cat), key="category")

st.markdown("<div style='margin-top:8px'></div>", unsafe_allow_html=True)
render_table(df_by_cat, title="Detail View")
```
