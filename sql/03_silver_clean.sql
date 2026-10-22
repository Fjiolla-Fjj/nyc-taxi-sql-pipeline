-- 03 SILVER: tag each bronze row with the FIRST rule it fails, keep only clean rows.
-- Tagging (instead of silently filtering) lets 06_reconciliation explain every dropped row.
CREATE OR REPLACE TABLE stg_trips_tagged AS
WITH base AS (
  SELECT *,
    date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime) / 60.0 AS duration_min,
    ROW_NUMBER() OVER (PARTITION BY VendorID, tpep_pickup_datetime, tpep_dropoff_datetime,
                       PULocationID, DOLocationID, trip_distance, total_amount ORDER BY source_month) AS dup_rank
  FROM bronze_trips
)
SELECT *,
  CASE
    WHEN dup_rank > 1                                            THEN '01_duplicate'
    WHEN year(tpep_pickup_datetime) <> 2024                      THEN '02_pickup_outside_2024'
    WHEN duration_min <= 0                                       THEN '03_non_positive_duration'
    WHEN duration_min > 360                                      THEN '04_duration_over_6h'
    WHEN trip_distance <= 0 OR trip_distance > 200               THEN '05_invalid_distance'
    WHEN fare_amount <= 0 OR total_amount <= 0                   THEN '06_non_positive_fare'
    WHEN trip_distance / (duration_min / 60) > 100               THEN '07_speed_over_100mph'
    WHEN PULocationID NOT BETWEEN 1 AND 263
      OR DOLocationID NOT BETWEEN 1 AND 263                      THEN '08_unknown_zone'
    ELSE NULL
  END AS drop_reason
FROM base;

CREATE OR REPLACE TABLE silver_trips AS
SELECT
  ROW_NUMBER() OVER (ORDER BY tpep_pickup_datetime) AS trip_id,
  CAST(VendorID AS INTEGER)               AS vendor_id,
  tpep_pickup_datetime                    AS pickup_ts,
  tpep_dropoff_datetime                   AS dropoff_ts,
  CAST(passenger_count AS INTEGER)        AS passenger_count,
  (passenger_count IS NULL OR passenger_count = 0) AS passenger_count_missing,
  trip_distance,
  CAST(COALESCE(RatecodeID, 99) AS INTEGER) AS ratecode_id,
  PULocationID AS pu_zone_id, DOLocationID AS do_zone_id,
  CAST(payment_type AS INTEGER)           AS payment_type_id,
  fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge,
  COALESCE(congestion_surcharge, 0) AS congestion_surcharge,
  COALESCE(Airport_fee, 0)          AS airport_fee,
  total_amount,
  ROUND(duration_min, 2)                              AS duration_min,
  ROUND(trip_distance / (duration_min / 60), 2)       AS speed_mph,
  ROUND(100 * tip_amount / fare_amount, 2)            AS tip_pct,
  CAST(tpep_pickup_datetime AS DATE)                  AS pickup_date,
  hour(tpep_pickup_datetime)                          AS pickup_hour,
  isodow(tpep_pickup_datetime)                        AS pickup_weekday,  -- 1=Mon
  source_month
FROM stg_trips_tagged WHERE drop_reason IS NULL;
