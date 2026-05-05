DATA ACCESS

All data access must be defined in this module. No other layer may read from tables directly.

Rules:
- Use spark.table() for all reads
- Always use three-part Unity Catalog naming: catalog.schema.table
- Read from Gold layer tables in UI-facing apps
- No SQL, no JDBC, no hardcoded table paths

Pattern:
df = spark.table("catalog.schema.table")

Example (system catalog — available in all workspaces):
df = spark.table("system.billing.usage")

Example (Gold table):
df = spark.table("prod.gold.sales_daily")

Filtering (do it here, before passing to the logic layer):
df = spark.table("prod.gold.sales_daily").filter("usage_date >= '2024-01-01'")
