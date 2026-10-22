-- 05 BUSINESS ANALYSIS on the gold star schema (CTEs, window functions, RANK, NTILE)

-- Monthly trend with MoM growth (LAG)
CREATE OR REPLACE TABLE out_monthly_trend AS
WITH m AS (
  SELECT d.month, d.month_name, COUNT(*) AS trips, ROUND(SUM(f.total_amount),2) AS revenue,
         ROUND(AVG(f.total_amount),2) AS avg_ticket
  FROM fact_trips f JOIN dim_date d USING (date_key) GROUP BY ALL)
SELECT *, ROUND(100.0*(trips - LAG(trips) OVER w)/LAG(trips) OVER w, 2) AS trips_mom_pct,
          ROUND(100.0*(revenue - LAG(revenue) OVER w)/LAG(revenue) OVER w, 2) AS revenue_mom_pct
FROM m WINDOW w AS (ORDER BY month) ORDER BY month;

-- Peak hours heatmap (weekday x hour)
CREATE OR REPLACE TABLE out_hour_weekday_heatmap AS
SELECT pickup_weekday, pickup_hour, COUNT(*) AS trips, ROUND(AVG(total_amount),2) AS avg_total
FROM fact_trips GROUP BY ALL ORDER BY 1,2;

-- Top pickup zones with RANK
CREATE OR REPLACE TABLE out_top_pickup_zones AS
SELECT * FROM (
  SELECT z.borough, z.zone_name, COUNT(*) AS trips, ROUND(SUM(f.total_amount),2) AS revenue,
         RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
  FROM fact_trips f JOIN dim_zone z ON f.pu_zone_id = z.zone_id GROUP BY ALL) WHERE rnk <= 20 ORDER BY rnk;

CREATE OR REPLACE TABLE out_top_dropoff_zones AS
SELECT * FROM (
  SELECT z.borough, z.zone_name, COUNT(*) AS trips, RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
  FROM fact_trips f JOIN dim_zone z ON f.do_zone_id = z.zone_id GROUP BY ALL) WHERE rnk <= 20 ORDER BY rnk;

-- Top routes (pickup -> dropoff, excluding same-zone)
CREATE OR REPLACE TABLE out_top_routes AS
WITH r AS (
  SELECT pu.zone_name AS pickup_zone, dz.zone_name AS dropoff_zone, COUNT(*) AS trips,
         ROUND(AVG(f.total_amount),2) AS avg_total, ROUND(AVG(f.duration_min),1) AS avg_duration_min
  FROM fact_trips f JOIN dim_zone pu ON f.pu_zone_id = pu.zone_id JOIN dim_zone dz ON f.do_zone_id = dz.zone_id
  WHERE f.pu_zone_id <> f.do_zone_id GROUP BY ALL)
SELECT *, RANK() OVER (ORDER BY trips DESC) AS rnk FROM r QUALIFY rnk <= 20 ORDER BY rnk;

-- Airport trips
CREATE OR REPLACE TABLE out_airport_trips AS
SELECT CASE WHEN pu.is_airport THEN pu.zone_name ELSE dz.zone_name END AS airport,
       CASE WHEN pu.is_airport THEN 'From airport' ELSE 'To airport' END AS direction,
       COUNT(*) AS trips, ROUND(SUM(f.total_amount),2) AS revenue, ROUND(AVG(f.total_amount),2) AS avg_total,
       ROUND(AVG(f.trip_distance),2) AS avg_miles
FROM fact_trips f
JOIN dim_zone pu ON f.pu_zone_id = pu.zone_id JOIN dim_zone dz ON f.do_zone_id = dz.zone_id
WHERE pu.is_airport OR dz.is_airport GROUP BY ALL ORDER BY trips DESC;

CREATE OR REPLACE TABLE out_airport_share AS
SELECT ROUND(100.0*COUNT(*) FILTER (WHERE pu.is_airport OR dz.is_airport)/COUNT(*),2) AS airport_trip_pct,
       ROUND(100.0*SUM(total_amount) FILTER (WHERE pu.is_airport OR dz.is_airport)/SUM(total_amount),2) AS airport_revenue_pct
FROM fact_trips f JOIN dim_zone pu ON f.pu_zone_id = pu.zone_id JOIN dim_zone dz ON f.do_zone_id = dz.zone_id;

-- Tipping by payment type (cash tips are not recorded by TLC)
CREATE OR REPLACE TABLE out_tips_by_payment AS
SELECT p.payment_type, COUNT(*) AS trips, ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS share_pct,
       ROUND(AVG(f.tip_pct),2) AS avg_tip_pct, ROUND(AVG(f.tip_amount),2) AS avg_tip,
       ROUND(100.0*AVG((f.tip_amount>0)::INT),2) AS pct_trips_tipped
FROM fact_trips f JOIN dim_payment_type p USING (payment_type_id) GROUP BY ALL ORDER BY trips DESC;

-- Average fare per mile by pickup borough
CREATE OR REPLACE TABLE out_fare_per_mile_borough AS
SELECT z.borough, COUNT(*) AS trips, ROUND(SUM(f.fare_amount)/SUM(f.trip_distance),2) AS fare_per_mile,
       ROUND(AVG(f.trip_distance),2) AS avg_miles, ROUND(AVG(f.speed_mph),1) AS avg_speed_mph
FROM fact_trips f JOIN dim_zone z ON f.pu_zone_id = z.zone_id GROUP BY ALL ORDER BY trips DESC;

-- Zone revenue deciles with NTILE: how concentrated is revenue?
CREATE OR REPLACE TABLE out_zone_revenue_deciles AS
WITH z AS (SELECT pu_zone_id, SUM(total_amount) AS revenue FROM fact_trips GROUP BY 1),
d AS (SELECT *, NTILE(10) OVER (ORDER BY revenue DESC) AS decile FROM z)
SELECT decile, COUNT(*) AS zones, ROUND(SUM(revenue),2) AS revenue,
       ROUND(100.0*SUM(revenue)/SUM(SUM(revenue)) OVER (),2) AS revenue_share_pct
FROM d GROUP BY decile ORDER BY decile;

-- Vendor KPIs
CREATE OR REPLACE TABLE out_vendor_kpis AS
SELECT v.vendor_name, COUNT(*) AS trips, ROUND(SUM(f.total_amount),2) AS revenue, ROUND(AVG(f.duration_min),1) AS avg_duration_min
FROM fact_trips f LEFT JOIN dim_vendor v USING (vendor_id) GROUP BY ALL ORDER BY trips DESC;
