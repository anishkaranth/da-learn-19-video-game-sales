# Results - da-learn-19 Video game sales (full data)

All numbers come from `python run_pipeline.py --source full` (DuckDB 1.5.6) on the complete files
(16,598 vgchartz rows + 16,719 ratings rows) and were re-produced on Databricks (`databricks/SETUP.md`).
Units are **millions of units sold** (vgchartz estimates, physical retail, snapshot Oct-2016).

## Headline KPIs (`tables/a_kpi_headline.csv`)
| KPI | Value |
|---|---|
| Title x platform rows (clean) | 16,596 (11,493 distinct game names) |
| Units sold | 8,920.41 M |
| Regional split | North America 49.27 % - Europe 27.30 % - Japan 14.48 % - Other 8.95 % |
| Avg / median units per title | 0.538 M / 0.17 M |
| Million-sellers | 2,081 titles (12.54 %) |
| Platforms / publishers | 31 / 578 |
| Metacritic score coverage | 48.50 % of titles |
| corr(critic score, units) | 0.246 (0.390 against log units) |

## Business questions and answers
1. **How did the market evolve?** Units by release year peak in **2008 (678.9 M, 1,428 titles)** and 2009 (667.3 M); 2016 is a
   partial year (344 titles, 70.9 M). Japan's share of units fell from 51.9 % of 1995 releases to 8.9 % of 2008 releases.
2. **Which platforms won?** PS2 is the best-selling platform (1,255.6 M, 14.08 %), then X360 (980.0 M), PS3 (957.8 M), Wii (926.7 M)
   and DS (822.5 M). By maker Sony (3,580 M) and Nintendo (3,522 M) are neck and neck; Microsoft 1,379 M. Sony held 67.2 % of 2000
   releases, Nintendo led 2008 (47.4 %), Sony led again in 2015 (53.2 %).
3. **Do regions want different genres?** Action is #1 overall (1,751 M) and in NA/EU, but **Role-Playing is 27.3 % of Japanese units** vs
   7.5 % of NA units; Shooters are 13.3 % of NA but only 3.0 % of Japan.
4. **How concentrated is the market?** The top 1 % of titles (166) sell **21.1 %** of all units and the top 10 % sell 58.9 %; the bottom
   half of titles sells 6.2 %. Nintendo alone has 20.0 % of units and a 48.3 % million-seller hit rate; the top 5 publishers hold 52.8 %.
5. **Do reviews matter?** Titles scored 90+ average **2.84 M units** (62.4 % million-sellers) vs 0.23 M below 50 (3.6 %); a 12x step,
   though the correlation is moderate (0.39 on log units) and causality runs both ways (big franchises get big budgets and reviews).
6. **Genre mix over time:** Platform games were 32.5 % of 1980s units; by 2011-16 Action (29.0 %) and Shooter (20.1 %) dominate.

## Top titles (all platforms combined)
Wii Sports 82.74 M; Grand Theft Auto V 55.92 M (5 platforms); Super Mario Bros. 45.31 M; Tetris 35.84 M; Mario Kart Wii 35.82 M.

## Data quality (`tables/dq_*.csv`)
| Check | Rows |
|---|---|
| vgchartz duplicate title x platform x year rows dropped | 2 (16,598 -> 16,596) |
| Year N/A (kept, era Unknown, excluded from trends) | 270 |
| Year after 2016 snapshot (placeholders, excluded from trends) | 4 |
| Publisher N/A / Unknown | 261 |
| Global_Sales differs from sum of regions by > 0.02 M (rounding in source) | 7 |
| Ratings rows: duplicate title x platform | 4 |
| Ratings rows without any score or ESRB rating (dropped) | 6,668 (-> 10,045 kept) |
| User_Score = "tbd" (set NULL) | 2,425 |
| Fact rows matched to a ratings row / to a critic score | 9,932 / 8,049 |
| Rows lost in dimension joins | 0 |

All **12/12 assertions PASS** (unique keys, FK integrity for 4 dims, no fan-out, score ranges, non-negative sales,
regions reconcile with global within 1 %, platform shares sum to 100 %).

## Caveats
* vgchartz figures are estimates of physical retail units; digital sales (big after ~2012) are missing, so the post-2010 decline is overstated.
* The two Kaggle files are different scrapes (Oct vs Dec 2016) - sales are taken from `vgsales.csv`, only scores/ratings from the second file.
  Title matching is exact on lower-cased name + platform, so a few re-titled games miss their scores.
* Raw quirks remain visible, e.g. one DS title dated 1985 makes `dim_platform.first_year` for DS = 1985.
