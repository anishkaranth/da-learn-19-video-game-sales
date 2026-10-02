-- 01_staging.sql
-- Land the two raw CSVs as all-STRING staging tables (no type inference; casting happens in 02).
-- {{RAW_DIR}} is substituted by run_pipeline.py.
-- DuckDB : read_csv(path, header = true, all_varchar = true)
-- Databricks equivalent (databricks/vgsales_pipeline_notebook.sql):
--   SELECT * EXCEPT (_rescued_data) FROM read_files('/Volumes/workspace/da_learn_19/raw/<file>.csv', format => 'csv',
--          header => true, multiLine => true, escape => '"', inferColumnTypes => false)
CREATE OR REPLACE TABLE stg_vgsales AS
SELECT * FROM read_csv('{{RAW_DIR}}/vgsales.csv', header = true, all_varchar = true, quote = '"', escape = '"');

CREATE OR REPLACE TABLE stg_vg_ratings AS
SELECT * FROM read_csv('{{RAW_DIR}}/Video_Games_Sales_as_at_22_Dec_2016.csv', header = true, all_varchar = true, quote = '"', escape = '"');
