LOGGING

All applications must use structured logging. Never use print() for diagnostic output.

Rules:
- Every .py file must import logger from _logger.py
- Use logger.info for normal flow milestones
- Use logger.error for all caught exceptions (always log before raising)
- Use logger.debug for intermediate values during development
- Never use print() — it disappears in Databricks Apps logs; logger output is captured

_logger.py (generate this file verbatim in every app):
import logging

def get_logger(name: str) -> logging.Logger:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    return logging.getLogger(name)

Usage in every module (first two lines after docstring):
from _logger import get_logger
logger = get_logger(__name__)

Log these events in data.py:
- Before spark.table(): logger.info(f"Loading: catalog.schema.table")
- After spark.table(): logger.info(f"Loaded {df.count()} rows from catalog.schema.table")
- On filter applied: logger.debug(f"Filter applied — {filtered_df.count()} rows remaining")
- On error: logger.error(f"Data access failed: {e}")

Log these events in logic.py:
- Start of each transformation: logger.info(f"Running: <transformation name>")
- Output row count: logger.debug(f"Result: {result.count()} rows")
- On error: logger.error(f"Transformation failed: {e}")

Log these events in app.py:
- App start: logger.info("App starting")
- Config loaded: logger.info(f"Config: {config}")
