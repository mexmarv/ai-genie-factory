UX/UI DESIGN SYSTEM

All Databricks Apps must use these exact values. Never invent colors, fonts, or spacing per app.

COLORS — always reference by token name in comments, use hex in code:
- Background (app canvas):   #0d1117
- Card / panel background:   #161b22
- Elevated (dropdowns/hover):#1c2128
- Border / divider:          #30363d
- Text primary (headlines):  #e6edf3
- Text secondary (labels):   #8b949e
- Text muted (placeholders): #484f58
- Accent blue (primary CTA): #00bcd4
- Accent purple (secondary): #7c4dff
- Positive / success green:  #26a641
- Negative / error red:      #f85149
- Warning orange:            #e3b341
- Alpura brand blue:         #003087  (use sparingly — headers only)

PLOTLY THEME — apply to every figure, no exceptions:
fig.update_layout(
    template="plotly_dark",
    paper_bgcolor="#161b22",
    plot_bgcolor="#161b22",
    font=dict(family="Inter, system-ui", color="#8b949e", size=11),
    margin=dict(l=40, r=20, t=40, b=40),
    title_font=dict(size=13, color="#e6edf3"),
    xaxis=dict(gridcolor="#30363d", linecolor="#30363d"),
    yaxis=dict(gridcolor="#30363d", linecolor="#30363d"),
)

CHART COLOR SEQUENCES — use these, never default Plotly colors:
- Sequential (single metric): ["#00bcd4","#00a8bb","#0094a3","#00808b","#006c74"]
- Categorical (multi-series): ["#00bcd4","#7c4dff","#26a641","#e3b341","#f85149"]
- Diverging (pos/neg):        ["#f85149","#e3b341","#26a641"]

CHART TYPE RULES:
- Trend over time        → px.line, fill="tozeroy", color="#00bcd4"
- Category comparison    → px.bar horizontal, sorted descending, color="#00bcd4"
- Part of whole          → px.treemap (never px.pie — unreadable on dark bg)
- Distribution           → px.histogram, color="#00bcd4"
- Multi-metric over time → go.Figure with make_subplots, shared x-axis

APP LAYOUT ORDER — always this sequence, never reordered:
1. App header (title + data source subtitle)
2. Filter bar (date range + dropdowns, horizontal)
3. KPI row (3–4 metric cards, full width, flex row)
4. Chart row(s) (max 2 charts side by side per row)
5. Data table (optional, always last)

KPI CARD — standard pattern for every metric card:
- Background: #161b22, border: 1px solid #30363d, border-radius: 8px, padding: 16px
- Label: 12px, color #8b949e, margin-bottom 4px
- Value: 36–48px, color #e6edf3, font-weight 700
- Delta: 12px, color #26a641 if positive, #f85149 if negative
- Format large numbers: 1,234,567 → "1.2M" | 12,345 → "12.3K"

APP SHELL BACKGROUND — always set on outermost container:
style={"background": "#0d1117", "minHeight": "100vh", "padding": "24px"}

FORBIDDEN:
- Light backgrounds — never use white or light grey as app background
- Default Plotly blue #636efa — always override with #00bcd4
- px.pie charts — use px.treemap
- Raw hex values without a comment identifying the token
- Per-app invented colors outside the token set above
