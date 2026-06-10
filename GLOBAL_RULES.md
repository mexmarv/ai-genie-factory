GLOBAL RULES

All applications must:

- Run on Databricks (Databricks Apps for web apps, Notebooks for exploratory, DLT for pipelines)
- Read only from Gold layer Unity Catalog tables in UI-facing apps
- Reference all tables using three-part naming: catalog.schema.table
- Separate data, logic, and UI into distinct layers — no layer may contain logic from another
- Use ai-dev-kit patterns and components (https://github.com/databricks/ai-dev-kit)
- Define all data access via spark.table() in the data access module
- Apply central KPI definitions from the semantic layer — never recalculate a KPI that exists in the platform
- Respect Unity Catalog RBAC/ACLs — never bypass access controls or use service principals to elevate permissions

Architecture layers:

- Data layer: spark.table() reads only, Unity Catalog three-part names, no transformation logic
- Logic layer: aggregations, transformations, business rules — no SQL, no UI dependencies
- UI layer: Plotly charts using approved patterns, pandas conversion happens here only

Forbidden:

- Business logic in UI layer
- SQL outside the data access module
- Hardcoded values (catalog names, table names, thresholds)
- Reading from Bronze or Silver tables in UI-facing apps
- Redefining KPIs that exist in the semantic layer
- Creating custom components that duplicate ai-dev-kit patterns
- Bypassing Unity Catalog governance
