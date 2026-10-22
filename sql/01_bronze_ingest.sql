-- 01 BRONZE: raw load of all monthly parquet files, untouched, with lineage
CREATE OR REPLACE TABLE bronze_trips AS
SELECT *, regexp_extract(filename, 'yellow_tripdata_(\d{4}-\d{2})', 1) AS source_month
FROM read_parquet('data/raw/yellow_tripdata_*.parquet', union_by_name = true, filename = true);

CREATE OR REPLACE TABLE bronze_zones AS
SELECT * FROM read_csv_auto('data/raw/taxi_zone_lookup.csv', header = true);

-- Row counts per source file (ingestion audit)
CREATE OR REPLACE TABLE rpt_bronze_file_counts AS
SELECT source_month, COUNT(*) AS rows_loaded,
       ROUND(SUM(total_amount), 2) AS total_amount_sum
FROM bronze_trips GROUP BY source_month ORDER BY source_month;
