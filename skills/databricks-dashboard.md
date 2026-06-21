---
name: databricks-dashboard
description: >
  Native Databricks AI/BI Lakeview Dashboard patterns for Alpura. Load when building,
  editing, or reviewing any Databricks Dashboard — dataset SQL queries, widget configuration,
  counter tiles, chart tiles, filter widgets, parameter references, layout, and markdown
  header tiles. Also load when the user asks about refreshing dashboards, sharing, embedding,
  or scheduling. Enforces Gold-layer-only datasets, parameterized SQL, and Alpura KPI
  conventions. Always pair with @ui-ux-patterns for color and chart type decisions.
---

# Databricks AI/BI Dashboard Patterns — Alpura

Apply to every native Databricks Lakeview Dashboard. These run directly in the Databricks
workspace — no Python app needed. Always read from Gold layer tables only.

> Always load **@ui-ux-patterns** alongside this skill for color tokens and chart type rules. Follow the **60-30-10 rule** for colors and use **DM Sans** for your title fonts.
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
Color:     #00bcd4 (accent cyan — from @ui-ux-patterns SEQ)
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

## Forbidden

- Datasets that read from `bronze_*` or `silver_*` tables
- `SELECT *` in dataset SQL — always explicit column list
- Per-tile date filters — use dashboard-level parameters
- Pie charts — use bar or counter tiles
- More than 3 JOINs in a single dataset SQL
- Hardcoded date ranges (`WHERE order_date > '2024-01-01'`)
- Sharing dashboards with "Can edit" to non-owners
