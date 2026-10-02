-- 02_cleaning.sql  (Spark SQL dialect; runs on DuckDB via 00_duckdb_compat.sql shims)
-- Steps: trim/standardise text -> TRY_CAST -> 'N/A' / 'tbd' to NULL -> dedupe -> derived attributes
--        -> outlier / consistency flags -> integrity filters. Sales are in millions of units.

-- ---------------------------------------------------------------- vgchartz sales (one row per title x platform)
CREATE OR REPLACE TABLE cln_game_sales AS
WITH typed AS (
  SELECT
    TRY_CAST(trim(Rank) AS INT)                                                AS sales_rank,
    trim(Name)                                                                 AS title,
    upper(trim(Platform))                                                      AS platform,
    TRY_CAST(CASE WHEN upper(trim(Year)) IN ('N/A', 'NA', '') THEN NULL ELSE trim(Year) END AS INT) AS release_year,
    trim(Genre)                                                       AS genre,
    CASE WHEN trim(Publisher) IS NULL OR upper(trim(Publisher)) IN ('N/A', '', 'UNKNOWN') THEN 'Unknown'
         ELSE trim(Publisher) END                                              AS publisher,
    COALESCE(TRY_CAST(trim(NA_Sales) AS DOUBLE), 0)                            AS na_sales,
    COALESCE(TRY_CAST(trim(EU_Sales) AS DOUBLE), 0)                            AS eu_sales,
    COALESCE(TRY_CAST(trim(JP_Sales) AS DOUBLE), 0)                            AS jp_sales,
    COALESCE(TRY_CAST(trim(Other_Sales) AS DOUBLE), 0)                         AS other_sales,
    TRY_CAST(trim(Global_Sales) AS DOUBLE)                                     AS global_sales_reported
  FROM stg_vgsales
), dedup AS (
  -- duplicate (title, platform, year) rows: keep the best-ranked one
  SELECT *, ROW_NUMBER() OVER (PARTITION BY lower(title), platform, COALESCE(release_year, -1) ORDER BY sales_rank) AS rn
  FROM typed
  WHERE title IS NOT NULL AND title <> '' AND platform IS NOT NULL AND global_sales_reported IS NOT NULL
)
SELECT
  sales_rank, title, platform,
  release_year,
  CASE WHEN release_year IS NULL THEN 'Unknown'
       WHEN release_year < 1990 THEN '1: 1980-89' WHEN release_year < 2000 THEN '2: 1990-99'
       WHEN release_year < 2006 THEN '3: 2000-05' WHEN release_year < 2011 THEN '4: 2006-10'
       ELSE '5: 2011-16+' END                                                  AS era,
  genre,
  publisher,
  na_sales, eu_sales, jp_sales, other_sales,
  global_sales_reported                                                        AS global_sales,
  ROUND(na_sales + eu_sales + jp_sales + other_sales, 2)                       AS regional_sum,
  CASE WHEN ABS(global_sales_reported - (na_sales + eu_sales + jp_sales + other_sales)) > 0.02 THEN 1 ELSE 0 END AS dq_global_ne_regions,
  CASE WHEN release_year IS NULL THEN 1 ELSE 0 END                             AS dq_missing_year,
  CASE WHEN release_year > 2016 THEN 1 ELSE 0 END                              AS dq_year_after_snapshot,
  CASE WHEN publisher = 'Unknown' THEN 1 ELSE 0 END                            AS dq_unknown_publisher,
  CASE WHEN global_sales_reported >= 1 THEN 1 ELSE 0 END                       AS is_million_seller,
  CASE WHEN global_sales_reported >= 10 THEN 1 ELSE 0 END                      AS is_mega_hit
FROM dedup
WHERE rn = 1;

-- ---------------------------------------------------------------- critic / user scores (Metacritic, Dec-2016 snapshot)
-- User_Score 'tbd' -> NULL and rescaled 0-10 -> 0-100 so it is comparable with Critic_Score.
-- ESRB 'K-A' (Kids to Adults) is the pre-1998 name of 'E'.
CREATE OR REPLACE TABLE cln_vg_ratings AS
WITH typed AS (
  SELECT
    trim(Name)                                                                 AS title,
    upper(trim(Platform))                                                      AS platform,
    TRY_CAST(trim(Critic_Score) AS INT)                                        AS critic_score,
    TRY_CAST(trim(Critic_Count) AS INT)                                        AS critic_count,
    CASE WHEN lower(trim(User_Score)) = 'tbd' THEN NULL ELSE TRY_CAST(trim(User_Score) AS DOUBLE) END AS user_score_10,
    TRY_CAST(trim(User_Count) AS INT)                                          AS user_count,
    NULLIF(trim(Developer), '')                                                AS developer,
    CASE WHEN upper(trim(Rating)) = 'K-A' THEN 'E' ELSE NULLIF(upper(trim(Rating)), '') END AS esrb_rating,
    CASE WHEN lower(trim(User_Score)) = 'tbd' THEN 1 ELSE 0 END                AS dq_user_score_tbd
  FROM stg_vg_ratings
), dedup AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY lower(title), platform
                               ORDER BY COALESCE(critic_count, 0) DESC, COALESCE(user_count, 0) DESC) AS rn
  FROM typed WHERE title IS NOT NULL AND title <> ''
)
SELECT title, platform, critic_score, critic_count,
       ROUND(user_score_10 * 10, 1) AS user_score, user_count, developer, esrb_rating, dq_user_score_tbd,
       CASE WHEN critic_score IS NOT NULL AND (critic_score < 0 OR critic_score > 100) THEN 1 ELSE 0 END AS dq_bad_critic_score
FROM dedup
WHERE rn = 1 AND (critic_score IS NOT NULL OR user_score_10 IS NOT NULL OR esrb_rating IS NOT NULL);
