---
name: databricks-dashboard
description: >
  Native Databricks AI/BI Lakeview Dashboard patterns for Alpura. Load when building,
  editing, or reviewing any Databricks Dashboard — dataset SQL queries, widget configuration,
  counter tiles, chart tiles, filter widgets, parameter references, layout, and markdown
  header tiles. Also load when the user asks about refreshing dashboards, sharing, embedding,
  scheduling, a P&L bridge, a waterfall chart, or any Custom Vega-Lite visualization not in
  Lakeview's built-in chart picker. Enforces Gold-layer-only datasets, parameterized SQL, and
  Alpura KPI conventions. Always pair with @databricks-dashboard-colors for theme/color
  tokens and @ui-ux-patterns for chart type decisions.
---

# Databricks AI/BI Dashboard Patterns — Alpura

Apply to every native Databricks Lakeview Dashboard. These run directly in the Databricks
workspace — no Python app needed. Always read from Gold layer tables only.

> Always load **@databricks-dashboard-colors** alongside this skill for the dashboard's dark/light
> theme tokens and visualization palette, set via the Lakeview Theme panel — not
> `@ui-ux-patterns`, which covers Python/Plotly Apps. Follow the **60-30-10 rule** for colors.
>
> For **conversational / natural language** interfaces on top of Gold tables, use Genie Spaces
> (managed via `manage_genie` MCP tool) instead of, or alongside, Lakeview Dashboards.

---

## Rules

- Datasets are SQL queries — always Gold layer (`prod.gold.*` or `system.*`)
- Every filter widget must use a named parameter — no hardcoded `WHERE` clauses
- Counter tiles show ONE metric with a comparison period
- Use dashboard-level filters, not per-tile filters, for date range and dimension slices
- Markdown tiles for section headers — never skip them in multi-section dashboards
- All SQL in datasets must be readable by the service principal running the refresh
- Never JOIN more than 3 tables in a single dataset — pre-join in Gold if needed
- Schedule refreshes for non-interactive dashboards — never leave manual-only for ops

---

## Dataset SQL Patterns

### Parameterized Date Filter

```sql
-- Dataset: daily_sales
-- Parameters: start_date (date), end_date (date), region (string, default='All')
SELECT
    order_date,
    region,
    SUM(amount)        AS total_sales,
    COUNT(order_id)    AS order_count,
    AVG(amount)        AS avg_order_value,
    SUM(amount) / NULLIF(LAG(SUM(amount)) OVER (ORDER BY order_date), 0) - 1 AS wow_growth
FROM prod.gold.sales_daily
WHERE order_date BETWEEN :start_date AND :end_date
  AND (:region = 'All' OR region = :region)
GROUP BY order_date, region
ORDER BY order_date
```

### KPI Comparison Dataset (Current vs Prior Period)

```sql
-- Dataset: kpi_summary
-- Computes current period metrics alongside prior period for delta display
WITH current_period AS (
    SELECT
        SUM(amount)     AS revenue,
        COUNT(order_id) AS orders,
        AVG(amount)     AS avg_order,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM prod.gold.sales_daily
    WHERE order_date BETWEEN :start_date AND :end_date
),
prior_period AS (
    SELECT
        SUM(amount)     AS revenue_prior,
        COUNT(order_id) AS orders_prior,
        AVG(amount)     AS avg_order_prior,
        COUNT(DISTINCT customer_id) AS customers_prior
    FROM prod.gold.sales_daily
    WHERE order_date BETWEEN
        DATEADD(day, -DATEDIFF(day, :start_date, :end_date) - 1, :start_date)
        AND DATEADD(day, -1, :start_date)
)
SELECT
    c.*,
    p.*,
    ROUND((c.revenue - p.revenue_prior) / NULLIF(p.revenue_prior, 0) * 100, 1) AS revenue_pct,
    ROUND((c.orders  - p.orders_prior)  / NULLIF(p.orders_prior,  0) * 100, 1) AS orders_pct
FROM current_period c, prior_period p
```

### Top N Ranking Dataset

```sql
-- Dataset: top_products
-- Parameter: top_n (integer, default=10)
SELECT
    sku,
    product_name,
    SUM(amount)        AS total_revenue,
    COUNT(order_id)    AS order_count,
    RANK() OVER (ORDER BY SUM(amount) DESC) AS revenue_rank
FROM prod.gold.sales_daily
WHERE order_date BETWEEN :start_date AND :end_date
GROUP BY sku, product_name
ORDER BY total_revenue DESC
LIMIT :top_n
```

### Time Series with Moving Average

```sql
-- Dataset: revenue_trend
SELECT
    order_date,
    SUM(amount)                                                        AS daily_revenue,
    AVG(SUM(amount)) OVER (ORDER BY order_date ROWS 6 PRECEDING)      AS ma_7d,
    AVG(SUM(amount)) OVER (ORDER BY order_date ROWS 29 PRECEDING)     AS ma_30d
FROM prod.gold.sales_daily
WHERE order_date BETWEEN
    DATEADD(day, -30, :start_date)  -- include lookback for moving avg
    AND :end_date
GROUP BY order_date
ORDER BY order_date
```

---

## Widget Configuration Guide

### Counter (KPI) Tile

```
Dataset:   kpi_summary
Field:     revenue
Title:     Total Revenue
Format:    Currency ($)
Comparison field:  revenue_prior
Comparison label:  vs prior period
Color rules:
  positive delta → #22c55e
  negative delta → #f43f5e
```

Counter tile rules:
- ONE metric per counter tile
- Always set a comparison field if prior period data is available
- Use `$` prefix for currency, `%` suffix for rates
- Title is the KPI label — keep under 24 chars

### Line / Area Chart Tile

```
Dataset:   revenue_trend
X axis:    order_date  (temporal)
Y axis:    daily_revenue
Series:    ma_7d (secondary line, dashed)
Chart type: Area
Color:     #00bcd4 (primary series — from @databricks-dashboard-colors)
Fill:      light (8% opacity)
Title:     Revenue Trend
```

### Horizontal Bar Chart Tile

```
Dataset:   top_products
X axis:    total_revenue
Y axis:    product_name
Sort:      descending by total_revenue
Color:     Single — #00bcd4
Title:     Top Products by Revenue
Show values: yes
```

### Pivot / Heatmap Tile

```
Dataset:   daily_sales (grouped by region × week)
Rows:      region
Columns:   week_start
Values:    total_sales (SUM)
Color scale: low=#111820 → high=#00bcd4
```

### Table Tile

```
Dataset:   daily_sales
Columns:   order_date, region, total_sales, order_count, avg_order_value
Sort:      order_date DESC
Row limit: 100
Formatting:
  total_sales → currency
  avg_order_value → currency
  wow_growth → percentage, color rule: pos=#22c55e neg=#f43f5e
```

---

## Filter Widget Setup

### Date Range Filter

```
Widget type:  Date range picker
Parameter:    start_date → end_date
Default:      last 30 days
Label:        Date Range
Apply to:     ALL datasets (set at dashboard level)
```

### Dropdown Filter (Single Select)

```
Widget type:  Dropdown (single select)
Parameter:    region
Dataset:      SELECT DISTINCT region FROM prod.gold.sales_daily ORDER BY 1
Default:      All
Include "All" option: yes
Label:        Region
```

### Multi-Select Filter

```
Widget type:  Multi-select
Parameter:    skus  (pass as comma-separated, handle in SQL with array_contains or IN)
Dataset:      SELECT sku, product_name FROM prod.gold.products ORDER BY product_name
Label:        Products
Max selections: 10
```

---

## Dashboard Layout Template

Always use the **Z-pattern** or **F-pattern** for creating hierarchy. Place the most important titles and filters top-left, and more detailed charts/tables bottom-right.

```
┌─────────────────────────────────────────────────────────────────┐
│  [Markdown header tile — App Name · Source · Last refreshed]    │
├───────────────┬────────────────────────────────────────────────-┤
│ [Filter bar: Date Range · Region · (more dropdowns)]            │
├───────────┬───────────┬───────────┬────────────────────────────-┤
│ Counter   │ Counter   │ Counter   │ Counter                     │
│ Revenue   │ Orders    │ Avg Order │ Customers                   │
├───────────┴───────────┴───────────┴────────────────────────────-┤
│  [Line/Area chart — Revenue Trend · full width · 40% height]    │
├──────────────────────────────┬──────────────────────────────────┤
│  [Bar chart — Top Products]  │  [Bar chart — By Region]         │
├──────────────────────────────┴──────────────────────────────────┤
│  [Table — Detail View · full width · last]                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Markdown Header Tile

```markdown
## App Name Dashboard
**Data source:** `prod.gold.sales_daily` · Unity Catalog  
**Grain:** Daily by region and SKU  
*Filters apply to all tiles. Last refreshed: {{REFRESH_TIME}}*
```

Markdown tile style:
- Use `##` heading — never `#` (too large)
- Always show data source table with full three-part name
- Always show grain (what one row represents)
- Background: transparent (inherits dashboard dark bg)

---

## Dashboard YAML Spec (for documentation / version control)

Document every dashboard in an `APP.md` equivalent:

```markdown
# Dashboard: [Name]

## Purpose
One sentence — what decision does this dashboard support?

## Audience
Who uses this? (Finance, Ops, Sales leadership, etc.)

## Data Sources
| Dataset name | Table | Grain | Refresh |
|---|---|---|---|
| daily_sales | prod.gold.sales_daily | day × region | hourly |
| kpi_summary | prod.gold.sales_daily | period aggregate | hourly |

## Parameters
| Name | Type | Default | Used by |
|---|---|---|---|
| start_date | date | -30d | all datasets |
| end_date | date | today | all datasets |
| region | string | All | daily_sales |

## Tiles
| Tile | Type | Dataset | Key metric |
|---|---|---|---|
| Total Revenue | Counter | kpi_summary | revenue vs revenue_prior |
| Revenue Trend | Area chart | revenue_trend | daily_revenue + ma_7d |
| Top Products | Bar | top_products | total_revenue |

## Refresh Schedule
Hourly 06:00–22:00 MXT. Service principal: sp-dashboard-reader.

## Permissions
Viewers: Finance team workspace group.
Owners: Data Engineering.
```

---

## Refresh & Scheduling

```
Recommended schedule: hourly during business hours (06:00–22:00 MXT)
Non-business dashboards: daily at 06:00 MXT
Real-time operational: 15-minute refresh (use streaming Gold tables)

Always set:
  - Notification on failure → data-engineering@alpura.com
  - Service principal for scheduled runs (not personal credentials)
  - Warehouse: Serverless SQL (lowest cost for scheduled refresh)
```

---

## Custom Visualizations (Vega-Lite) — P&L Waterfall Bridge

Lakeview's built-in chart type picker (Counter, Line/Area, Bar, Pivot, Table) has no native
waterfall/bridge chart. For P&L bridges, budget-vs-actuals, or cost breakdowns, use a
**Custom (Vega-Lite)** visualization widget instead of approximating one with a stacked bar.

> Sourced from **ALP-Waterfall v1.2.0**, Alpura's own community widget at
> [alpura.io/vizdbx](https://alpura.io/vizdbx) — reuse this spec rather than writing a new
> waterfall from scratch. VizDBX also publishes ALP Revenue Trend, ALP Sales by Category,
> ALP Sales vs Cost Matrix, and ALP Sales Donut — check there before building any custom
> chart type this skill doesn't already cover.

### Wiring it into a dashboard

1. Add a dataset whose SQL returns exactly the three Data Contract columns below, in the
   row order you want bars to appear (add an `ORDER BY` — Vega renders rows as supplied).
2. Add a visualization widget → **Custom (Vega-Lite)** → paste the spec JSON below.
3. The spec's `data.name` is `databricks_query` — Lakeview auto-binds your dataset to it;
   do not rename it.
4. It's a community spec, not an official Databricks widget — review the transform logic
   before production use like you would any code you didn't write yourself.

### Data contract

| Column | Type | Meaning |
|---|---|---|
| `category` | string | Bar label, rendered in the SQL's row order — order the query explicitly |
| `amount` | number | Delta value for that step (negative for a decrease) |
| `measure` | string | `'total'` anchors a bar to zero (start/end); any other value floats as a step |

```sql
-- Dataset: pl_bridge — ord controls left-to-right bar order
SELECT category, amount, measure
FROM (
  SELECT 'Inicio' AS category, :start_revenue AS amount, 'total' AS measure, 1 AS ord
  UNION ALL
  SELECT 'Ventas', delta_ventas, 'delta', 2 FROM prod.gold.pl_bridge_period
  UNION ALL
  SELECT 'COGS', delta_cogs, 'delta', 3 FROM prod.gold.pl_bridge_period
  -- ... one row per bridge step ...
  UNION ALL
  SELECT 'Total', :end_revenue, 'total', 99
)
ORDER BY ord
```

### Dark spec (default — `alpura-dashboard-dark`)

```json
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "_name": "ALP-Waterfall",
  "_version": "1.2.0",
  "_theme": "dark",
  "_description": "P&L bridge / waterfall chart with toggleable per-step arrows vs overall bridge. Dark theme — Alpura UX system. In Databricks AI/BI Dashboards, pass this as renderSpec.jsonSpec.spec stringified JSON; data.name must be 'databricks_query'.",
  "_data_contract": {
    "category": "string — bar label, ordered as supplied",
    "amount": "number — delta value",
    "measure": "string — 'total' anchors bar to zero; any other value = floating delta bar"
  },
  "_params": {
    "currencyPrefix": "string — default '$'",
    "unitSuffix": "string — default ' M'",
    "showAllArrows": "boolean — true shows every step arrow; false shows only first-to-last bridge"
  },
  "width": "container",
  "height": "container",
  "config": {
    "background": "#161b22",
    "autosize": { "type": "fit", "contains": "padding" },
    "view": { "stroke": null, "fill": "#161b22" },
    "axisY": {
      "gridColor": "#30363d",
      "domainOpacity": 0,
      "tickOpacity": 0,
      "labelColor": "#8b949e",
      "titleColor": "#8b949e"
    },
    "font": "Inter, system-ui"
  },
  "params": [
    { "name": "currencyPrefix", "value": "$" },
    { "name": "unitSuffix", "value": " M" },
    {
      "name": "showAllArrows",
      "value": true,
      "bind": { "input": "checkbox", "name": "Mostrar todas las flechas  " }
    }
  ],
  "data": { "name": "databricks_query" },
  "transform": [
    { "window": [{ "op": "row_number", "as": "order" }], "frame": [null, 0] },
    { "calculate": "datum.measure === 'total' ? 1 : 0", "as": "is_total" },
    {
      "window": [{ "op": "sum", "field": "is_total", "as": "seg" }],
      "sort": [{ "field": "order" }],
      "frame": [null, 0]
    },
    {
      "window": [{ "op": "sum", "field": "amount", "as": "run" }],
      "groupby": ["seg"],
      "sort": [{ "field": "order" }],
      "frame": [null, 0]
    },
    {
      "joinaggregate": [
        { "op": "max", "field": "amount", "as": "gmax_amt" },
        { "op": "count", "as": "gcount" }
      ]
    },
    { "calculate": "datum.measure === 'total' ? datum.amount : datum.run", "as": "sum" },
    {
      "calculate": "datum.measure === 'total' ? 0 : datum.run - datum.amount",
      "as": "previous_sum"
    },
    {
      "window": [{ "op": "lag", "field": "sum", "as": "prev_sum_col" }],
      "sort": [{ "field": "order" }],
      "frame": [null, null]
    },
    { "calculate": "datum.order > 1 ? datum.sum - datum.prev_sum_col : null", "as": "step_delta" },
    {
      "calculate": "datum.order > 1 ? (datum.sum - datum.prev_sum_col)/datum.prev_sum_col : null",
      "as": "step_pct"
    },
    { "joinaggregate": [{ "op": "max", "field": "sum", "as": "gmax" }] },
    {
      "calculate": "datum.measure === 'total' ? 'total' : (datum.amount >= 0 ? 'increase' : 'decrease')",
      "as": "cat_color"
    },
    {
      "calculate": "datum.measure === 'total' ? null : datum.amount / datum.previous_sum",
      "as": "pct_step"
    },
    { "calculate": "datum.order - 1", "as": "prev_x" },
    { "calculate": "datum.order + 1", "as": "next_x" },
    { "calculate": "datum.order - 0.5", "as": "cx" },
    {
      "calculate": "max(datum.prev_sum_col == null ? datum.sum : datum.prev_sum_col, datum.sum) + datum.gmax * 0.10",
      "as": "arrow_y"
    },
    { "calculate": "datum.gmax * 0.09", "as": "boxH" },
    { "calculate": "datum.arrow_y + datum.gmax * 0.02", "as": "box_y1" },
    { "calculate": "datum.box_y1 + datum.boxH", "as": "box_y2" },
    { "calculate": "(datum.box_y1 + datum.box_y2) / 2", "as": "box_cy" },
    { "calculate": "datum.box_cy + datum.boxH * 0.24", "as": "amt_y" },
    { "calculate": "datum.box_cy - datum.boxH * 0.24", "as": "pct_y" },
    { "calculate": "datum.cx - 0.34", "as": "bx1" },
    { "calculate": "datum.cx + 0.34", "as": "bx2" },
    {
      "calculate": "currencyPrefix + format(datum.sum, ',.0f') + unitSuffix",
      "as": "total_label"
    },
    {
      "calculate": "(datum.amount < 0 ? '−' : '+') + currencyPrefix + format(abs(datum.amount), ',.0f') + unitSuffix",
      "as": "amt_label"
    },
    {
      "calculate": "(datum.pct_step < 0 ? '−' : '+') + format(abs(datum.pct_step), '.1%')",
      "as": "pct_label"
    },
    {
      "calculate": "(datum.step_delta < 0 ? '−' : '+') + currencyPrefix + format(abs(datum.step_delta), ',.0f') + unitSuffix",
      "as": "bamt_label"
    },
    {
      "calculate": "(datum.step_pct < 0 ? '−' : '+') + format(abs(datum.step_pct), '.1%')",
      "as": "bpct_label"
    },
    {
      "window": [{ "op": "first_value", "field": "sum", "as": "firstTotal" }],
      "sort": [{ "field": "order" }],
      "frame": [null, null]
    },
    {
      "window": [{ "op": "last_value", "field": "sum", "as": "lastTotal" }],
      "sort": [{ "field": "order" }],
      "frame": [null, null]
    },
    { "calculate": "1", "as": "firstX" },
    { "calculate": "datum.gcount", "as": "lastX" },
    { "calculate": "(1 + datum.gcount)/2", "as": "cx_all" },
    { "calculate": "datum.gmax * 1.12", "as": "y_overall" },
    { "calculate": "datum.lastTotal - datum.firstTotal", "as": "overall_amt" },
    {
      "calculate": "(datum.lastTotal - datum.firstTotal)/datum.firstTotal",
      "as": "overall_pct"
    },
    { "calculate": "datum.y_overall + datum.gmax*0.02", "as": "obox_y1" },
    { "calculate": "datum.obox_y1 + datum.boxH", "as": "obox_y2" },
    { "calculate": "(datum.obox_y1 + datum.obox_y2)/2", "as": "obox_cy" },
    { "calculate": "datum.obox_cy + datum.boxH*0.24", "as": "oamt_y" },
    { "calculate": "datum.obox_cy - datum.boxH*0.24", "as": "opct_y" },
    { "calculate": "datum.cx_all - 0.40", "as": "obx1" },
    { "calculate": "datum.cx_all + 0.40", "as": "obx2" },
    {
      "calculate": "(datum.overall_amt < 0 ? '−' : '+') + currencyPrefix + format(abs(datum.overall_amt), ',.0f') + unitSuffix",
      "as": "oamt_label"
    },
    {
      "calculate": "(datum.overall_pct < 0 ? '−' : '+') + format(abs(datum.overall_pct), '.1%')",
      "as": "opct_label"
    }
  ],
  "encoding": {
    "x": {
      "field": "order",
      "type": "quantitative",
      "scale": { "padding": 60, "nice": false },
      "axis": {
        "title": "Concepto",
        "labels": false,
        "ticks": false,
        "grid": false,
        "domainColor": "#30363d",
        "titlePadding": 30,
        "titleColor": "#8b949e"
      }
    }
  },
  "layer": [
    {
      "transform": [{ "filter": "datum.next_x <= datum.gcount" }],
      "mark": { "type": "rule", "strokeWidth": 1, "strokeDash": [4, 3], "color": "#484f58" },
      "encoding": {
        "x": { "field": "order" },
        "x2": { "field": "next_x" },
        "y": { "field": "sum", "type": "quantitative" }
      }
    },
    {
      "mark": { "type": "bar", "size": 46, "stroke": "#0d1117", "strokeWidth": 1 },
      "encoding": {
        "y": {
          "field": "previous_sum",
          "type": "quantitative",
          "axis": {
            "title": "Importe (MXN)",
            "format": "~s",
            "labelColor": "#8b949e",
            "titleColor": "#8b949e"
          }
        },
        "y2": { "field": "sum" },
        "color": {
          "field": "cat_color",
          "type": "nominal",
          "scale": {
            "domain": ["total", "increase", "decrease"],
            "range": ["#00bcd4", "#26a641", "#f85149"]
          },
          "legend": null
        },
        "tooltip": [
          { "field": "category", "type": "nominal", "title": "Concepto" },
          { "field": "amount", "type": "quantitative", "title": "Importe", "format": ",.0f" },
          { "field": "sum", "type": "quantitative", "title": "Acumulado", "format": ",.0f" },
          { "field": "pct_step", "type": "quantitative", "title": "% vs. paso previo", "format": ".1%" }
        ]
      }
    },
    {
      "transform": [{ "filter": "datum.measure === 'total'" }],
      "mark": { "type": "text", "baseline": "bottom", "dy": -6, "fontWeight": "bold", "fontSize": 12, "color": "#e6edf3" },
      "encoding": {
        "x": { "field": "order" },
        "y": { "field": "sum", "type": "quantitative" },
        "text": { "field": "total_label" }
      }
    },
    {
      "transform": [{ "filter": "datum.order > 1 && showAllArrows && datum.step_delta != 0" }],
      "mark": { "type": "rule", "strokeWidth": 1.2, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "prev_x" },
        "x2": { "field": "order" },
        "y": { "field": "arrow_y", "type": "quantitative" }
      }
    },
    {
      "transform": [{ "filter": "datum.order > 1 && showAllArrows && datum.step_delta != 0" }],
      "mark": { "type": "rule", "strokeWidth": 1.2, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "prev_x" },
        "y": { "field": "arrow_y", "type": "quantitative" },
        "y2": { "field": "prev_sum_col" }
      }
    },
    {
      "transform": [{ "filter": "datum.order > 1 && showAllArrows && datum.step_delta != 0" }],
      "mark": { "type": "rule", "strokeWidth": 1.2, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "order" },
        "y": { "field": "arrow_y", "type": "quantitative" },
        "y2": { "field": "sum" }
      }
    },
    {
      "transform": [{ "filter": "datum.order > 1 && showAllArrows && datum.step_delta != 0" }],
      "mark": { "type": "point", "shape": "triangle-down", "filled": true, "size": 70, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "prev_x" },
        "y": { "field": "prev_sum_col", "type": "quantitative" }
      }
    },
    {
      "transform": [{ "filter": "datum.order > 1 && showAllArrows && datum.step_delta != 0" }],
      "mark": { "type": "point", "shape": "triangle-down", "filled": true, "size": 70, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "order" },
        "y": { "field": "sum", "type": "quantitative" }
      }
    },
    {
      "transform": [{ "filter": "datum.order > 1 && showAllArrows && datum.step_delta != 0" }],
      "mark": { "type": "rect", "fill": "#161b22", "stroke": "#30363d", "strokeWidth": 1, "cornerRadius": 4 },
      "encoding": {
        "x": { "field": "bx1" },
        "x2": { "field": "bx2" },
        "y": { "field": "box_y1", "type": "quantitative" },
        "y2": { "field": "box_y2" }
      }
    },
    {
      "transform": [{ "filter": "datum.order > 1 && showAllArrows && datum.step_delta != 0" }],
      "mark": { "type": "text", "align": "center", "fontWeight": "bold", "fontSize": 12, "color": "#e6edf3" },
      "encoding": {
        "x": { "field": "cx" },
        "y": { "field": "amt_y", "type": "quantitative" },
        "text": { "field": "bamt_label" }
      }
    },
    {
      "transform": [{ "filter": "datum.order > 1 && showAllArrows && datum.step_delta != 0" }],
      "mark": { "type": "text", "align": "center", "fontSize": 11, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "cx" },
        "y": { "field": "pct_y", "type": "quantitative" },
        "text": { "field": "bpct_label" }
      }
    },
    {
      "transform": [{ "filter": "datum.order == 1 && !showAllArrows" }],
      "mark": { "type": "rule", "strokeWidth": 1.2, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "firstX" },
        "x2": { "field": "lastX" },
        "y": { "field": "y_overall", "type": "quantitative" }
      }
    },
    {
      "transform": [{ "filter": "datum.order == 1 && !showAllArrows" }],
      "mark": { "type": "rule", "strokeWidth": 1.2, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "firstX" },
        "y": { "field": "y_overall", "type": "quantitative" },
        "y2": { "field": "firstTotal" }
      }
    },
    {
      "transform": [{ "filter": "datum.order == 1 && !showAllArrows" }],
      "mark": { "type": "rule", "strokeWidth": 1.2, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "lastX" },
        "y": { "field": "y_overall", "type": "quantitative" },
        "y2": { "field": "lastTotal" }
      }
    },
    {
      "transform": [{ "filter": "datum.order == 1 && !showAllArrows" }],
      "mark": { "type": "point", "shape": "triangle-down", "filled": true, "size": 80, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "firstX" },
        "y": { "field": "firstTotal", "type": "quantitative" }
      }
    },
    {
      "transform": [{ "filter": "datum.order == 1 && !showAllArrows" }],
      "mark": { "type": "point", "shape": "triangle-down", "filled": true, "size": 80, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "lastX" },
        "y": { "field": "lastTotal", "type": "quantitative" }
      }
    },
    {
      "transform": [{ "filter": "datum.order == 1 && !showAllArrows" }],
      "mark": { "type": "rect", "fill": "#161b22", "stroke": "#30363d", "strokeWidth": 1, "cornerRadius": 4 },
      "encoding": {
        "x": { "field": "obx1" },
        "x2": { "field": "obx2" },
        "y": { "field": "obox_y1", "type": "quantitative" },
        "y2": { "field": "obox_y2" }
      }
    },
    {
      "transform": [{ "filter": "datum.order == 1 && !showAllArrows" }],
      "mark": { "type": "text", "align": "center", "fontWeight": "bold", "fontSize": 13, "color": "#e6edf3" },
      "encoding": {
        "x": { "field": "cx_all" },
        "y": { "field": "oamt_y", "type": "quantitative" },
        "text": { "field": "oamt_label" }
      }
    },
    {
      "transform": [{ "filter": "datum.order == 1 && !showAllArrows" }],
      "mark": { "type": "text", "align": "center", "fontSize": 11, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "cx_all" },
        "y": { "field": "opct_y", "type": "quantitative" },
        "text": { "field": "opct_label" }
      }
    },
    {
      "mark": { "type": "text", "baseline": "top", "dy": 10, "fontSize": 12, "color": "#8b949e" },
      "encoding": {
        "x": { "field": "order" },
        "y": { "datum": 0 },
        "text": { "field": "category" }
      }
    }
  ]
}
```

### Light spec (`alpura-dashboard-light`)

`transform` and `layer` structure are identical to the dark spec above — Vega-Lite specs are
verbose enough that duplicating all ~900 lines here would just drift out of sync. Take the
dark spec and change only these three things:

1. **`config`** — replace with:
   ```json
   {
     "autosize": { "type": "fit", "contains": "padding" },
     "view": { "stroke": null },
     "axisY": { "gridColor": "#eceef0", "domainOpacity": 0, "tickOpacity": 0 },
     "font": "Helvetica, Arial, sans-serif"
   }
   ```
   (no `background`/`view.fill` override — the widget inherits the dashboard's light canvas)
2. **Bar `color.scale.range`** — replace `["#00bcd4", "#26a641", "#f85149"]` with
   `["#0E7C86", "#2E8B57", "#C0504D"]` (darker teal/green/red — the dark hues fail contrast
   on a white canvas).
3. **`boxH` calculate** — change `datum.gmax * 0.09` to `datum.gmax * 0.13`. Light mode's
   annotation boxes need more vertical padding for the text to read cleanly.

Every other `#e6edf3` / `#8b949e` / `#30363d` text and stroke color in `layer` stays as-is —
those already read fine against a white canvas at the opacities used here.

The dark spec's `total` and `decrease` colors (`#00bcd4`, `#f85149`) already match
`@databricks-dashboard-colors`' primary-series and negative-delta tokens exactly — this
widget was built against the same brand palette, so it composes cleanly with the rest of the
dashboard theme without further adjustment.

---

## Forbidden

- Datasets that read from `bronze_*` or `silver_*` tables
- `SELECT *` in dataset SQL — always explicit column list
- Per-tile date filters — use dashboard-level parameters
- Pie charts — use bar or counter tiles
- More than 3 JOINs in a single dataset SQL
- Hardcoded date ranges (`WHERE order_date > '2024-01-01'`)
- Sharing dashboards with "Can edit" to non-owners
