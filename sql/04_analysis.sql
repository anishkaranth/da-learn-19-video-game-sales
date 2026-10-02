-- 04_analysis.sql  Business KPI queries (Spark SQL dialect). Each result is materialised as an a_* table.
-- Units: sales in MILLIONS of units (vgchartz estimates, physical retail, snapshot Oct-2016).
-- Time-trend tables use release years 1980-2016 (2017/2020 rows are pre-release placeholders, flagged in 02).

-- Q1 Headline KPIs
CREATE OR REPLACE TABLE a_kpi_headline AS
SELECT
  COUNT(*)                                                                   AS titles,
  COUNT(DISTINCT title)                                                      AS distinct_games,
  ROUND(SUM(global_sales), 2)                                                AS global_sales_m,
  ROUND(100.0 * SUM(na_sales) / SUM(na_sales + eu_sales + jp_sales + other_sales), 2)    AS na_share_pct,
  ROUND(100.0 * SUM(eu_sales) / SUM(na_sales + eu_sales + jp_sales + other_sales), 2)    AS eu_share_pct,
  ROUND(100.0 * SUM(jp_sales) / SUM(na_sales + eu_sales + jp_sales + other_sales), 2)    AS jp_share_pct,
  ROUND(100.0 * SUM(other_sales) / SUM(na_sales + eu_sales + jp_sales + other_sales), 2) AS other_share_pct,
  ROUND(AVG(global_sales), 3)                                                AS avg_sales_per_title_m,
  ROUND(percentile_approx(global_sales, 0.5), 2)                             AS median_sales_per_title_m,
  SUM(is_million_seller)                                                     AS million_sellers,
  ROUND(100.0 * SUM(is_million_seller) / COUNT(*), 2)                        AS million_seller_pct,
  COUNT(DISTINCT platform_key)                                               AS platforms,
  COUNT(DISTINCT publisher_key)                                              AS publishers,
  ROUND(100.0 * SUM(CASE WHEN critic_score IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS critic_score_coverage_pct,
  ROUND(corr(CAST(critic_score AS DOUBLE), global_sales), 4)                 AS corr_critic_vs_sales,
  ROUND(corr(CAST(critic_score AS DOUBLE), ln(global_sales + 0.01)), 4)      AS corr_critic_vs_log_sales
FROM fact_game_sales;

-- Q2 Sales by release year and region (market cycle)
CREATE OR REPLACE TABLE a_sales_by_year AS
SELECT y.release_year, COUNT(*) AS titles,
       ROUND(SUM(f.global_sales), 2) AS global_sales_m, ROUND(SUM(f.na_sales), 2) AS na_sales_m,
       ROUND(SUM(f.eu_sales), 2) AS eu_sales_m, ROUND(SUM(f.jp_sales), 2) AS jp_sales_m,
       ROUND(SUM(f.other_sales), 2) AS other_sales_m,
       ROUND(100.0 * SUM(f.jp_sales) / NULLIF(SUM(f.global_sales), 0), 2) AS jp_share_pct
FROM fact_game_sales f JOIN dim_year y ON f.year_key = y.year_key
WHERE y.release_year BETWEEN 1980 AND 2016
GROUP BY y.release_year;

-- Q3 Platform league table
CREATE OR REPLACE TABLE a_platform_sales AS
SELECT p.platform, p.platform_maker, p.platform_type, p.first_year, p.last_year, COUNT(*) AS titles,
       ROUND(SUM(f.global_sales), 2) AS global_sales_m,
       ROUND(100.0 * SUM(f.global_sales) / SUM(SUM(f.global_sales)) OVER (), 2) AS share_pct,
       ROUND(AVG(f.global_sales), 3) AS avg_sales_per_title_m,
       SUM(f.is_million_seller) AS million_sellers
FROM fact_game_sales f JOIN dim_platform p ON f.platform_key = p.platform_key
GROUP BY p.platform, p.platform_maker, p.platform_type, p.first_year, p.last_year;

-- Q4 Platform maker share by year (console wars)
CREATE OR REPLACE TABLE a_maker_by_year AS
SELECT y.release_year, p.platform_maker, ROUND(SUM(f.global_sales), 2) AS global_sales_m,
       ROUND(100.0 * SUM(f.global_sales) / SUM(SUM(f.global_sales)) OVER (PARTITION BY y.release_year), 2) AS share_of_year_pct
FROM fact_game_sales f JOIN dim_platform p ON f.platform_key = p.platform_key JOIN dim_year y ON f.year_key = y.year_key
WHERE y.release_year BETWEEN 1980 AND 2016
GROUP BY y.release_year, p.platform_maker;

-- Q5 Genre x region (regional taste)
CREATE OR REPLACE TABLE a_genre_region AS
SELECT g.genre, COUNT(*) AS titles, ROUND(SUM(f.global_sales), 2) AS global_sales_m,
       ROUND(SUM(f.na_sales), 2) AS na_sales_m, ROUND(SUM(f.eu_sales), 2) AS eu_sales_m,
       ROUND(SUM(f.jp_sales), 2) AS jp_sales_m, ROUND(SUM(f.other_sales), 2) AS other_sales_m,
       ROUND(100.0 * SUM(f.na_sales) / SUM(SUM(f.na_sales)) OVER (), 2) AS share_of_na_pct,
       ROUND(100.0 * SUM(f.eu_sales) / SUM(SUM(f.eu_sales)) OVER (), 2) AS share_of_eu_pct,
       ROUND(100.0 * SUM(f.jp_sales) / SUM(SUM(f.jp_sales)) OVER (), 2) AS share_of_jp_pct,
       ROUND(AVG(f.global_sales), 3) AS avg_sales_per_title_m
FROM fact_game_sales f JOIN dim_genre g ON f.genre_key = g.genre_key
GROUP BY g.genre;

-- Q6 Genre share of sales by era (trend)
CREATE OR REPLACE TABLE a_genre_by_era AS
SELECT y.era, g.genre, ROUND(SUM(f.global_sales), 2) AS global_sales_m,
       ROUND(100.0 * SUM(f.global_sales) / SUM(SUM(f.global_sales)) OVER (PARTITION BY y.era), 2) AS share_of_era_pct
FROM fact_game_sales f JOIN dim_genre g ON f.genre_key = g.genre_key JOIN dim_year y ON f.year_key = y.year_key
WHERE y.era <> 'Unknown'
GROUP BY y.era, g.genre;

-- Q7 Publisher league table with cumulative share (concentration)
CREATE OR REPLACE TABLE a_publisher_top AS
WITH p AS (
  SELECT pb.publisher, pb.publisher_size, COUNT(*) AS titles, ROUND(SUM(f.global_sales), 2) AS global_sales_m,
         SUM(f.is_million_seller) AS million_sellers, ROUND(AVG(CAST(f.critic_score AS DOUBLE)), 1) AS avg_critic_score
  FROM fact_game_sales f JOIN dim_publisher pb ON f.publisher_key = pb.publisher_key
  GROUP BY pb.publisher, pb.publisher_size
)
SELECT ROW_NUMBER() OVER (ORDER BY global_sales_m DESC, publisher) AS publisher_rank, publisher, publisher_size, titles,
       global_sales_m, million_sellers, ROUND(100.0 * million_sellers / titles, 2) AS hit_rate_pct, avg_critic_score,
       ROUND(100.0 * global_sales_m / SUM(global_sales_m) OVER (), 2) AS share_pct,
       ROUND(100.0 * SUM(global_sales_m) OVER (ORDER BY global_sales_m DESC, publisher ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(global_sales_m) OVER (), 2) AS cumulative_share_pct
FROM p;

-- Q8 Critic score vs sales (titles with a Metacritic score)
CREATE OR REPLACE TABLE a_critic_score_bands AS
SELECT critic_band, COUNT(*) AS titles, ROUND(AVG(global_sales), 3) AS avg_sales_m,
       ROUND(percentile_approx(global_sales, 0.5), 3) AS median_sales_m,
       ROUND(100.0 * SUM(is_million_seller) / COUNT(*), 2) AS million_seller_pct,
       ROUND(AVG(user_score), 1) AS avg_user_score
FROM fact_game_sales GROUP BY critic_band;

-- Q9 Hit concentration: share of units from the top 1% / 10% of titles
CREATE OR REPLACE TABLE a_hit_concentration AS
WITH r AS (SELECT global_sales, PERCENT_RANK() OVER (ORDER BY global_sales DESC) AS pr FROM fact_game_sales)
SELECT 'top 1% of titles' AS segment, COUNT(*) AS titles, ROUND(SUM(global_sales), 2) AS global_sales_m,
       ROUND(100.0 * SUM(global_sales) / (SELECT SUM(global_sales) FROM fact_game_sales), 2) AS share_pct FROM r WHERE pr < 0.01
UNION ALL SELECT 'top 10% of titles', COUNT(*), ROUND(SUM(global_sales), 2),
       ROUND(100.0 * SUM(global_sales) / (SELECT SUM(global_sales) FROM fact_game_sales), 2) FROM r WHERE pr < 0.10
UNION ALL SELECT 'bottom 50% of titles', COUNT(*), ROUND(SUM(global_sales), 2),
       ROUND(100.0 * SUM(global_sales) / (SELECT SUM(global_sales) FROM fact_game_sales), 2) FROM r WHERE pr >= 0.50;

-- Q10 ESRB rating mix (rated titles only)
CREATE OR REPLACE TABLE a_esrb_rating AS
SELECT COALESCE(esrb_rating, 'Not rated / no match') AS esrb_rating, COUNT(*) AS titles,
       ROUND(SUM(global_sales), 2) AS global_sales_m, ROUND(AVG(global_sales), 3) AS avg_sales_m,
       ROUND(100.0 * SUM(na_sales) / NULLIF(SUM(global_sales), 0), 2) AS na_share_pct
FROM fact_game_sales GROUP BY COALESCE(esrb_rating, 'Not rated / no match');

-- Q11 Top 15 titles (all platforms combined)
CREATE OR REPLACE TABLE a_top_titles AS
SELECT title, COUNT(*) AS platforms, ROUND(SUM(global_sales), 2) AS global_sales_m,
       MIN(NULLIF(f.year_key, 0)) AS first_year, MAX(g.genre) AS genre
FROM fact_game_sales f JOIN dim_genre g ON f.genre_key = g.genre_key
GROUP BY title ORDER BY global_sales_m DESC LIMIT 15;
