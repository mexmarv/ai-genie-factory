DLT PIPELINES

Use Delta Live Tables for all pipeline workloads. Never use raw notebooks for production ingestion.

Rules:
- Bronze: @dlt.table with Auto Loader (cloudFiles) as source — raw ingestion only
- Silver: @dlt.table with @dlt.expect quality gates — validated, SCD Type 2
- Gold: @dlt.materialized_view — aggregated, app-ready, Photon-optimized
- Always flow Bronze → Silver → Gold — never skip a layer
- Name tables with layer prefix: bronze_<source>, silver_<entity>, gold_<metric>
- Never use spark.read in DLT notebooks — use dlt.read() or dlt.read_stream()
- Use Databricks Volumes for all file source paths — no hardcoded DBFS paths
- Apply logging pattern from LOGGING module (import _logger, log row counts at each layer)

Bronze pattern (streaming Auto Loader):
import dlt
from _logger import get_logger
logger = get_logger(__name__)

@dlt.table(
    name="bronze_sales_orders",
    comment="Raw sales orders ingested from landing zone via Auto Loader"
)
def bronze_sales_orders():
    logger.info("Ingesting bronze_sales_orders from cloudFiles source")
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.schemaLocation", "/Volumes/catalog/schema/checkpoints/sales")
        .load("/Volumes/catalog/schema/raw/sales/")
    )

Silver pattern (with expectations and SCD tracking):
@dlt.table(
    name="silver_sales_orders",
    comment="Validated sales orders — nulls and negatives rejected"
)
@dlt.expect_or_drop("valid_order_id", "order_id IS NOT NULL")
@dlt.expect_or_drop("positive_amount", "amount > 0")
def silver_sales_orders():
    logger.info("Transforming silver_sales_orders")
    return (
        dlt.read_stream("bronze_sales_orders")
        .select("order_id", "order_date", "amount", "region", "sku")
    )

Gold pattern (materialized view):
@dlt.materialized_view(
    name="gold_sales_daily",
    comment="Daily sales totals by region — app-ready"
)
def gold_sales_daily():
    logger.info("Building gold_sales_daily")
    return (
        dlt.read("silver_sales_orders")
        .groupBy("order_date", "region")
        .agg({"amount": "sum"})
    )

Forbidden in DLT:
- spark.read() — use dlt.read() or dlt.read_stream()
- Business logic in Bronze tables (raw ingestion only)
- Hardcoded file paths — use Volumes (/Volumes/catalog/schema/path)
- Skipping the Silver layer to write directly from Bronze to Gold
