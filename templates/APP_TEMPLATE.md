APP NAME: [Descriptive name — used as the Databricks App title and displayed in the UI header]

Objective:
[One paragraph. What business question does this answer? Who uses it (role/team)?
How often? What decision does it enable?]

Data:
- [catalog.schema.table — full three-part Unity Catalog name]
- [catalog.schema.table — list ALL tables this app reads; reference Gold layer only]

Schema notes:
[For each non-obvious column, add a line:]
- column_name (type): description or value range
- struct_field.sub_field (type): how to access it (e.g., usage_metadata.cluster_id)
- column_name: enum values to filter on (e.g., status IN ('ACTIVE', 'PENDING'))
[If schema is self-explanatory, write "None"]

KPIs / Metrics:
[For each metric displayed in the app:]
- Metric name: how it's calculated — or "defined in semantic layer as [metric_name]"
- Metric name: ...
[If a metric exists in the semantic layer, reference it by name — do NOT recalculate it]

Transformations:
- Base filter: [WHERE clause shared by all queries in this app]
- [Transformation 1: group by / aggregate description]
- [Transformation 2: ...]
[Be explicit about: what to group by, what to aggregate, what to filter, what to sort/limit]

UI Components:
[List every visual component in render order:]
- [KPI card: what it shows, e.g., "Total revenue in selected period (formatted with commas)"]
- [Chart 1: type + axes + title, e.g., "Line chart — daily_revenue over order_date"]
- [Chart 2: type + axes + title]
- [Table: columns to show, row limit]
[If chart type not specified here, Genie Code will choose the most appropriate Plotly chart]

Filters:
- [Filter 1: type + default value, e.g., "Date range — default: last 30 days"]
- [Filter 2: type + default value, e.g., "Region dropdown — default: All regions"]
[If no filters: write "None"]

Design:
- Background: [hex color or "default dark (#0d1117)"]
- Color scheme: [primary + accent colors, or "blues and teals (primary #00bcd4)"]
- Plotly template: [plotly_dark / plotly_white / seaborn — or "plotly_dark"]
- Layout notes: [any specific layout requirements, or "default ai-dev-kit layout"]

Constraints:
[Any app-specific overrides to factory modules:]
- [e.g., "Use px.scatter_mapbox instead of standard px.bar for geographic data"]
[If no overrides: write "None beyond GLOBAL_RULES"]
