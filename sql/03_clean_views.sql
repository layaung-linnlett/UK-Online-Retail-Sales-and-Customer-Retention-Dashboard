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

-- CASCADE, so this script can be re-run. Everything downstream is built on
-- vw_valid_sales - the customer profile in 05, the cadence views in 06 and 11,
-- the corrected sales view in 07 - and Postgres refuses to drop a view that
-- still has dependents. CASCADE removes them too, which is correct: they are
-- all rebuilt by re-running scripts 04-11 in order, and a dependent view left
-- pointing at an old definition would be worse than one that is missing.
DROP VIEW IF EXISTS vw_valid_sales CASCADE;

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

-- CASCADE for the same reason: vw_valid_sales_net (07) is defined against
-- vw_cancellations and would block the drop on a re-run.
DROP VIEW IF EXISTS vw_cancellations CASCADE;

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
    invoice_date::date AS cancellation_date,
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


-- ============================================================================
-- vw_all_invoices - one row per invoice, from the RAW table
--
-- Why this exists:
--   The cancellation rate was originally calculated as cancelled invoices
--   (counted from the raw table) divided by cancelled + valid orders (counted
--   from vw_valid_sales, AFTER rows with no customer ID were removed). Those
--   are two different populations, and the mismatch inflated the rate to
--   17.15% when the consistent figure is 14.81%.
--
--   It also could not be filtered. vw_valid_sales is related to the report's
--   date table and vw_cancellations is not, so any date filter shrank the
--   denominator and left the numerator whole - February 2011 returned 79%
--   against a true 15.7%.
--
--   This view fixes both at once: every invoice in the dataset, cancelled or
--   not, from one source, each with a date. Counting both sides of the
--   fraction from here gives a rate that is consistent AND filters correctly.
--
-- Business question answered:
--   What share of invoices raised were cancellations, and how does that move
--   month to month?
-- ============================================================================

DROP VIEW IF EXISTS vw_all_invoices CASCADE;

CREATE VIEW vw_all_invoices AS
SELECT
    invoice_no,
    (invoice_no LIKE 'C%')                          AS is_cancellation,
    MIN(invoice_date)::date                         AS invoice_date,
    DATE_TRUNC('month', MIN(invoice_date))::date    AS invoice_month,
    MIN(country)                                    AS country
FROM online_retail_raw
GROUP BY invoice_no, (invoice_no LIKE 'C%');
