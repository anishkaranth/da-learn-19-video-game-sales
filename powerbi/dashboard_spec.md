# Power BI dashboard spec (3 pages)

Reference rendering of the same KPIs: `results/charts/dashboard.svg`.

## Page 1 - Market overview
| Visual | Fields |
|---|---|
| 4 cards | Units Sold (M), Titles, Million Seller %, Median Units per Title (M) |
| Line chart | X `dim_year[release_year]` (1980-2016), Y Units (Trend Years) (M) |
| Stacked area | X release_year, Y NA / EU / JP / Other Units (M) |
| Slicers | dim_platform[platform_maker], dim_genre[genre], dim_year[era] |

## Page 2 - Platforms and publishers
| Visual | Fields |
|---|---|
| Bar (top 12) | dim_platform[platform], Units Sold (M), colour platform_maker |
| 100 % stacked column | X release_year, Y Units Sold (M), legend platform_maker (console wars) |
| Table | dim_publisher[publisher], Units Sold (M), Titles, Million Seller %, Avg Critic Score, Publisher Rank (top N = 10) |

## Page 3 - Genres, regions and reviews
| Visual | Fields |
|---|---|
| Matrix | rows dim_genre[genre]; values NA / EU / JP Units (M) with conditional formatting |
| Bar | genre, Share of Genre JP % |
| Column | fact_game_sales[critic_band] (exclude "No score"), Avg Units per Title (M) |
| Scatter | X Avg Critic Score, Y Avg Units per Title (M), details publisher |
