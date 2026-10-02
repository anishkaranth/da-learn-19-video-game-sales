#!/usr/bin/env python3
"""Download the full video-game sales datasets into data/raw_full/ and verify SHA-256.

Kaggle pages : https://www.kaggle.com/datasets/gregorut/videogamesales (vgsales.csv, vgchartz scrape, 16,598 rows)
               https://www.kaggle.com/datasets/rush4ratio/video-game-sales-with-ratings (Video_Games_Sales_as_at_22_Dec_2016.csv, 16,719 rows)
Mirrors      : GitHub copies of the unmodified Kaggle files (URLs below)
Licence      : vgsales - unknown/unspecified on Kaggle (data scraped from vgchartz.com); ratings - unknown on Kaggle
               (vgchartz + Metacritic). Use for learning / non-commercial analysis with attribution.
"""
import hashlib, pathlib, urllib.request

FILES = {
    "vgsales.csv": ("https://raw.githubusercontent.com/amankharwal/Website-data/master/vgsales.csv",
                    "e2076095ffcae2a92dbc6de6ecbd54455ee034bb38da550b2dc385e9265d4ebe"),
    "Video_Games_Sales_as_at_22_Dec_2016.csv": (
        "https://raw.githubusercontent.com/danieljaouen/DS-Unit-1-Sprint-1-Dealing-With-Data/master/module1-afirstlookatdata/Video_Games_Sales_as_at_22_Dec_2016.csv",
        "7d6b300e49bf216b73a1b3790f1340d7384b3fd766506389f9bb9c99b2c7d16d"),
}
out = pathlib.Path(__file__).resolve().parents[1] / "data" / "raw_full"
out.mkdir(parents=True, exist_ok=True)
bad = 0
for name, (url, sha) in FILES.items():
    p = out / name
    if not p.exists():
        print("downloading", url)
        urllib.request.urlretrieve(url, p)
    got = hashlib.sha256(p.read_bytes()).hexdigest()
    print(f"{name:42s} {p.stat().st_size:>11,} bytes  {'OK' if got == sha else 'CHECKSUM MISMATCH ' + got}")
    bad += got != sha
raise SystemExit(1 if bad else 0)
