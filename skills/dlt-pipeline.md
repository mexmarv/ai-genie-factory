---
name: dlt-pipeline
description: >
  Delta Live Tables pipeline patterns for Alpura's Medallion architecture. Load when
  building or reviewing any DLT pipeline, ingestion notebook, Bronze/Silver/Gold table
  definitions, streaming pipeline code, CDC patterns, or SCD Type 2 slowly changing
  dimensions. Also load when the user mentions Auto Loader, DLT expectations, APPLY
  CHANGES INTO, schema evolution, checkpoint management, pipeline settings, or Photon.
  Enforces Bronze→Silver→Gold flow, quality expectations at every Silver table,
  Databricks Volumes for all file paths, and no spark.read() inside DLT.
---

# DLT Pipeline Patterns — Alpura Medallion Architecture

Apply to every DLT pipeline notebook. Pipelines always flow Bronze → Silver → Gold.
Never skip Silver. Never write business logic in Bronze.

---

## Rules

- **Bronze**: raw ingestion via Auto Loader — no transformations, no filtering
- **Silver**: validated, deduped, cleaned — `@dlt.expect_or_drop` on every quality dimension
- **Gold**: aggregated, app-ready, business-metric-named — `@dlt.materialized_view` preferred
- Never skip Silver — no Bronze → Gold directly
- Always use Databricks Volumes (`/Volumes/catalog/schema/path`) — never `dbfs:/`
- Use `dlt.read()` / `dlt.read_stream()` — never `spark.read()` inside DLT
- Name tables: `bronze_<source>`, `silver_<entity>`, `gold_<metric>`
- Log ingestion count and key metrics at every layer — use `_logger.py`
- All pipeline code runs in DLT notebooks — never in regular notebooks
- Schema evolution: use `cloudFiles.schemaEvolutionMode = "rescue"` at Bronze

---

## Bronze — Auto Loader Ingestion

### JSON / CSV from Volumes

```python
import dlt
from pyspark.sql import functions as F
from _logger import get_logger
logger = get_logger(__name__)

@dlt.table(
    name="bronze_sales_orders",
    comment="Raw sales orders — Auto Loader ingestion from Volumes landing zone",
    table_properties={"quality": "bronze", "pipelines.reset.allowed": "true"},
)
def bronze_sales_orders():
    logger.info("Ingesting bronze_sales_orders")
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.schemaLocation",  "/Volumes/prod/raw/checkpoints/sales_orders_schema")
        .option("cloudFiles.schemaEvolutionMode", "rescue")   # new columns → _rescued_data
        .option("cloudFiles.inferColumnTypes", "true")
        .load("/Volumes/prod/raw/landing/sales_orders/")
        .withColumn("_ingested_at",  F.current_timestamp())
        .withColumn("_source_file",  F.input_file_name())
    )
```

### Parquet / Delta from Volumes

```python
@dlt.table(name="bronze_inventory", comment="Raw inventory snapshots from ERP export")
def bronze_inventory():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "parquet")
        .option("cloudFiles.schemaLocation", "/Volumes/prod/raw/checkpoints/inventory_schema")
        .load("/Volumes/prod/raw/landing/inventory/")
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_source_file", F.input_file_name())
    )
```

### Kafka / Event Hub Streaming Source

```python
@dlt.table(name="bronze_events", comment="Real-time events from Kafka")
def bronze_events():
    return (
        spark.readStream.format("kafka")
        .option("kafka.bootstrap.servers", spark.conf.get("kafka.bootstrap.servers"))
        .option("subscribe", "alpura.sales.events")
        .option("startingOffsets", "latest")
        .load()
        .select(
            F.col("key").cast("string").alias("event_key"),
            F.from_json(F.col("value").cast("string"), EVENT_SCHEMA).alias("payload"),
            F.col("timestamp").alias("kafka_timestamp"),
            F.current_timestamp().alias("_ingested_at"),
        )
        .select("event_key", "payload.*", "kafka_timestamp", "_ingested_at")
    )
```

---

## Silver — Quality Gates & Transformations

### Standard Quality Gates

```python
@dlt.table(
    name="silver_sales_orders",
    comment="Validated sales orders — deduped, typed, quality-gated",
    table_properties={"quality": "silver", "delta.enableChangeDataFeed": "true"},
)
@dlt.expect_or_drop("valid_order_id",    "order_id IS NOT NULL AND order_id != ''")
@dlt.expect_or_drop("positive_amount",   "amount > 0")
@dlt.expect_or_drop("valid_order_date",  "order_date IS NOT NULL AND order_date <= current_date()")
@dlt.expect_or_drop("valid_region",      "region IN ('North','South','East','West','Central')")
@dlt.expect("complete_customer",         "customer_id IS NOT NULL")   # metric only, keep row
def silver_sales_orders():
    logger.info("Transforming silver_sales_orders")
    return (
        dlt.read_stream("bronze_sales_orders")
        .select(
            F.col("order_id").cast("string"),
            F.to_date("order_date", "yyyy-MM-dd").alias("order_date"),
            F.col("amount").cast("decimal(18,2)"),
            F.trim(F.upper("region")).alias("region"),
            F.col("sku").cast("string"),
            F.col("customer_id").cast("string"),
            F.col("_ingested_at"),
            F.col("_source_file"),
        )
        .dropDuplicates(["order_id"])   # dedup on natural key
        .withColumn("silver_loaded_at", F.current_timestamp())
    )
```

### Expectation Decorator Reference

| Decorator | On violation | When to use |
|---|---|---|
| `@dlt.expect` | Keep row, record metric | Non-critical — alerting only |
| `@dlt.expect_or_drop` | Drop violating row | Data quality gate — default for Silver |
| `@dlt.expect_or_fail` | Fail entire pipeline | Critical — amount, order_id null |
| `@dlt.expect_all` | Keep row, record all | Batch of soft checks |
| `@dlt.expect_all_or_drop` | Drop if any fails | Strict multi-rule gate |
| `@dlt.expect_all_or_fail` | Fail if any fails | Non-negotiable data contracts |

---

## CDC — APPLY CHANGES INTO (SCD Type 1)

Use when the source sends change events (inserts + updates + deletes).

```python
# Target table declaration — must exist before APPLY CHANGES
dlt.create_streaming_table(
    name="silver_customers",
    comment="Current customer state — CDC from CRM system (SCD Type 1)",
    table_properties={"quality": "silver", "delta.enableChangeDataFeed": "true"},
    expect_all_or_drop={
        "valid_customer_id": "customer_id IS NOT NULL",
        "valid_email":       "email RLIKE '^[^@]+@[^@]+\\\\.[^@]+$'",
    },
)

dlt.apply_changes(
    target      = "silver_customers",
    source      = "bronze_customers_cdc",    # CDC source with _change_type column
    keys        = ["customer_id"],
    sequence_by = F.col("updated_at"),       # monotonically increasing timestamp
    ignore_null_updates = True,              # don't overwrite with NULLs
    apply_as_deletes = F.expr("_change_type = 'DELETE'"),
    apply_as_truncates = F.expr("_change_type = 'TRUNCATE'"),
    column_list = ["customer_id","name","email","region","segment","updated_at"],
    except_column_list = ["_rescued_data","_ingested_at","_source_file"],
)
```

---

## SCD Type 2 — History Tracking

Use when you need full change history (price changes, customer reclassifications, etc.).

```python
# SCD2 target — stores all versions with effective date range
dlt.create_streaming_table(
    name="silver_products_scd2",
    comment="Product dimension with full change history — SCD Type 2",
    table_properties={"quality": "silver"},
)

dlt.apply_changes(
    target       = "silver_products_scd2",
    source       = "bronze_products_cdc",
    keys         = ["product_id"],
    sequence_by  = F.col("updated_at"),
    stored_as_scd_type = 2,             # magic: Databricks handles start/end dates
    # Adds: __START_AT, __END_AT columns automatically
    column_list  = ["product_id","sku","name","price","category","updated_at"],
)
```

Querying SCD2 history:

```sql
-- Current state
SELECT * FROM prod.silver.silver_products_scd2 WHERE __END_AT IS NULL;

-- Point-in-time lookup
SELECT * FROM prod.silver.silver_products_scd2
WHERE product_id = '123'
  AND '2024-06-01' BETWEEN __START_AT AND COALESCE(__END_AT, current_date());
```

---

## Gold — Materialized Views

```python
@dlt.materialized_view(
    name="gold_sales_daily",
    comment="Daily sales by region — app-ready, Photon-optimised",
    table_properties={"quality": "gold"},
)
def gold_sales_daily():
    logger.info("Building gold_sales_daily")
    return (
        dlt.read("silver_sales_orders")
        .groupBy("order_date", "region")
        .agg(
            F.sum("amount").alias("total_sales"),
            F.count("order_id").alias("order_count"),
            F.avg("amount").alias("avg_order_value"),
            F.countDistinct("customer_id").alias("unique_customers"),
            F.countDistinct("sku").alias("unique_skus"),
        )
    )

@dlt.materialized_view(
    name="gold_customer_ltv",
    comment="Customer lifetime value — rolling 12-month aggregate",
    table_properties={"quality": "gold"},
)
def gold_customer_ltv():
    return (
        dlt.read("silver_sales_orders")
        .filter(F.col("order_date") >= F.add_months(F.current_date(), -12))
        .groupBy("customer_id")
        .agg(
            F.sum("amount").alias("ltv_12m"),
            F.count("order_id").alias("order_count_12m"),
            F.max("order_date").alias("last_order_date"),
            F.min("order_date").alias("first_order_date"),
        )
        .withColumn("customer_segment",
            F.when(F.col("ltv_12m") >= 100_000, "Platinum")
             .when(F.col("ltv_12m") >= 50_000,  "Gold")
             .when(F.col("ltv_12m") >= 10_000,  "Silver")
             .otherwise("Bronze"))
    )
```

---

## Multi-Hop Join at Gold

```python
@dlt.materialized_view(
    name="gold_sales_enriched",
    comment="Sales joined with product and customer dimensions — fully enriched",
    table_properties={"quality": "gold"},
)
def gold_sales_enriched():
    sales    = dlt.read("silver_sales_orders")
    products = dlt.read("silver_products_scd2").filter(F.col("__END_AT").isNull())  # current only
    customers= dlt.read("silver_customers")

    return (
        sales
        .join(products,  on="sku",         how="left")
        .join(customers, on="customer_id", how="left")
        .select(
            "order_id", "order_date", "amount", "region",
            "product_name", "category", "price",
            "customer_id", sales["name"].alias("customer_name"), "segment",
            "silver_loaded_at",
        )
    )
```

---

## Streaming vs Batch Mode

```python
# Streaming — use for real-time / near-real-time (Kafka, Auto Loader)
dlt.read_stream("bronze_sales_orders")    # incremental, processes new records only

# Batch — use for static lookups, full Gold rebuilds
dlt.read("silver_products_scd2")          # full table scan each pipeline run

# Mixed: streaming fact + batch dimension join is valid at Gold
```

---

## Schema Evolution

```python
# Bronze: allow new columns with rescue
.option("cloudFiles.schemaEvolutionMode", "rescue")
# New columns land in _rescued_data — review and promote to Silver explicitly

# Silver: handle schema changes via ALTER TABLE or pipeline schema evolution
# Set in pipeline settings:
#   "pipelines.autoOptimize.managed": "true"
#   "spark.databricks.delta.schema.autoMerge.enabled": "true"
```

---

## Pipeline Settings (JSON)

Configure in the pipeline UI under "Advanced configuration":

```json
{
  "spark.databricks.delta.schema.autoMerge.enabled": "true",
  "pipelines.autoOptimize.managed": "true",
  "spark.sql.shuffle.partitions": "auto",
  "pipelines.clusterShutdown.delay": "60s"
}
```

Recommended cluster config:

```json
{
  "num_workers": 2,
  "spark_version": "latest",
  "node_type_id": "Standard_D8ds_v5",
  "photon_type": "PHOTON",
  "autoscale": {
    "min_workers": 1,
    "max_workers": 4
  }
}
```

**Serverless DLT is the default for all new pipelines** (faster startup, no cluster config,
auto-scales, Photon enabled by default):

```json
{
  "serverless": true,
  "channel": "CURRENT"
}
```

Classic compute only when serverless is unavailable in the region or cost constraints apply.

---

## Checkpoint Management

```
Checkpoint locations — always use Volumes, never DBFS:
  /Volumes/{catalog}/raw/checkpoints/{table_name}_schema   ← Auto Loader schema
  /Volumes/{catalog}/raw/checkpoints/{table_name}_cp       ← Stream checkpoint

Never delete checkpoints without a full pipeline reset.
To reset: pipeline settings → Full Refresh → confirm.
Resetting Bronze: wipes state, re-ingests all files — expensive for large datasets.
```

---

## Monitoring Expectations

```python
# Query expectation metrics after a pipeline run
SELECT
    timestamp,
    pipeline_id,
    name AS expectation_name,
    dataset,
    passed_records,
    failed_records,
    ROUND(failed_records * 100.0 / NULLIF(passed_records + failed_records, 0), 2) AS failure_pct
FROM system.lakeflow.pipeline_events
WHERE event_type = 'flow_progress'
  AND timestamp >= DATEADD(day, -7, current_timestamp())
ORDER BY timestamp DESC
```

Alert threshold: `failure_pct > 5%` on any Silver table → PagerDuty / email.

---

## Testing DLT Pipelines

DLT notebooks can't be unit-tested directly. Use this pattern:

```python
# tests/test_silver_transforms.py
# Extract transform logic into pure functions in a separate module, test those

import pytest
import pandas as pd
from pyspark.sql import SparkSession

@pytest.fixture(scope="session")
def spark():
    return SparkSession.builder.master("local[2]").appName("dlt-tests").getOrCreate()

def test_silver_orders_drops_null_order_id(spark):
    raw = spark.createDataFrame([
        ("ORD001", "2024-01-01", 100.0, "North"),
        (None,     "2024-01-02", 200.0, "South"),   # should be dropped
    ], ["order_id", "order_date", "amount", "region"])
    result = raw.filter("order_id IS NOT NULL AND order_id != ''")
    assert result.count() == 1

def test_silver_orders_drops_negative_amounts(spark):
    raw = spark.createDataFrame([
        ("ORD001", "2024-01-01",  100.0, "North"),
        ("ORD002", "2024-01-02", -50.0,  "South"),  # should be dropped
    ], ["order_id", "order_date", "amount", "region"])
    result = raw.filter("amount > 0")
    assert result.count() == 1
```

---

## DLT Pipeline YAML Spec (APP.md equivalent)

Document every pipeline before building:

```markdown
# Pipeline: [Name]

## Purpose
What business process does this pipeline serve?

## Schedule
Triggered / Continuous / Cron: "0 * * * *"

## Sources
| Layer | Type | Format | Location |
|---|---|---|---|
| Landing | Auto Loader | JSON | /Volumes/prod/raw/landing/sales_orders/ |

## Tables
| Name | Layer | Type | Key columns | Quality gates |
|---|---|---|---|---|
| bronze_sales_orders | Bronze | Streaming | — | none |
| silver_sales_orders | Silver | Streaming | order_id | 4 expect_or_drop |
| gold_sales_daily | Gold | Materialized view | order_date, region | inherited |

## CDC / SCD
[ ] No CDC   [ ] SCD Type 1 (APPLY CHANGES)   [ ] SCD Type 2

## Compute
[ ] Serverless   [ ] Classic (node type: ___)

## Alerts
Failure → data-engineering@alpura.com
Expectation failure_pct > 5% → PagerDuty
```

---

## Forbidden

- `spark.read()` inside DLT notebooks — use `dlt.read()` or `dlt.read_stream()`
- Business logic or aggregations in Bronze tables
- Hardcoded `dbfs:/` paths — use `/Volumes/catalog/schema/path`
- Skipping Silver — Bronze directly to Gold
- `SELECT *` at Silver without explicit column list
- Missing `@dlt.expect_or_drop` on null-intolerant key columns at Silver
- `df.count()` inside DLT table functions — expensive, triggers full scan
- Deleting checkpoints without a Full Refresh pipeline run
- Using regular notebooks instead of DLT pipeline notebooks for pipeline logic
