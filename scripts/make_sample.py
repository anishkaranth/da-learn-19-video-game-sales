#!/usr/bin/env python3
"""Build the git-sized raw sample in data/raw/ from data/raw_full/ (deterministic, no randomness).

Rule: every 200th vgchartz rank (Rank % 200 == 1 -> 1, 201, 401, ...) from vgsales.csv, plus the rows of the
ratings file whose (Name, Platform) match one of those titles. Rows are copied verbatim."""
import csv, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
FULL, OUT = ROOT / "data/raw_full", ROOT / "data/raw"
OUT.mkdir(parents=True, exist_ok=True)
with open(FULL / "vgsales.csv", newline="", encoding="utf-8") as f:
    rows = list(csv.reader(f))
keep = [r for r in rows[1:] if r[0].isdigit() and int(r[0]) % 200 == 1]
with open(OUT / "vgsales.csv", "w", newline="", encoding="utf-8") as f:
    csv.writer(f, lineterminator="\n").writerows([rows[0]] + keep)
keys = {(r[1].strip().lower(), r[2].strip().upper()) for r in keep}
with open(FULL / "Video_Games_Sales_as_at_22_Dec_2016.csv", newline="", encoding="utf-8") as f:
    rr = list(csv.reader(f))
rk = [r for r in rr[1:] if (r[0].strip().lower(), r[1].strip().upper()) in keys]
with open(OUT / "Video_Games_Sales_as_at_22_Dec_2016.csv", "w", newline="", encoding="utf-8") as f:
    csv.writer(f, lineterminator="\n").writerows([rr[0]] + rk)
print(f"vgsales {len(keep)} of {len(rows) - 1}  ratings {len(rk)} of {len(rr) - 1}")
