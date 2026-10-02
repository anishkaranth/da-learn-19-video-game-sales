-- 03_model.sql  Star schema (Spark SQL dialect)
--   fact : fact_game_sales (grain: one title released on one platform, vgchartz Oct-2016 snapshot)
--   dims : dim_platform (with maker + type), dim_genre, dim_publisher, dim_year
-- Critic/user scores from cln_vg_ratings are attached to the fact by (lower(title), platform).

CREATE OR REPLACE TABLE dim_platform AS
SELECT
  CAST(ROW_NUMBER() OVER (ORDER BY platform) AS INT) AS platform_key,
  platform,
  CASE WHEN platform IN ('WII', 'NES', 'SNES', 'N64', 'GC', 'WIIU', 'GB', 'GBA', 'DS', '3DS') THEN 'Nintendo'
       WHEN platform IN ('PS', 'PS2', 'PS3', 'PS4', 'PSP', 'PSV') THEN 'Sony'
       WHEN platform IN ('XB', 'X360', 'XONE') THEN 'Microsoft'
       WHEN platform IN ('GEN', 'SAT', 'DC', 'SCD', 'GG') THEN 'Sega'
       WHEN platform = 'PC' THEN 'PC'
       ELSE 'Other' END AS platform_maker,
  CASE WHEN platform IN ('GB', 'GBA', 'DS', '3DS', 'PSP', 'PSV', 'GG', 'WS') THEN 'Handheld'
       WHEN platform = 'PC' THEN 'PC' ELSE 'Home console' END AS platform_type,
  first_year, last_year, titles
FROM (SELECT platform, MIN(release_year) AS first_year, MAX(release_year) AS last_year, COUNT(*) AS titles
      FROM cln_game_sales GROUP BY platform) p;

CREATE OR REPLACE TABLE dim_genre AS
SELECT CAST(ROW_NUMBER() OVER (ORDER BY genre) AS INT) AS genre_key, genre
FROM (SELECT DISTINCT genre FROM cln_game_sales WHERE genre IS NOT NULL) g;

CREATE OR REPLACE TABLE dim_publisher AS
SELECT CAST(ROW_NUMBER() OVER (ORDER BY publisher) AS INT) AS publisher_key, publisher,
       titles, CASE WHEN titles >= 100 THEN 'Major (100+ titles)' WHEN titles >= 20 THEN 'Mid (20-99)' ELSE 'Small (<20)' END AS publisher_size
FROM (SELECT publisher, COUNT(*) AS titles FROM cln_game_sales GROUP BY publisher) p;

CREATE OR REPLACE TABLE dim_year AS
SELECT CAST(COALESCE(release_year, 0) AS INT) AS year_key, release_year,
       era, CASE WHEN release_year IS NULL THEN 'Unknown' ELSE concat(CAST(FLOOR(release_year / 10) * 10 AS STRING), 's') END AS decade
FROM (SELECT DISTINCT release_year, era FROM cln_game_sales) y;

CREATE OR REPLACE TABLE fact_game_sales AS
SELECT
  s.sales_rank AS game_id,
  p.platform_key, g.genre_key, pb.publisher_key, CAST(COALESCE(s.release_year, 0) AS INT) AS year_key,
  s.title,
  s.na_sales, s.eu_sales, s.jp_sales, s.other_sales, s.global_sales,
  r.critic_score, r.critic_count, r.user_score, r.user_count, r.esrb_rating, r.developer,
  CASE WHEN r.critic_score IS NULL THEN 'No score'
       WHEN r.critic_score < 50 THEN '1: <50' WHEN r.critic_score < 60 THEN '2: 50-59'
       WHEN r.critic_score < 70 THEN '3: 60-69' WHEN r.critic_score < 80 THEN '4: 70-79'
       WHEN r.critic_score < 90 THEN '5: 80-89' ELSE '6: 90+' END AS critic_band,
  CASE WHEN r.title IS NULL THEN 0 ELSE 1 END AS has_rating_match,
  s.is_million_seller, s.is_mega_hit,
  s.dq_global_ne_regions, s.dq_missing_year, s.dq_year_after_snapshot, s.dq_unknown_publisher
FROM cln_game_sales s
JOIN dim_platform p ON s.platform = p.platform
JOIN dim_genre g ON s.genre = g.genre
JOIN dim_publisher pb ON s.publisher = pb.publisher
LEFT JOIN cln_vg_ratings r ON lower(s.title) = lower(r.title) AND s.platform = r.platform;
