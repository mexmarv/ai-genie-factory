UI PATTERNS

All UI must use Plotly (plotly.express). No other charting library.

Rules:
- Convert Spark DataFrames to pandas only in this layer (never in data or logic layers)
- Use ai-dev-kit layout components for app shell, filters, and layout
- Keep chart functions pure: accept a pandas DataFrame, return a Plotly figure
- If APP.md specifies a chart type, use it exactly
- If APP.md does not specify a chart type, choose the most appropriate Plotly chart for the data and metric

Chart type guidance (use judgment when not specified):
- Trends over time → px.line
- Comparisons by category → px.bar
- Part-of-whole → px.pie or px.treemap
- Distribution → px.histogram or px.box
- Correlation → px.scatter
- Ranked lists → px.bar (horizontal)

Pandas conversion (UI layer only):
df_pandas = df.toPandas()

Filter pattern (date range):
df_filtered = df.filter((col("date_col") >= start_date) & (col("date_col") <= end_date))
# Convert to pandas after filtering, not before
