-- ============================================================================
-- 03_clean_views.sql
--
-- What this does:
--   Builds two views on top of the raw table instead of writing cleaned data
--   to a new table. A view is a saved query - it re-runs against the raw
--   table every time it's queried, so the raw data stays untouched and the
--   cleaning logic stays visible and auditable in one place.
--
--   vw_valid_sales   - genuine completed sales lines only, with a computed
--                       sales_value column. This is what Power BI's sales
--                       and customer pages are built on.
--   vw_cancellations - the cancellation lines that vw_valid_sales excludes,
--                       kept separate so cancellations can be analysed on
--                       their own terms (Page 3 of the dashboard).
--
-- Business question answered:
--   What counts as a "real" sale for revenue and customer reporting, and
--   how significant are cancellations on their own?
-- ============================================================================

DROP VIEW IF EXISTS vw_valid_sales;

CREATE VIEW vw_valid_sales AS
SELECT
    invoice_no,
    stock_code,
    TRIM(description) AS product_name,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    ROUND(quantity * unit_price, 2) AS sales_value,
    DATE_TRUNC('month', invoice_date)::date AS order_month,
    invoice_date::date AS order_date
FROM online_retail_raw
WHERE invoice_no NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0
  AND customer_id IS NOT NULL
  AND description IS NOT NULL;

-- This view removes cancellations, invalid quantity/price records, missing
-- customer IDs, and missing descriptions. UCI documents that invoice numbers
-- starting with C indicate cancellations.

DROP VIEW IF EXISTS vw_cancellations;

CREATE VIEW vw_cancellations AS
SELECT
    invoice_no,
    stock_code,
    TRIM(description) AS product_name,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    ROUND(ABS(quantity * unit_price), 2) AS cancellation_value,
    DATE_TRUNC('month', invoice_date)::date AS cancellation_month
FROM online_retail_raw
WHERE invoice_no LIKE 'C%';

-- Sanity check on the cleaned data
SELECT
    COUNT(*)                      AS valid_sales_lines,
    COUNT(DISTINCT invoice_no)    AS valid_orders,
    COUNT(DISTINCT customer_id)   AS identified_customers,
    ROUND(SUM(sales_value), 2)    AS net_sales
FROM vw_valid_sales;
