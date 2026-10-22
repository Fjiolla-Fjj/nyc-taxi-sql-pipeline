-- 02 DATA QUALITY: profile every issue on the raw bronze layer (counts + % of rows)
CREATE OR REPLACE TABLE rpt_data_quality AS
WITH b AS (
  SELECT *, date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime) / 60.0 AS dur_min
  FROM bronze_trips
), dup AS (
  SELECT SUM(c - 1) AS n FROM (
    SELECT COUNT(*) c FROM bronze_trips
    GROUP BY VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, PULocationID, DOLocationID,
             trip_distance, total_amount
    HAVING COUNT(*) > 1)
), checks AS (
  SELECT 'null_passenger_count' AS check_name, COUNT(*) FILTER (WHERE passenger_count IS NULL) AS n FROM b UNION ALL
  SELECT 'zero_passengers', COUNT(*) FILTER (WHERE passenger_count = 0) FROM b UNION ALL
  SELECT 'null_ratecode', COUNT(*) FILTER (WHERE RatecodeID IS NULL) FROM b UNION ALL
  SELECT 'negative_fare', COUNT(*) FILTER (WHERE fare_amount < 0) FROM b UNION ALL
  SELECT 'zero_fare', COUNT(*) FILTER (WHERE fare_amount = 0) FROM b UNION ALL
  SELECT 'negative_total_amount', COUNT(*) FILTER (WHERE total_amount < 0) FROM b UNION ALL
  SELECT 'zero_or_negative_distance', COUNT(*) FILTER (WHERE trip_distance <= 0) FROM b UNION ALL
  SELECT 'distance_over_200_miles', COUNT(*) FILTER (WHERE trip_distance > 200) FROM b UNION ALL
  SELECT 'dropoff_before_or_at_pickup', COUNT(*) FILTER (WHERE dur_min <= 0) FROM b UNION ALL
  SELECT 'duration_over_6_hours', COUNT(*) FILTER (WHERE dur_min > 360) FROM b UNION ALL
  SELECT 'speed_over_100_mph', COUNT(*) FILTER (WHERE dur_min > 0 AND trip_distance / (dur_min/60) > 100) FROM b UNION ALL
  SELECT 'pickup_outside_2024', COUNT(*) FILTER (WHERE year(tpep_pickup_datetime) <> 2024) FROM b UNION ALL
  SELECT 'pickup_month_mismatch_file', COUNT(*) FILTER (WHERE strftime(tpep_pickup_datetime, '%Y-%m') <> source_month) FROM b UNION ALL
  SELECT 'invalid_zone_id', COUNT(*) FILTER (WHERE PULocationID NOT BETWEEN 1 AND 263 OR DOLocationID NOT BETWEEN 1 AND 263) FROM b UNION ALL
  SELECT 'unknown_zone_264_265', COUNT(*) FILTER (WHERE PULocationID IN (264,265) OR DOLocationID IN (264,265)) FROM b UNION ALL
  SELECT 'invalid_payment_type', COUNT(*) FILTER (WHERE payment_type NOT BETWEEN 1 AND 6) FROM b UNION ALL
  SELECT 'duplicate_trips', (SELECT n FROM dup)
)
SELECT check_name, n AS issue_rows,
       ROUND(100.0 * n / (SELECT COUNT(*) FROM bronze_trips), 3) AS pct_of_rows
FROM checks ORDER BY issue_rows DESC;
