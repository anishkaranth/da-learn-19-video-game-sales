# Databricks setup and run record

The pipeline runs on a Databricks **serverless SQL warehouse** (Unity Catalog) and a Lakeview (AI/BI) dashboard is
published over the resulting tables. The shared warehouse is left to auto-stop.

| Object | Workspace location |
|---|---|
| Raw CSVs (full) | UC volume `/Volumes/workspace/da_learn_19/raw/` (`vgsales.csv`, `Video_Games_Sales_as_at_22_Dec_2016.csv`) |
| Tables (stg_*, cln_*, dim_*, fact_*, a_*, dq_*) | `workspace.da_learn_19` |
| Notebook | `/Workspace/Shared/da-learn-19-video-game-sales/vgsales_pipeline_notebook` |
| Dashboard (published) | **da-learn-19 Video game sales** (1 page: 2 counters + 6 charts = 8 visuals) |

## DuckDB vs Databricks
Executed 2026-10-02, 22:12-22:16 IST on the Serverless Starter Warehouse (37 statements, ~170 s of statement time).
All **9 stg/cln/dim/fact tables have identical row counts** on both engines (stg 16,598 / 16,719; cln_game_sales and
fact 16,596; cln_vg_ratings 10,045; dims 31 / 12 / 578 / 40). `dq_assertions` 12/12 PASS on both. Every compared KPI
table matches cell for cell except one median: `a_critic_score_bands` 90+ median 1.54 M (Databricks `percentile_approx`)
vs 1.555 M (DuckDB exact). Details: `run_outputs/duckdb_vs_databricks.json`.

## Files here
| File | What it is |
|---|---|
| `vgsales_pipeline_notebook.sql` | Databricks SQL notebook source (exported from the workspace after import; generated from `sql/` by `scripts/build_databricks.py`) |
| `video_game_sales_dashboard.lvdash.json` | Lakeview dashboard definition exported from the workspace |
| `run_outputs/` | Tables queried back from Databricks, `duckdb_vs_databricks.json`, `databricks_run.json`, `statement_log.json` |

## Re-run it yourself
1. `CREATE SCHEMA IF NOT EXISTS workspace.da_learn_19; CREATE VOLUME IF NOT EXISTS workspace.da_learn_19.raw;`
2. `python scripts/download_full_data.py`, then upload both CSVs from `data/raw_full/` to the volume
   (Catalog Explorer -> volume -> *Upload*, or `databricks fs cp`).
3. Workspace -> *Import* -> `vgsales_pipeline_notebook.sql`; attach a SQL warehouse -> *Run all*. `dq_assertions` should show 12 x PASS.
4. Dashboards -> *Import dashboard from file* -> `video_game_sales_dashboard.lvdash.json` -> pick a warehouse -> *Publish*.

## Dialect notes (DuckDB vs Databricks)
| Topic | DuckDB run | Databricks |
|---|---|---|
| CSV load | `read_csv(path, header = true, all_varchar = true)` | `read_files(..., inferColumnTypes => false)` minus `_rescued_data` |
| `percentile_approx` | exact (`quantile_cont` shim in `00_duckdb_compat.sql`) | approximate - medians can differ slightly |
| `corr`, `ln`, `PERCENT_RANK`, window frames, `TRY_CAST` | same | same |
