# Data

| Folder | In git? | Contents |
|---|---|---|
| `raw/` | yes | Reproducible **sample** of both raw files (83 + 83 rows), built by `scripts/make_sample.py` |
| `raw_full/` | no (gitignored) | Full files, downloaded by `scripts/download_full_data.py` (SHA-256 verified) |
| `clean_full/star/` | no | Full star-schema CSVs written by `python run_pipeline.py --source full` |

## Sample rule (deterministic)
* `raw/vgsales.csv` - every 200th vgchartz rank (`Rank % 200 == 1`: ranks 1, 201, 401, ... 16,401) = 83 of 16,598 rows, copied verbatim.
* `raw/Video_Games_Sales_as_at_22_Dec_2016.csv` - the rows of the ratings file whose (Name, Platform) match one of those 83 titles = 83 of 16,719 rows.

The sample spans the whole sales distribution (Wii Sports at rank 1 down to 0.01 M-unit titles), so every SQL step and
chart runs on it. Sample results land in `results/sample/` (`JSON.shot`) and are **not** used for any reported number.

## Source files
| File | Rows | Columns |
|---|---|---|
| `vgsales.csv` | 16,598 | Rank, Name, Platform, Year, Genre, Publisher, NA_Sales, EU_Sales, JP_Sales, Other_Sales, Global_Sales (millions of units) |
| `Video_Games_Sales_as_at_22_Dec_2016.csv` | 16,719 | Name, Platform, Year_of_Release, Genre, Publisher, NA/EU/JP/Other/Global_Sales, Critic_Score, Critic_Count, User_Score, User_Count, Developer, Rating |

Known raw issues handled in `sql/02_cleaning.sql`: `Year = N/A` (271 rows), `Publisher = N/A` / Unknown, 2 duplicate
title x platform x year rows, `User_Score = tbd` (2,425 rows), ESRB `K-A` (old name of `E`), 2017/2020 placeholder years.
