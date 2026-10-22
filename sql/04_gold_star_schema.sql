-- 04 GOLD: star schema for BI (Power BI / Excel)
CREATE OR REPLACE TABLE dim_zone AS
SELECT CAST(LocationID AS INTEGER) AS zone_id, Borough AS borough, Zone AS zone_name, service_zone,
       Zone IN ('JFK Airport','LaGuardia Airport','Newark Airport') AS is_airport
FROM bronze_zones;

CREATE OR REPLACE TABLE dim_date AS
SELECT CAST(d AS DATE) AS date_key, year(d) AS year, month(d) AS month, monthname(d) AS month_name,
       day(d) AS day, isodow(d) AS weekday_num, dayname(d) AS weekday_name, isodow(d) >= 6 AS is_weekend,
       quarter(d) AS quarter
FROM range(DATE '2024-01-01', DATE '2025-01-01', INTERVAL 1 DAY) t(d);

CREATE OR REPLACE TABLE dim_payment_type AS
SELECT * FROM (VALUES (0,'Flex Fare / Unknown'),(1,'Credit card'),(2,'Cash'),(3,'No charge'),
                      (4,'Dispute'),(5,'Unknown'),(6,'Voided trip')) t(payment_type_id, payment_type);

CREATE OR REPLACE TABLE dim_vendor AS
SELECT * FROM (VALUES (1,'Creative Mobile Technologies'),(2,'Curb Mobility (VeriFone)'),
                      (6,'Myle Technologies'),(7,'Helix')) t(vendor_id, vendor_name);

CREATE OR REPLACE TABLE fact_trips AS
SELECT trip_id, pickup_date AS date_key, vendor_id, payment_type_id, pu_zone_id, do_zone_id, ratecode_id,
       pickup_ts, dropoff_ts, pickup_hour, pickup_weekday, passenger_count, trip_distance, duration_min,
       speed_mph, fare_amount, tip_amount, tolls_amount, extra + mta_tax + improvement_surcharge +
       congestion_surcharge + airport_fee AS surcharges, total_amount, tip_pct
FROM silver_trips;
