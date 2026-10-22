-- 06 RECONCILIATION: bronze -> silver -> gold. Every dropped row and every dollar is accounted for.
CREATE OR REPLACE TABLE rec_layer_totals AS
SELECT 'bronze' AS layer, COUNT(*) AS rows, ROUND(SUM(total_amount),2) AS total_amount FROM bronze_trips UNION ALL
SELECT 'silver', COUNT(*), ROUND(SUM(total_amount),2) FROM silver_trips UNION ALL
SELECT 'gold_fact', COUNT(*), ROUND(SUM(total_amount),2) FROM fact_trips;

CREATE OR REPLACE TABLE rec_drop_reasons AS
SELECT COALESCE(drop_reason, '00_kept_in_silver') AS reason, COUNT(*) AS rows,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),3) AS pct_of_bronze,
       ROUND(SUM(total_amount),2) AS total_amount
FROM stg_trips_tagged GROUP BY 1 ORDER BY 1;

-- The proof: bronze = silver + sum(dropped), for rows AND money. diff must be 0.
CREATE OR REPLACE TABLE rec_check AS
WITH b AS (SELECT COUNT(*) r, SUM(total_amount) a FROM bronze_trips),
     s AS (SELECT COUNT(*) r, SUM(total_amount) a FROM silver_trips),
     g AS (SELECT COUNT(*) r, SUM(total_amount) a FROM fact_trips),
     d AS (SELECT COUNT(*) r, SUM(total_amount) a FROM stg_trips_tagged WHERE drop_reason IS NOT NULL)
SELECT b.r AS bronze_rows, s.r AS silver_rows, d.r AS dropped_rows, b.r - s.r - d.r AS row_diff,
       ROUND(b.a - s.a - d.a, 2) AS amount_diff, s.r - g.r AS silver_vs_gold_row_diff,
       ROUND(s.a - g.a, 2) AS silver_vs_gold_amount_diff,
       CASE WHEN b.r - s.r - d.r = 0 AND ABS(b.a - s.a - d.a) < 0.01 AND s.r = g.r THEN 'PASS' ELSE 'FAIL' END AS status
FROM b, s, g, d;

-- Orphan check: every fact FK must resolve in its dimension
CREATE OR REPLACE TABLE rec_fk_orphans AS
SELECT 'pu_zone' AS fk, COUNT(*) AS orphans FROM fact_trips f ANTI JOIN dim_zone z ON f.pu_zone_id = z.zone_id UNION ALL
SELECT 'do_zone', COUNT(*) FROM fact_trips f ANTI JOIN dim_zone z ON f.do_zone_id = z.zone_id UNION ALL
SELECT 'date', COUNT(*) FROM fact_trips f ANTI JOIN dim_date d USING (date_key) UNION ALL
SELECT 'payment_type', COUNT(*) FROM fact_trips f ANTI JOIN dim_payment_type p USING (payment_type_id) UNION ALL
SELECT 'vendor', COUNT(*) FROM fact_trips f ANTI JOIN dim_vendor v USING (vendor_id);

-- Monthly reconciliation per source file
CREATE OR REPLACE TABLE rec_monthly AS
SELECT source_month, COUNT(*) AS bronze_rows, COUNT(*) FILTER (WHERE drop_reason IS NULL) AS silver_rows,
       ROUND(100.0*COUNT(*) FILTER (WHERE drop_reason IS NOT NULL)/COUNT(*),2) AS dropped_pct
FROM stg_trips_tagged GROUP BY 1 ORDER BY 1;
