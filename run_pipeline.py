#!/usr/bin/env python3
"""Run sql/00..05 on DuckDB, export star/KPI/DQ tables, metrics.json, JSON.shot and SVG charts.

  python run_pipeline.py --source sample   # data/raw (in git)          -> results/sample/
  python run_pipeline.py --source full     # data/raw_full (download)   -> results/, data/clean_full/, powerbi/data/
"""
import argparse, csv, json, pathlib, platform, re, sys, time
import duckdb

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))
import project as P
import svgcharts as S

SQL_FILES = ["00_duckdb_compat.sql", "01_staging.sql", "02_cleaning.sql", "03_model.sql",
             "04_analysis.sql", "05_quality_checks.sql"]


def split_sql(text):
    """Split on ';' at end of line after removing -- comments."""
    stmts, buf = [], []
    for line in text.splitlines():
        i = line.find("--")
        if i >= 0 and line[:i].count("'") % 2 == 0:
            line = line[:i]
        if not line.strip():
            continue
        buf.append(line)
        if line.rstrip().endswith(";"):
            s = "\n".join(buf).strip().rstrip(";").strip()
            if s:
                stmts.append(s)
            buf = []
    return stmts


def J(v):
    if hasattr(v, "isoformat"):
        return v.isoformat()
    if v.__class__.__name__ == "Decimal":
        return float(v)
    if isinstance(v, float):
        return round(v, 4)
    return v


def jdump(o):
    """indent=1 JSON with innermost objects collapsed onto one line (compact but diff-friendly)."""
    s = json.dumps(o, indent=1)
    return re.sub(r"\{\n\s+([^{}\[\]]*?)\n\s*\}", lambda m: "{" + " ".join(l.strip() for l in m.group(1).splitlines()) + "}", s) + "\n"


def rows(con, q):
    cur = con.execute(q)
    cols = [d[0] for d in cur.description]
    return [{c: J(v) for c, v in zip(cols, r)} for r in cur.fetchall()]


def export(con, q, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    cur = con.execute(q)
    cols = [d[0] for d in cur.description]
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(cols)
        for r in cur.fetchall():
            w.writerow(["" if v is None else J(v) for v in r])


def run_sql(con, raw):
    timings = {}
    for f in SQL_FILES:
        t0 = time.time()
        for s in split_sql((ROOT / "sql" / f).read_text().replace("{{RAW_DIR}}", raw.as_posix())):
            con.execute(s)
        timings[f] = round(time.time() - t0, 2)
        print(f"ran {f:24s} {timings[f]:7.2f}s", flush=True)
    return timings


def chart(con, v):
    r = rows(con, v["sql"].format(S=""))
    if not r:
        return None
    if v["kind"] == "line":
        xs = sorted({x[v["x"]] for x in r}, key=str)
        if v.get("color"):
            names = list(dict.fromkeys(x[v["color"]] for x in r))
            idx = {(x[v["color"]], x[v["x"]]): x[v["y"]] for x in r}
            ser = {n: [idx.get((n, x)) for x in xs] for n in names}
        else:
            m = {x[v["x"]]: x[v["y"]] for x in r}
            ser = {v["title"]: [m.get(x) for x in xs]}
        return S.line(xs, {k: [None if a is None else float(a) for a in s] for k, s in ser.items()}, v["title"], v.get("fmt"))
    lab = [x[v["x"]] for x in r]; val = [float(x[v["y"]] or 0) for x in r]
    if v["kind"] == "hbar":
        return S.hbar(lab, val, v["title"], v.get("fmt"), h=300 if len(lab) <= 12 else None)
    return S.vbar(lab, val, v["title"], v.get("fmt"), rot=-35 if len(lab) > 8 or max(len(str(l)) for l in lab) > 9 else None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", choices=["sample", "full"], default="sample")
    a = ap.parse_args()
    full = a.source == "full"
    raw = ROOT / ("data/raw_full" if full else "data/raw")
    res = ROOT / ("results" if full else "results/sample")
    for f in P.RAW_FILES:
        if not (raw / f).exists():
            raise SystemExit(f"missing {raw / f}; run scripts/download_full_data.py (full) first")
    con = duckdb.connect()
    con.execute("SET preserve_insertion_order = false")
    timings = run_sql(con, raw)

    for t in P.STAR:
        if full:
            export(con, f"SELECT * FROM {t}", ROOT / "data/clean_full/star" / f"{t}.csv")
            cap = P.PBI_CAP.get(t)
            q = f"SELECT * FROM {t} ORDER BY ALL" + (f" LIMIT {cap}" if cap else "")
            if cap and t in P.PBI_SAMPLE_FILTER:
                q = f"SELECT * FROM {t} WHERE {P.PBI_SAMPLE_FILTER[t]} ORDER BY ALL LIMIT {cap}"
            export(con, q, ROOT / "powerbi/data" / f"{t}.csv")
    tables = [r["table_name"] for r in rows(con, "SELECT table_name FROM information_schema.tables "
              "WHERE table_name LIKE 'a\\_%' ESCAPE '\\' OR table_name LIKE 'dq\\_%' ESCAPE '\\' ORDER BY 1")]
    for t in tables:
        export(con, f"SELECT * FROM {t} ORDER BY ALL LIMIT 500", res / "tables" / f"{t}.csv")

    kpi = rows(con, "SELECT * FROM a_kpi_headline")[0]
    asserts = rows(con, "SELECT * FROM dq_assertions")
    counts = rows(con, "SELECT * FROM dq_row_counts")
    metrics = {
        "project": P.REPO, "dataset": P.DATASET, "source_mode": a.source, "kpis": kpi,
        "data_quality": {"row_counts": counts, "issues": rows(con, "SELECT * FROM dq_issues"),
                         "assertions": {r["check_name"]: r["status"] for r in asserts}},
        "analysis": {k: rows(con, q) for k, q in P.METRIC_QUERIES.items()},
        "engine": {"duckdb": duckdb.__version__, "python": platform.python_version()},
        "sql_timings_s": timings,
    }
    res.mkdir(parents=True, exist_ok=True)
    (res / "metrics.json").write_text(jdump(metrics))
    shot = {"snapshot": "headline KPIs + run config", "project": P.REPO, "source_mode": a.source,
            "config": P.SHOT_CONFIG, "headline": kpi,
            "top": {k: rows(con, q) for k, q in P.SHOT_QUERIES.items()},
            "row_counts": {r["entity"]: r.get("clean_rows") for r in counts},
            "assertions_passed": sum(r["status"] == "PASS" for r in asserts), "assertions_total": len(asserts)}
    (res / "JSON.shot").write_text(jdump(shot))
    print(json.dumps(kpi, indent=1))

    out = res / "charts"; out.mkdir(parents=True, exist_ok=True)
    panels = []
    for v in P.VIZ:
        svg = chart(con, v)
        if svg:
            (out / f"{v['name']}.svg").write_text(svg); panels.append(svg)
    cards = [(lab, fmt.format(kpi[col])) for col, lab, fmt in P.CARDS]
    (out / "dashboard.svg").write_text(S.dashboard(P.DASH_TITLE + ("" if full else " (sample)"), cards, panels))
    print("charts ->", sorted(p.name for p in out.glob("*.svg")))


if __name__ == "__main__":
    main()
