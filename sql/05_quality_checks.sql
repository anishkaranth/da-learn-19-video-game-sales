-- 05_quality_checks.sql  Data-quality evidence: before/after counts, issue counts, assertions (Spark SQL dialect)

CREATE OR REPLACE TABLE dq_row_counts AS
SELECT 'game_sales' AS entity, (SELECT COUNT(*) FROM stg_vgsales) AS raw_rows,
       (SELECT COUNT(*) FROM (SELECT DISTINCT lower(trim(Name)), upper(trim(Platform)), Year FROM stg_vgsales) d) AS distinct_keys,
       (SELECT COUNT(*) FROM cln_game_sales) AS clean_rows, 'title x platform x year' AS grain
UNION ALL SELECT 'vg_ratings', (SELECT COUNT(*) FROM stg_vg_ratings),
       (SELECT COUNT(*) FROM (SELECT DISTINCT lower(trim(Name)), upper(trim(Platform)) FROM stg_vg_ratings) d),
       (SELECT COUNT(*) FROM cln_vg_ratings), 'title x platform (rows with any score/rating)'
UNION ALL SELECT 'fact_game_sales', NULL, NULL, (SELECT COUNT(*) FROM fact_game_sales), 'title x platform'
UNION ALL SELECT 'dim_platform', NULL, NULL, (SELECT COUNT(*) FROM dim_platform), 'platform'
UNION ALL SELECT 'dim_genre', NULL, NULL, (SELECT COUNT(*) FROM dim_genre), 'genre'
UNION ALL SELECT 'dim_publisher', NULL, NULL, (SELECT COUNT(*) FROM dim_publisher), 'publisher'
UNION ALL SELECT 'dim_year', NULL, NULL, (SELECT COUNT(*) FROM dim_year), 'release year (0 = unknown)';

CREATE OR REPLACE TABLE dq_null_rates AS
SELECT 'game_sales' AS entity, 'Year' AS column_name,
  (SELECT ROUND(100.0 * SUM(CASE WHEN Year IS NULL OR upper(trim(Year)) IN ('N/A', '') THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_vgsales) AS raw_null_pct,
  (SELECT ROUND(100.0 * SUM(CASE WHEN release_year IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_game_sales) AS clean_null_pct,
  'kept, year_key 0 / era Unknown' AS treatment
UNION ALL SELECT 'game_sales', 'Publisher',
  (SELECT ROUND(100.0 * SUM(CASE WHEN Publisher IS NULL OR upper(trim(Publisher)) IN ('N/A', '') THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_vgsales),
  (SELECT ROUND(100.0 * SUM(CASE WHEN publisher IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_game_sales), 'mapped to Unknown'
UNION ALL SELECT 'vg_ratings', 'Critic_Score',
  (SELECT ROUND(100.0 * SUM(CASE WHEN Critic_Score IS NULL OR trim(Critic_Score) = '' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_vg_ratings),
  (SELECT ROUND(100.0 * SUM(CASE WHEN critic_score IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_vg_ratings), 'NULL = no Metacritic score'
UNION ALL SELECT 'vg_ratings', 'User_Score',
  (SELECT ROUND(100.0 * SUM(CASE WHEN User_Score IS NULL OR trim(User_Score) = '' OR lower(trim(User_Score)) = 'tbd' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_vg_ratings),
  (SELECT ROUND(100.0 * SUM(CASE WHEN user_score IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_vg_ratings), 'tbd -> NULL, rescaled x10'
UNION ALL SELECT 'fact_game_sales', 'critic_score',
  NULL, (SELECT ROUND(100.0 * SUM(CASE WHEN critic_score IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM fact_game_sales), 'after title+platform match';

CREATE OR REPLACE TABLE dq_issues AS
SELECT 'game_sales: duplicate title x platform x year rows dropped' AS check_name,
       (SELECT COUNT(*) FROM stg_vgsales) - (SELECT COUNT(*) FROM cln_game_sales) AS affected_rows
UNION ALL SELECT 'game_sales: Year N/A (kept as Unknown)', (SELECT SUM(dq_missing_year) FROM cln_game_sales)
UNION ALL SELECT 'game_sales: Year > 2016 snapshot (kept, excluded from trends)', (SELECT SUM(dq_year_after_snapshot) FROM cln_game_sales)
UNION ALL SELECT 'game_sales: Publisher N/A or Unknown', (SELECT SUM(dq_unknown_publisher) FROM cln_game_sales)
UNION ALL SELECT 'game_sales: Global_Sales <> sum of regions by > 0.02M (rounding)', (SELECT SUM(dq_global_ne_regions) FROM cln_game_sales)
UNION ALL SELECT 'game_sales: zero-sales rows (Global_Sales = 0)', (SELECT COUNT(*) FROM cln_game_sales WHERE global_sales = 0)
UNION ALL SELECT 'vg_ratings: duplicate title x platform rows dropped',
       (SELECT COUNT(*) FROM stg_vg_ratings WHERE trim(Name) <> '') - (SELECT COUNT(*) FROM (SELECT DISTINCT lower(trim(Name)), upper(trim(Platform)) FROM stg_vg_ratings WHERE trim(Name) <> '') d)
UNION ALL SELECT 'vg_ratings: rows without any score/rating (dropped)',
       (SELECT COUNT(*) FROM (SELECT DISTINCT lower(trim(Name)), upper(trim(Platform)) FROM stg_vg_ratings WHERE trim(Name) <> '') d) - (SELECT COUNT(*) FROM cln_vg_ratings)
UNION ALL SELECT 'vg_ratings: User_Score = tbd (set NULL)', (SELECT COUNT(*) FROM stg_vg_ratings WHERE lower(trim(User_Score)) = 'tbd')
UNION ALL SELECT 'vg_ratings: ESRB K-A recoded to E', (SELECT COUNT(*) FROM stg_vg_ratings WHERE upper(trim(Rating)) = 'K-A')
UNION ALL SELECT 'fact: titles matched to a critic score', (SELECT COUNT(*) FROM fact_game_sales WHERE critic_score IS NOT NULL)
UNION ALL SELECT 'fact: titles with any ratings match', (SELECT SUM(has_rating_match) FROM fact_game_sales)
UNION ALL SELECT 'RI: fact rows lost in dim joins', (SELECT COUNT(*) FROM cln_game_sales) - (SELECT COUNT(*) FROM fact_game_sales);

CREATE OR REPLACE TABLE dq_assertions AS
WITH c AS (
  SELECT 'fact_game_sales.game_id unique' AS check_name,
         (SELECT COUNT(*) - COUNT(DISTINCT game_id) FROM fact_game_sales) AS failed_rows
  UNION ALL SELECT 'fact rows = cleaned rows (no fan-out / loss in joins)',
         (SELECT ABS((SELECT COUNT(*) FROM fact_game_sales) - (SELECT COUNT(*) FROM cln_game_sales)))
  UNION ALL SELECT 'fact.platform_key -> dim_platform', (SELECT COUNT(*) FROM fact_game_sales WHERE platform_key NOT IN (SELECT platform_key FROM dim_platform))
  UNION ALL SELECT 'fact.genre_key -> dim_genre', (SELECT COUNT(*) FROM fact_game_sales WHERE genre_key NOT IN (SELECT genre_key FROM dim_genre))
  UNION ALL SELECT 'fact.publisher_key -> dim_publisher', (SELECT COUNT(*) FROM fact_game_sales WHERE publisher_key NOT IN (SELECT publisher_key FROM dim_publisher))
  UNION ALL SELECT 'fact.year_key -> dim_year', (SELECT COUNT(*) FROM fact_game_sales WHERE year_key NOT IN (SELECT year_key FROM dim_year))
  UNION ALL SELECT 'regional sales >= 0', (SELECT COUNT(*) FROM fact_game_sales WHERE na_sales < 0 OR eu_sales < 0 OR jp_sales < 0 OR other_sales < 0)
  UNION ALL SELECT 'critic_score in 0..100', (SELECT COUNT(*) FROM fact_game_sales WHERE critic_score < 0 OR critic_score > 100)
  UNION ALL SELECT 'user_score in 0..100', (SELECT COUNT(*) FROM fact_game_sales WHERE user_score < 0 OR user_score > 100)
  UNION ALL SELECT 'global sales reconcile with regions within 1% overall',
         (SELECT CASE WHEN ABS(SUM(global_sales) - SUM(na_sales + eu_sales + jp_sales + other_sales)) <= 0.01 * SUM(global_sales) THEN 0 ELSE 1 END FROM fact_game_sales)
  UNION ALL SELECT 'platform share sums to 100%', (SELECT CASE WHEN ABS(SUM(share_pct) - 100) < 0.1 THEN 0 ELSE 1 END FROM a_platform_sales)
  UNION ALL SELECT 'dim_publisher.publisher unique', (SELECT COUNT(*) - COUNT(DISTINCT publisher) FROM dim_publisher)
)
SELECT check_name, failed_rows, CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status FROM c;
