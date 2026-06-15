STACK

Runtime:
- Databricks (unified platform for all workloads)
- Databricks Apps for web application deployment
- Delta Live Tables (DLT) for pipeline workloads

Language:
- Python

UI:
- Plotly (plotly.express) for all charts and visualizations

Data Access:
- Notebooks and DLT: spark.table() for all reads
- Databricks Apps: databricks-sdk WorkspaceClient + Statement Execution API (no Spark session in Apps runtime)
- Unity Catalog three-part table names: catalog.schema.table in both runtimes
- Gold layer tables only in UI-facing apps
- Delta Lake as the table format

Data Architecture:
- Medallion: Bronze (raw ingestion) → Silver (validated, SCD Type 2) → Gold (aggregated, app-ready)
- Gold tables are materialized views or Photon-optimized Delta tables with star schema
- Semantic layer via dbxs metrics registered in Unity Catalog metrics store

Governance:
- Unity Catalog for lineage, access control, and discoverability
- RBAC with attribute-based policies
- Column-level lineage and impact analysis via Unity Catalog

Libraries:
- ai-dev-kit: https://github.com/databricks/ai-dev-kit
