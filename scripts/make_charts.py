"""Build PNG charts from the exported gold CSVs in outputs/."""
import csv, pathlib, matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt
R = pathlib.Path(__file__).resolve().parent.parent; O, I = R/"outputs", R/"images"; I.mkdir(exist_ok=True)
rd = lambda n: list(csv.DictReader(open(O/f"{n}.csv")))

m = rd("out_monthly_trend"); fig, ax = plt.subplots(figsize=(10,5))
ax.bar([r["month_name"][:3] for r in m], [float(r["revenue"])/1e6 for r in m], color="#2b6cb0")
ax2 = ax.twinx(); ax2.plot([r["month_name"][:3] for r in m], [int(r["trips"])/1e6 for r in m], "o-", color="#dd6b20")
ax.set_ylabel("Revenue ($M)"); ax2.set_ylabel("Trips (M)"); ax.set_title("2024 Monthly Revenue (bars) and Trips (line)")
fig.tight_layout(); fig.savefig(I/"01_monthly_trend.png", dpi=120)

h = rd("out_hour_weekday_heatmap"); g = [[0]*24 for _ in range(7)]
for r in h: g[int(r["pickup_weekday"])-1][int(r["pickup_hour"])] = int(r["trips"])/1e3
fig, ax = plt.subplots(figsize=(12,4)); im = ax.imshow(g, aspect="auto", cmap="YlOrRd")
ax.set_yticks(range(7), ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]); ax.set_xticks(range(24)); ax.set_xlabel("Pickup hour")
fig.colorbar(im, label="Trips (thousands)"); ax.set_title("Peak Hours Heatmap: trips by weekday x hour (2024)")
fig.tight_layout(); fig.savefig(I/"02_peak_hours_heatmap.png", dpi=120)

d = [r for r in rd("rec_drop_reasons") if not r["reason"].startswith("00")]
fig, ax = plt.subplots(figsize=(10,5)); ax.barh([r["reason"][3:] for r in d], [int(r["rows"]) for r in d], color="#c53030")
ax.invert_yaxis(); ax.set_xscale("log"); ax.set_xlabel("Rows dropped (log scale)"); ax.set_title("Bronze -> Silver: why 1,874,914 rows were dropped")
fig.tight_layout(); fig.savefig(I/"03_dropped_rows_by_reason.png", dpi=120)

z = rd("out_top_pickup_zones")[:10]; fig, ax = plt.subplots(figsize=(10,5))
ax.barh([r["zone_name"] for r in z], [float(r["revenue"])/1e6 for r in z], color="#2f855a"); ax.invert_yaxis()
ax.set_xlabel("Revenue ($M)"); ax.set_title("Top 10 pickup zones by trips - revenue shown (airports punch above their weight)")
fig.tight_layout(); fig.savefig(I/"04_top_pickup_zones.png", dpi=120)

t = rd("out_tips_by_payment"); fig, ax = plt.subplots(figsize=(8,5))
ax.bar([r["payment_type"] for r in t], [float(r["pct_trips_tipped"]) for r in t], color="#6b46c1")
ax.set_ylabel("% of trips with a recorded tip"); ax.set_title("Tipping by payment type (cash tips are not recorded)")
fig.tight_layout(); fig.savefig(I/"05_tips_by_payment.png", dpi=120)
