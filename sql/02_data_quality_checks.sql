-- ============================================================================
-- 02_data_quality_checks.sql
--
-- What this does:
--   Profiles the raw table before any cleaning happens: row count, date
--   range, missing values, cancellation volume, non-positive quantity/price,
--   and country coverage. The results are not used in the dashboard directly
--   - they are the evidence base for every cleaning decision made in
--   03_clean_views.sql, and they are written up in DATA_QUALITY_FINDINGS.md.
--
-- Business question answered:
--   Is this dataset trustworthy enough to build a sales dashboard on, and
--   what do I need to exclude or flag before analysing it?
-- ============================================================================

-- 1. Total raw records
SELECT COUNT(*) AS total_rows
FROM online_retail_raw;

-- 2. Date range
SELECT
    MIN(invoice_date) AS earliest_transaction,
    MAX(invoice_date) AS latest_transaction
FROM online_retail_raw;

-- 3. Missing values
SELECT
    COUNT(*) FILTER (WHERE invoice_no   IS NULL) AS missing_invoice_no,
    COUNT(*) FILTER (WHERE stock_code   IS NULL) AS missing_stock_code,
    COUNT(*) FILTER (WHERE description  IS NULL) AS missing_description,
    COUNT(*) FILTER (WHERE customer_id  IS NULL) AS missing_customer_id,
    COUNT(*) FILTER (WHERE country      IS NULL) AS missing_country
FROM online_retail_raw;

-- 4. Cancellation invoices (UCI docs: invoice numbers starting with C are cancellations)
SELECT
    COUNT(DISTINCT invoice_no) AS cancelled_invoices,
    COUNT(*)                   AS cancellation_lines
FROM online_retail_raw
WHERE invoice_no LIKE 'C%';

-- 5. Non-positive quantity and price
SELECT
    COUNT(*) FILTER (WHERE quantity   <= 0) AS non_positive_quantity,
    COUNT(*) FILTER (WHERE unit_price <= 0) AS non_positive_price
FROM online_retail_raw;

-- 6. Countries represented
SELECT
    country,
    COUNT(DISTINCT invoice_no) AS invoices
FROM online_retail_raw
GROUP BY country
ORDER BY invoices DESC;
