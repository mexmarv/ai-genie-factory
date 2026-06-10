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

## Reference Files

- `references/dash_patterns.md` — Full Dash app shell, CSS injection, callback pattern
- `references/streamlit_patterns.md` — Streamlit equivalent patterns
