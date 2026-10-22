"""Run the NYC Taxi SQL pipeline end to end on DuckDB, time each layer, export reports/aggregates to outputs/."""
import duckdb, pathlib, time, os, json

ROOT = pathlib.Path(__file__).resolve().parent.parent
os.chdir(ROOT)
con = duckdb.connect("data/nyc_taxi.duckdb")
con.execute("SET memory_limit='8GB'; SET temp_directory='data/tmp'; SET preserve_insertion_order=false;")

timings, t0 = {}, time.time()
for f in sorted((ROOT / "sql").glob("*.sql")):
    s = time.time()
    con.execute(f.read_text())
    timings[f.name] = round(time.time() - s, 1)
    print(f"{f.name:32s} {timings[f.name]:>7.1f}s")
timings["total_seconds"] = round(time.time() - t0, 1)
print(f"TOTAL {timings['total_seconds']}s")

out = ROOT / "outputs"; out.mkdir(exist_ok=True)
tables = [r[0] for r in con.execute("SELECT table_name FROM information_schema.tables").fetchall()]
for t in tables:
    if t.startswith(("rpt_", "rec_", "out_", "dim_")) and t != "dim_date":
        con.execute(f"COPY {t} TO 'outputs/{t}.csv' (HEADER)")
(out / "pipeline_timings.json").write_text(json.dumps(timings, indent=2))
for t in ("rec_check", "rec_layer_totals"):
    print(con.sql(f"SELECT * FROM {t}"))
