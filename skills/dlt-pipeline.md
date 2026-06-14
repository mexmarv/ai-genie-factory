---
name: dlt-pipeline
description: >
  Delta Live Tables pipeline patterns for Alpura's Medallion architecture. Load when
  building or reviewing any DLT pipeline, ingestion notebook, Bronze/Silver/Gold table
  definitions, or streaming pipeline code. Also load when the user mentions Auto Loader,
  DLT expectations, CDC, SCD Type 2, or materialised views.
  Enforces Bronze→Silver→Gold flow, Auto Loader for ingestion, quality expectations,
  and Databricks Volumes for file paths.
---

# DLT Pipeline Patterns — Medallion Architecture

Apply to every DLT pipeline notebook. Pipelines always flow Bronze → Silver → Gold.

## Rules

- Bronze: raw ingestion via Auto Loader — no transformations
- Silver: validated, cleaned, SCD Type 2 — use `@dlt.expect_or_drop` for quality gates
- Gold: aggregated, app-ready — use `@dlt.materialized_view` where possible
- Never skip Silver — no Bronze → Gold directly
- Always use Databricks Volumes for file paths — never hardcoded DBFS paths
- Use `dlt.read()` / `dlt.read_stream()` — never `spark.read()` inside DLT
- Name tables: `bronze_<source>`, `silver_<entity>`, `gold_<metric>`

## Bronze — Auto Loader

```python
import dlt
from _logger import get_logger
logger = get_logger(__name__)

@dlt.table(
    name="bronze_sales_orders",
    comment="Raw sales orders — Auto Loader ingestion from landing Volumes"
)
def bronze_sales_orders():
    logger.info("Ingesting bronze_sales_orders")
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.schemaLocation",
                "/Volumes/prod/raw/checkpoints/sales_orders")
        .load("/Volumes/prod/raw/landing/sales_orders/")
    )
```

## Silver — Quality Gates

```python
@dlt.table(
    name="silver_sales_orders",
    comment="Validated sales orders — nulls and negatives rejected"
)
@dlt.expect_or_drop("valid_order_id",  "order_id IS NOT NULL")
@dlt.expect_or_drop("positive_amount", "amount > 0")
@dlt.expect_or_drop("valid_date",      "order_date IS NOT NULL")
def silver_sales_orders():
    logger.info("Transforming silver_sales_orders")
    return (
        dlt.read_stream("bronze_sales_orders")
        .select("order_id","order_date","amount","region","sku","customer_id")
        .withColumn("ingested_at", F.current_timestamp())
    )
```

## Gold — Materialised View

```python
@dlt.materialized_view(
    name="gold_sales_daily",
    comment="Daily sales by region — app-ready, Photon-optimised"
)
def gold_sales_daily():
    logger.info("Building gold_sales_daily")
    return (
        dlt.read("silver_sales_orders")
        .groupBy("order_date", "region")
        .agg(
            F.sum("amount").alias("total_sales"),
            F.count("order_id").alias("order_count")
        )
    )
```

## Expectations Reference

| Decorator | Behaviour on violation |
|---|---|
| `@dlt.expect` | Record metric, keep row |
| `@dlt.expect_or_drop` | Drop violating rows |
| `@dlt.expect_or_fail` | Fail the entire pipeline |

## Forbidden

- `spark.read()` inside DLT notebooks — use `dlt.read()` or `dlt.read_stream()`
- Business logic in Bronze tables
- Hardcoded `dbfs:/` paths — use `/Volumes/catalog/schema/path`
- Skipping Silver to write Bronze directly to Gold
