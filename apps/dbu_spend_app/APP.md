APP NAME: DBU Spend Monitor

Objective:
Visualize Databricks Unit (DBU) consumption over time and by cluster with a polished dark-themed dashboard.

Data:
- system.billing.usage

Schema notes:
- DBU consumption column: usage_quantity (decimal)
- Date column: usage_date (date)
- Cluster identifier: usage_metadata.cluster_id (nullable struct sub-field — access as usage_metadata.cluster_id)
- Filter to DBU records only: usage_unit = 'DBU'
- Filter to original records only: record_type = 'ORIGINAL' (exclude RETRACTION and RESTATEMENT to avoid double-counting)

Metrics:
- Total DBUs consumed per day
- Total DBUs consumed per cluster (top 10 by usage, exclude nulls)
- Grand total DBUs in selected period (KPI card)

Transformations:
- Base filter: WHERE usage_unit = 'DBU' AND record_type = 'ORIGINAL'
- Time series: group by usage_date → sum(usage_quantity) as total_dbus
- By cluster: group by usage_metadata.cluster_id → sum(usage_quantity) as total_dbus, filter where usage_metadata.cluster_id IS NOT NULL, order by total_dbus DESC, limit 10
- KPI total: sum(usage_quantity) across entire filtered dataset

UI:
- KPI card at the top: total DBUs in period (large bold number, formatted with commas)
- Line chart: total_dbus over usage_date — smooth trend line, filled area under the curve
- Bar chart: top 10 clusters by total_dbus — horizontal bars, sorted descending, cluster_id as label

Filters:
- Date range (default: last 30 days)

Design:
- Dark background (#0d1117 or similar near-black)
- Color scheme: blues and teals (primary #00bcd4, accent #7c4dff)
- Use plotly_dark template for all charts
- Chart titles in bold, axis labels clean and minimal
- KPI card: large font, contrasting accent color, subtitle showing date range
- Hover tooltips: formatted numbers with comma separators, include date/cluster label
- Consistent padding and spacing between components using ai-dev-kit layout
- App title: "DBU Spend Monitor" with subtitle "Powered by system.billing.usage"

Constraints:
- None beyond GLOBAL_RULES
