---
name: databricks-app
description: >
  Full Databricks Apps architecture for Alpura — Dash and Streamlit apps deployed on
  Databricks App Service. Load when building, reviewing, or deploying any Databricks App:
  file structure, app.yaml, requirements.txt, service principal auth, environment config,
  data/logic/ui/app layer architecture, SQL warehouse connectivity, deployment commands,
  debug patterns, and live reload. Also load when the user asks about app.yaml, permissions,
  service principals, why the app won't start, or how to deploy. Always pair with
  @ui-ux-patterns for all visual components and chart functions.
---

# Databricks App Architecture — Alpura

Apply to every Databricks App (Dash or Streamlit) built at Alpura.

> Source of truth for auth and connectivity patterns: https://github.com/databricks-solutions/ai-dev-kit/tree/main/databricks-skills/databricks-apps-python

---

## Rules

- Every app follows the 5-file layer architecture: `data.py / logic.py / ui.py / app.py / _logger.py`
- `data.py` queries UC tables via `databricks-sql-connector` + `Config()` credentials provider — **NO `spark`, NO `WorkspaceClient().statement_execution`**
- `logic.py` transforms only — pandas DataFrames, no Spark, no UI imports
- `ui.py` renders only — Plotly figures, Dash/Streamlit components
- `app.py` orchestrates — wires layers, defines layout and callbacks
- `_logger.py` is the only logging import — never use `print()` or raw `logging`
- All table names and `warehouse_id` come from the `CONFIG` dict in `app.py` — never hardcoded in `data.py`
- Always include `requirements.txt` and `app.yaml`

---

## Standard File Structure

```
my-app/
├── app.py              ← Orchestrator: layout, callbacks, CONFIG dict
├── data.py             ← Data layer: sql-connector reads only
├── logic.py            ← Logic layer: pandas transforms, aggregations, KPI math
├── ui.py               ← UI layer: Plotly figures, Dash/Streamlit components
├── _logger.py          ← Structured logger (copy from template)
├── app.yaml            ← Databricks App deployment manifest
├── requirements.txt    ← Python dependencies
└── APP.md              ← App spec (purpose, tables, filters, tiles)
```

---

## Data Access — The Only Correct Pattern

Use `databricks-sql-connector` with `Config()` from `databricks-sdk`. The App runtime injects
`DATABRICKS_CLIENT_ID` and `DATABRICKS_CLIENT_SECRET` (OAuth M2M) which `Config()` auto-detects.

```python
# data.py — PROVEN pattern for Databricks Apps SQL access
import os
import pandas as pd
from databricks.sdk.core import Config
from databricks import sql as dbsql
from _logger import get_logger

logger = get_logger(__name__)


class DataAccessError(Exception):
    pass


def _execute_sql(query: str, warehouse_id: str) -> pd.DataFrame:
    """Query UC via sql-connector + Config() SP credentials. Returns pandas DataFrame with
    correct Python types (int, float, str) — not strings like Statement Execution API."""
    cfg = Config()  # auto-detects DATABRICKS_CLIENT_ID / SECRET from App runtime env
    with dbsql.connect(
        server_hostname=cfg.host,
        http_path=f"/sql/1.0/warehouses/{warehouse_id}",
        credentials_provider=lambda: cfg.authenticate,
    ) as conn:
        with conn.cursor() as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()
            cols = [d[0] for d in cursor.description]
    return pd.DataFrame(rows, columns=cols)


def load_table(catalog: str, schema: str, table: str, warehouse_id: str,
               where: str = "") -> pd.DataFrame:
    full_name = f"{catalog}.{schema}.{table}"
    sql = f"SELECT * FROM {full_name}"
    if where:
        sql += f" WHERE {where}"
    try:
        logger.info(f"Loading {full_name}")
        df = _execute_sql(sql, warehouse_id)
        logger.info(f"Loaded {len(df)} rows from {full_name}")
        return df
    except Exception as e:
        logger.error(f"Failed to load {full_name}: {e}")
        raise DataAccessError(f"Table unavailable: {full_name}") from e


def filter_by_date(df: pd.DataFrame, col: str, start, end) -> pd.DataFrame:
    return df[(df[col] >= start) & (df[col] <= end)]


def filter_by_values(df: pd.DataFrame, col: str, values: list) -> pd.DataFrame:
    if not values or values == ["All"]:
        return df
    return df[df[col].isin(values)]
```

---

## Startup Pattern — CSV Fallback + dcc.Interval UC Retry

**Never call `Config()` or `dbsql.connect()` at module level** — it blocks the health check
and causes a 502. Two-phase pattern: load from CSV instantly (health check passes, UI is
interactive), then retry UC in the background interval until the warehouse responds.

**Why retry, not single-shot:** `max_intervals=1` silently fails if the warehouse is cold
at the moment the interval fires. Use `max_intervals=12, interval=10000` (retries every 10 s
for up to 2 minutes) with a `_uc_loaded` flag to stop once data is live.

```python
# app.py — correct two-phase startup

# Phase 1: CSV — instant, health check passes, UI is interactive immediately
try:
    stores_df, items_df = load_catalog_csv("stores.csv", "items.csv")
    store_options = [{'label': r['name'], 'value': r['id']}
                     for _, r in stores_df.iterrows()]
except Exception as e:
    logger.error(f"CSV startup failed: {e}")
    stores_df, items_df, store_options = pd.DataFrame(), pd.DataFrame(), []

_uc_loaded = False  # module-level flag — prevents redundant retries after success

# In layout:
dcc.Interval(id='uc-reload-interval', interval=10000, max_intervals=12, n_intervals=0),
html.Div(id='data-loading-banner', children=[
    html.Span("⏳ Conectando a Databricks…", style={"color": TEXT_SECONDARY})
]),
dcc.Dropdown(id='store-dropdown', options=store_options,
             placeholder="Buscar…", disabled=False),  # enabled — CSV data ready

# Phase 2: UC reload callback — retries every 10 s, stops on success
@app.callback(
    [Output('store-dropdown', 'options'),
     Output('store-dropdown', 'placeholder'),
     Output('store-dropdown', 'disabled'),
     Output('data-loading-banner', 'children'),
     Output('uc-reload-interval', 'max_intervals')],
    [Input('uc-reload-interval', 'n_intervals')],
    prevent_initial_call=True
)
def reload_from_uc(n_intervals):
    global stores_df, items_df, store_options, _uc_loaded
    if _uc_loaded:
        return [dash.no_update] * 5  # already live — skip
    try:
        stores_df, items_df = load_catalog(TABLE_STORES, TABLE_ITEMS)
        store_options = [{'label': r['name'], 'value': r['id']}
                         for _, r in stores_df.iterrows()]
        _uc_loaded = True
        banner = html.Span(
            f"✓ {len(stores_df)} tiendas · {len(items_df)} artículos — Databricks",
            style={"color": POSITIVE, "fontWeight": "500"}
        )
        return store_options, "Buscar…", False, banner, n_intervals  # stop interval
    except Exception as e:
        logger.error(f"UC attempt {n_intervals} failed: {e}")
    banner = html.Span(f"⏳ Conectando… (intento {n_intervals}/12)",
                       style={"color": TEXT_SECONDARY})
    return store_options, "Buscar…", False, banner, dash.no_update
```

Callbacks that render data (map, chart) should NOT take `uc-data-status` as an Input —
it causes unwanted re-renders that can wipe user state (e.g. DENUE overlays). Instead,
they read from the global DataFrames which are already updated when the user next interacts.

---

## app.yaml — Deployment Manifest

Set `DATABRICKS_HTTP_PATH` as a plain `value` — the full warehouse HTTP path.
**Do NOT use `valueFrom` + `resources:`** — this pattern throws
"error resolving resource: resource not found" unless the workspace admin has pre-configured
the resource grant, which is rarely done. Every working Alpura app uses plain `value:`.

```yaml
command: ["python", "app.py"]       # Dash
# command: ["streamlit", "run", "app.py", "--server.port=8050"]  # Streamlit

env:
  - name: DATABRICKS_HTTP_PATH
    value: /sql/1.0/warehouses/your-warehouse-id   # full HTTP path, not just the ID
  - name: APP_ENV
    value: "production"
```

`DATABRICKS_HOST`, `DATABRICKS_CLIENT_ID`, and `DATABRICKS_CLIENT_SECRET` are injected
automatically by the App runtime — do NOT declare them in app.yaml.

> To find the warehouse HTTP path: Databricks UI → SQL Warehouses → your warehouse →
> Connection Details → HTTP Path (looks like `/sql/1.0/warehouses/5e20f044ce39cd0b`).

---

## requirements.txt

```
dash
plotly
pandas
databricks-sdk          # Config() for auth credential provider
databricks-sql-connector  # sql.connect() for SQL warehouse queries
python-dotenv
requests
numpy
```

**Do NOT add:** `pyspark`, `databricks-connect`, `geopandas`, `shapely` — no Spark session
in Apps runtime; geopandas requires native GDAL not available in the container.

---

## Service Principal Permissions (One-time Setup)

The App's SP `applicationId` (UUID) is shown in `databricks apps get <name>` as `service_principal_client_id`.

```sql
-- Run as catalog owner or workspace admin
GRANT USE CATALOG ON CATALOG my_catalog TO `<sp-application-id-uuid>`;
GRANT USE SCHEMA  ON SCHEMA  my_catalog.my_schema TO `<sp-application-id-uuid>`;
GRANT SELECT      ON TABLE   my_catalog.my_schema.my_table TO `<sp-application-id-uuid>`;
```

Use the UUID (e.g. `14b79bb6-7339-476f-b217-79b270d51906`), NOT the display name
(`app-xxxxx my-app-name`) — Databricks GRANT requires the applicationId.

---

## CONFIG Pattern — app.py

```python
import os

# Read the full HTTP path injected by app.yaml — NOT the warehouse ID alone
HTTP_PATH = os.environ.get("DATABRICKS_HTTP_PATH", "")
CATALOG  = "prod"
SCHEMA   = "gold"
TABLES = {
    "sales":     f"{CATALOG}.{SCHEMA}.sales_daily",
    "products":  f"{CATALOG}.{SCHEMA}.products",
}
```

---

## APP.md Spec Template

Every app must have an `APP.md` before any code is written:

```markdown
# App: [Name]

## Purpose
One sentence — what decision or workflow does this app support?

## Audience
[Team / role — e.g. "Finance team, read-only"]

## Data Sources
| Layer | Table | Active Filter | Refresh |
|---|---|---|---|
| Silver | cat.sch.stores | fin_close_dt IS NULL | daily |

## Filters / KPIs / Charts
...

## Framework
[ ] Dash  [ ] Streamlit
```

---

## Deployment Commands

```bash
# Deploy / update
databricks apps deploy my-app-name --source-code-path ./my-app

# View logs (live tail) — requires OAuth profile, not PAT
databricks apps logs my-app-name --follow

# Get app info (includes service_principal_client_id for GRANTs)
databricks apps get my-app-name

# List all apps
databricks apps list
```

---

## Debug Checklist

```
1. APP WON'T START (CRASHED 2s after deploy)
   □ Config()/dbsql.connect() called at module level? Move inside a function
   □ Package with native C libs in requirements? (geopandas, shapely) — remove them
   □ ImportError? Check that databricks-sql-connector is in requirements.txt

2. NO DATA LOADS / QUERY FAILS
   □ SP has USE CATALOG, USE SCHEMA, SELECT? Run GRANT in a notebook
   □ GRANT uses applicationId UUID (from databricks apps get), NOT display name
   □ DATABRICKS_HTTP_PATH set in app.yaml as plain value:? Check logs for warehouse=''
   □ Do NOT use valueFrom: + resources: — throws "resource not found" unless workspace admin
     pre-configures it. Use value: /sql/1.0/warehouses/your-id instead
   □ Interval fires but query still fails? Warehouse may be cold — use max_intervals=12
     with interval=10000 to retry up to 2 minutes
   □ Error banner shows specific message? That's the real error — fix it

3. MAP / CHART DOESN'T UPDATE AFTER DATA LOADS
   □ Add Input('uc-data-status', 'children') to the chart/map callback
   □ Without it the callback only fires on user interaction, not on data arrival

4. BLANK / BROKEN UI
   □ Callback returning correct types? (list for options, go.Figure for graph)
   □ Columns returned as strings? sql-connector returns correct Python types; Statement
     Execution API returns everything as strings — always use sql-connector

5. AUTH ERROR IN CALLBACK
   □ Use Config() + credentials_provider — NOT WorkspaceClient().statement_execution
   □ Config() auto-detects DATABRICKS_CLIENT_ID/SECRET injected by App runtime
   □ DATABRICKS_TOKEN is NOT reliably set in Apps — never depend on it
```

---

## Forbidden

- `spark.table()` or `spark.sql()` — no Spark session in Apps runtime
- `WorkspaceClient().statement_execution.execute_statement()` for SQL queries — use sql-connector
- `Config()` or `dbsql.connect()` at module level — always inside a function/callback
- `WorkspaceClient(token=os.environ["DATABRICKS_TOKEN"])` — TOKEN not guaranteed in Apps
- Hardcoded warehouse IDs or catalog names outside CONFIG/env vars
- `geopandas`, `shapely`, or any package requiring native C libs
- `pyspark` or `databricks-connect` in requirements.txt
- `print()` — always `logger.info/error`
- Business logic in `ui.py` — aggregations go in `logic.py`
- `debug=True` in production `app.run()`
- Reading `bronze_*` or `silver_*` tables in UI-facing apps (use Gold)
