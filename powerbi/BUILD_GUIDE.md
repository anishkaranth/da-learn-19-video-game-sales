# Power BI build guide

> A `.pbix` cannot be produced on the Linux box this project was built on (Power BI Desktop is Windows-only and has
> no headless authoring mode), so this folder is a **kit**: star-schema CSVs + model + measures + page spec.
> Estimated build time: 45 min.

1. **Get the data.** `powerbi/data/` holds a sample-sized star (top 150 titles by vgchartz rank, all platforms/genres/years,
   the publishers of those titles). For real numbers regenerate the full star:
   `pip install -r requirements.txt && python scripts/download_full_data.py && python run_pipeline.py --source full`
   then load `data/clean_full/star/*.csv` (5 files).
2. **Load.** Power BI Desktop -> *Get data -> Text/CSV* for each file. Set types as in `model.md`. Locale English (United States).
3. **Model.** Model view -> create the 4 relationships in `model.md` (all *:1, single direction). Hide keys and flags.
4. **Measures.** Create a `_Measures` table and paste `measures.dax`. Format units with 2 decimals and suffix "M", % measures as percentage.
5. **Pages.** Build the 3 pages in `dashboard_spec.md`; compare with `results/charts/dashboard.svg`.
6. **Validate** (full data): Units Sold 8,920.41 M; Titles 16,596; Million Seller % 12.54 %; NA share 49.27 %; JP share 14.48 %.
7. Save as `video_game_sales.pbix` (not committed - binary).
