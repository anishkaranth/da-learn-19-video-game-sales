"""Project config shared by run_pipeline.py, build_databricks.py (and the Databricks deploy)."""
REPO = "da-learn-19-video-game-sales"
NN = "19"
DASH_TITLE = "Video game sales 1980-2016 (vgchartz)"
DASH_NAME = "da-learn-19 Video game sales"
NOTEBOOK = "vgsales_pipeline_notebook"
DASH_FILE = "video_game_sales_dashboard"
CURRENCY = "USD"
DATASET = "vgchartz Video Game Sales (Kaggle gregorut/videogamesales) + Video Game Sales with Ratings (Kaggle rush4ratio/video-game-sales-with-ratings)"
RAW = {"stg_vgsales": {"file": "vgsales.csv", "format": "csv"},
       "stg_vg_ratings": {"file": "Video_Games_Sales_as_at_22_Dec_2016.csv", "format": "csv"}}
RAW_FILES = [v["file"] for v in RAW.values()]
CLEAN = ["cln_game_sales", "cln_vg_ratings"]
STAR = ["fact_game_sales", "dim_platform", "dim_genre", "dim_publisher", "dim_year"]
# Power BI kit (sample-sized): fact = top 150 titles by vgchartz rank; dim_publisher = publishers of those titles
PBI_CAP = {"fact_game_sales": 150, "dim_publisher": 150}
PBI_SAMPLE_FILTER = {"fact_game_sales": "game_id <= 150",
                     "dim_publisher": "publisher_key IN (SELECT publisher_key FROM fact_game_sales WHERE game_id <= 150)"}
COMPARE_TABLES = ["a_platform_sales", "a_genre_region", "a_publisher_top", "a_critic_score_bands", "a_hit_concentration", "a_esrb_rating", "dq_issues"]
SHOT_CONFIG = {"engine": "duckdb (local, full data) + Databricks serverless SQL", "sql_dialect": "Spark/Databricks SQL + DuckDB shims (sql/00)",
               "units": "millions of units sold (vgchartz estimates, physical retail)", "snapshot": "vgsales Oct-2016; ratings 22-Dec-2016",
               "dedupe": "title x platform x year (keep best rank)", "ratings_join": "lower(title) + platform; User_Score x10, tbd -> NULL",
               "trend_years": "1980-2016", "sample_rule": "data/raw = every 200th vgchartz rank + matching ratings rows"}
SHOT_QUERIES = {
    "top5_platforms": "SELECT platform, global_sales_m, share_pct FROM a_platform_sales ORDER BY global_sales_m DESC LIMIT 5",
    "top5_genres": "SELECT genre, global_sales_m, share_of_jp_pct FROM a_genre_region ORDER BY global_sales_m DESC LIMIT 5",
    "top5_publishers": "SELECT publisher, global_sales_m, cumulative_share_pct FROM a_publisher_top ORDER BY publisher_rank LIMIT 5",
    "hit_concentration": "SELECT * FROM a_hit_concentration ORDER BY segment",
    "critic_bands": "SELECT critic_band, titles, avg_sales_m, million_seller_pct FROM a_critic_score_bands ORDER BY critic_band",
}
METRIC_QUERIES = {
    "sales_by_year": "SELECT release_year, titles, global_sales_m, jp_share_pct FROM a_sales_by_year ORDER BY release_year",
    "platform_sales": "SELECT platform, platform_maker, platform_type, titles, global_sales_m, share_pct, million_sellers FROM a_platform_sales ORDER BY global_sales_m DESC",
    "maker_share_by_year": "SELECT release_year, platform_maker, share_of_year_pct FROM a_maker_by_year WHERE release_year % 4 = 0 AND share_of_year_pct >= 1 ORDER BY release_year, share_of_year_pct DESC",
    "genre_region": "SELECT * FROM a_genre_region ORDER BY global_sales_m DESC",
    "genre_by_era": "SELECT era, genre, share_of_era_pct FROM a_genre_by_era QUALIFY ROW_NUMBER() OVER (PARTITION BY era ORDER BY share_of_era_pct DESC) <= 3 ORDER BY era, share_of_era_pct DESC",
    "top15_publishers": "SELECT publisher_rank, publisher, titles, global_sales_m, hit_rate_pct, avg_critic_score, cumulative_share_pct FROM a_publisher_top ORDER BY publisher_rank LIMIT 15",
    "critic_score_bands": "SELECT * FROM a_critic_score_bands ORDER BY critic_band",
    "hit_concentration": "SELECT * FROM a_hit_concentration ORDER BY segment",
    "esrb_rating": "SELECT * FROM a_esrb_rating ORDER BY global_sales_m DESC",
    "top_titles": "SELECT * FROM a_top_titles ORDER BY global_sales_m DESC",
}
CARDS = [("titles", "Title x platform rows", "{:,}"), ("global_sales_m", "Units sold (M)", "{:,.0f}"),
         ("median_sales_per_title_m", "Median units / title (M)", "{:.2f}"), ("million_seller_pct", "Million-sellers", "{:.1f}%"),
         ("na_share_pct", "North America share", "{:.1f}%"), ("jp_share_pct", "Japan share", "{:.1f}%")]
DASH_KPI_SQL = "SELECT titles, global_sales_m, million_seller_pct / 100 AS million_seller_rate, na_share_pct / 100 AS na_share FROM {S}a_kpi_headline"
COUNTERS = [("global_sales_m", "Units sold (millions)", "num"), ("million_seller_rate", "Titles selling 1M+", "pct")]
DASH_NOTE = "Source: vgchartz scrape (Kaggle gregorut/videogamesales, 16,598 rows, Oct-2016) + Metacritic scores (Kaggle rush4ratio). Units in millions. Tables: workspace.da_learn_19."
VIZ = [
    {"name": "sales_by_year", "title": "Units sold by release year (M)", "kind": "line", "x": "release_year", "y": "global_sales_m", "fmt": "{:,.0f}",
     "sql": "SELECT release_year, global_sales_m FROM {S}a_sales_by_year ORDER BY release_year"},
    {"name": "platform_sales", "title": "Top 12 platforms by units sold (M)", "kind": "hbar", "x": "platform", "y": "global_sales_m", "fmt": "{:,.0f}",
     "sql": "SELECT platform, global_sales_m FROM {S}a_platform_sales ORDER BY global_sales_m DESC LIMIT 12"},
    {"name": "genre_sales", "title": "Units sold by genre (M)", "kind": "hbar", "x": "genre", "y": "global_sales_m", "fmt": "{:,.0f}",
     "sql": "SELECT genre, global_sales_m FROM {S}a_genre_region ORDER BY global_sales_m DESC"},
    {"name": "genre_jp_share", "title": "Genre share of Japanese sales (%)", "kind": "hbar", "x": "genre", "y": "share_of_jp_pct", "fmt": "{:.1f}%",
     "sql": "SELECT genre, share_of_jp_pct FROM {S}a_genre_region ORDER BY share_of_jp_pct DESC"},
    {"name": "top_publishers", "title": "Top 10 publishers by units sold (M)", "kind": "hbar", "x": "publisher", "y": "global_sales_m", "fmt": "{:,.0f}",
     "sql": "SELECT publisher, global_sales_m FROM {S}a_publisher_top ORDER BY publisher_rank LIMIT 10"},
    {"name": "critic_bands", "title": "Avg units per title by Metacritic score (M)", "kind": "bar", "x": "critic_band", "y": "avg_sales_m", "fmt": "{:.2f}",
     "sql": "SELECT critic_band, avg_sales_m FROM {S}a_critic_score_bands WHERE critic_band <> 'No score' ORDER BY critic_band"},
]
