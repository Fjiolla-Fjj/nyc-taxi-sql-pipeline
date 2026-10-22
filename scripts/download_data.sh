#!/usr/bin/env bash
# Download NYC TLC Yellow Taxi trip records (2024) + zone lookup into data/raw/
set -euo pipefail
YEAR=${YEAR:-2024}
BASE=https://d37ci6vzurychx.cloudfront.net
mkdir -p data/raw
for m in 01 02 03 04 05 06 07 08 09 10 11 12; do
  f=yellow_tripdata_${YEAR}-${m}.parquet
  [ -f data/raw/$f ] || curl -fsSL -o data/raw/$f "$BASE/trip-data/$f"
done
[ -f data/raw/taxi_zone_lookup.csv ] || curl -fsSL -o data/raw/taxi_zone_lookup.csv "$BASE/misc/taxi_zone_lookup.csv"
du -sh data/raw
