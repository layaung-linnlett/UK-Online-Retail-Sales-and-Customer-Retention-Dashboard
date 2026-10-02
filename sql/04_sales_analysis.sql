-- ============================================================================
-- 04_sales_analysis.sql
--
-- What this does:
--   Runs the sales-side analysis queries against vw_valid_sales_net (sales net of reversed orders): overall
--   KPIs, the monthly trend, month-on-month growth (using LAG), top
--   products, sales by country, and international sales excluding the UK.
--   These queries are the direct source for Power BI Page 1 (Sales
--   overview) and their results are also exported to
--   outputs/query_results/ so the Power BI numbers can be checked against
--   something independent.
--
-- Business question answered:
--   How are net sales and order volume changing over time, and which
--   products and countries should receive more sales focus?
-- ============================================================================

-- Overall KPIs
SELECT
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(sales_value) / COUNT(DISTINCT invoice_no), 2) AS average_order_value,
    ROUND(SUM(quantity)::NUMERIC / COUNT(DISTINCT invoice_no), 2) AS average_items_per_order
FROM vw_valid_sales_net;

-- Monthly sales trend
SELECT
    order_month,
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS orders,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(SUM(sales_value) / COUNT(DISTINCT invoice_no), 2) AS average_order_value
FROM vw_valid_sales_net
GROUP BY order_month
ORDER BY order_month;

-- Month-on-month growth
-- LAG() looks back one row (one month, because the outer query is ordered by
-- order_month) without collapsing the current row, so each month can be
-- compared to the one before it in a single pass.
WITH monthly_sales AS (
    SELECT
        order_month,
        SUM(sales_value) AS net_sales
    FROM vw_valid_sales_net
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(net_sales, 2) AS net_sales,
    ROUND(net_sales - LAG(net_sales) OVER (ORDER BY order_month), 2) AS month_on_month_change,
    ROUND(
        100.0 * (net_sales - LAG(net_sales) OVER (ORDER BY order_month))
        / NULLIF(LAG(net_sales) OVER (ORDER BY order_month), 0),
        2
    ) AS month_on_month_growth_pct
FROM monthly_sales
ORDER BY order_month;

-- Top 10 products by net sales
SELECT
    product_name,
    SUM(quantity) AS units_sold,
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS orders
FROM vw_valid_sales_net
GROUP BY product_name
ORDER BY net_sales DESC
LIMIT 10;

-- Sales by country
SELECT
    country,
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS orders,
    COUNT(DISTINCT customer_id) AS customers
FROM vw_valid_sales_net
GROUP BY country
ORDER BY net_sales DESC;

-- Top 10 international countries excluding the UK
SELECT
    country,
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS orders,
    ROUND(100.0 * SUM(sales_value) / SUM(SUM(sales_value)) OVER (), 2) AS share_of_international_sales_pct
FROM vw_valid_sales_net
WHERE country <> 'United Kingdom'
GROUP BY country
ORDER BY net_sales DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Supplementary queries for Power BI Page 3 (Cancellations and products)
-- Written in the same style as the rest of this file, against
-- vw_cancellations and vw_valid_sales, to give Page 3's visuals something
-- to be checked against.
-- ----------------------------------------------------------------------------

-- Cancellation KPIs (rate = cancelled invoices / (cancelled invoices + valid orders))
SELECT
    COUNT(DISTINCT c.invoice_no) AS cancelled_invoices,
    ROUND(SUM(c.cancellation_value), 2) AS cancellation_value,
    (SELECT COUNT(DISTINCT invoice_no) FROM vw_valid_sales) AS valid_orders,
    ROUND(
        100.0 * COUNT(DISTINCT c.invoice_no)
        / (COUNT(DISTINCT c.invoice_no) + (SELECT COUNT(DISTINCT invoice_no) FROM vw_valid_sales)),
        2
    ) AS cancellation_rate_pct
FROM vw_cancellations c;

-- Cancelled value over time (by month)
SELECT
    cancellation_month,
    ROUND(SUM(cancellation_value), 2) AS cancelled_value,
    COUNT(DISTINCT invoice_no) AS cancelled_invoices
FROM vw_cancellations
GROUP BY cancellation_month
ORDER BY cancellation_month;

-- Most cancelled products by cancellation value
SELECT
    product_name,
    SUM(quantity) AS units_cancelled,
    ROUND(SUM(cancellation_value), 2) AS cancelled_value,
    COUNT(DISTINCT invoice_no) AS cancelled_invoices
FROM vw_cancellations
GROUP BY product_name
ORDER BY cancelled_value DESC
LIMIT 10;

-- Top 10 products by quantity sold (distinct from "top products by net sales")
SELECT
    product_name,
    SUM(quantity) AS units_sold,
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS orders
FROM vw_valid_sales_net
GROUP BY product_name
ORDER BY units_sold DESC
LIMIT 10;

-- Full product sales table (for the Page 1 / Page 3 detail tables)
SELECT
    product_name,
    SUM(quantity) AS units_sold,
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS orders,
    ROUND(SUM(sales_value) / NULLIF(SUM(quantity), 0), 2) AS average_unit_value
FROM vw_valid_sales_net
GROUP BY product_name
ORDER BY net_sales DESC;

-- What is actually inside the cancellation total?
--
-- The cancellation figure is often quoted as if it were a returns figure. It
-- is not. This query splits it into four categories so the returns number can
-- be stated on its own.
--
-- The split is by stock_code, because the non-merchandise entries in this
-- dataset are recorded under codes that are not product codes:
--   AMAZONFEE, M (Manual), CRUK, BANK CHARGES, D (Discount), S (SAMPLES)
--     - marketplace fees and accounting adjustments, not returns
--   POST, C2 (CARRIAGE), DOT (DOTCOM POSTAGE)
--     - shipping refunds, listed separately because they usually accompany a
--       genuine return rather than being one
--   C581484 - the single 80,995-unit keying error, reversed twelve minutes
--     after it was entered. Not a return either, and large enough to distort
--     the total on its own, so it is isolated rather than left in.
SELECT
    CASE
        WHEN stock_code IN ('AMAZONFEE', 'M', 'CRUK', 'BANK CHARGES', 'D', 'S')
            THEN '1. Fees and accounting adjustments'
        WHEN stock_code IN ('POST', 'C2', 'DOT')
            THEN '2. Shipping and carriage refunds'
        WHEN invoice_no = 'C581484'
            THEN '3. The 80,995-unit keying error'
        ELSE '4. Merchandise returned by a customer'
    END AS category,
    COUNT(*) AS cancellation_lines,
    ROUND(SUM(cancellation_value), 2) AS cancelled_value,
    ROUND(100.0 * SUM(cancellation_value) / SUM(SUM(cancellation_value)) OVER (), 2) AS pct_of_cancelled_value
FROM vw_cancellations
GROUP BY 1
ORDER BY 1;

-- The same non-merchandise entries, itemised, so each one can be checked.
SELECT
    stock_code,
    product_name,
    COUNT(*) AS cancellation_lines,
    ROUND(SUM(cancellation_value), 2) AS cancelled_value
FROM vw_cancellations
WHERE stock_code IN ('AMAZONFEE', 'M', 'CRUK', 'BANK CHARGES', 'D', 'S',
                     'POST', 'C2', 'DOT')
GROUP BY stock_code, product_name
ORDER BY cancelled_value DESC;

-- Cancellation rate, counted consistently from vw_all_invoices.
-- This is the corrected version of the "Cancellation KPIs" query above, which
-- divides a raw-table numerator by a cleaned-view denominator and reports
-- 17.15%. Both are kept so the difference can be seen rather than asserted.
SELECT
    COUNT(*)                                            AS total_invoices,
    COUNT(*) FILTER (WHERE is_cancellation)             AS cancelled_invoices,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_cancellation) / COUNT(*), 2)
                                                        AS cancellation_rate_pct
FROM vw_all_invoices;

-- The same rate by month, which the original calculation could not produce
-- at all because its two halves came from tables on different date grains.
SELECT
    invoice_month,
    COUNT(*)                                            AS invoices,
    COUNT(*) FILTER (WHERE is_cancellation)             AS cancelled_invoices,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_cancellation) / COUNT(*), 2)
                                                        AS cancellation_rate_pct
FROM vw_all_invoices
GROUP BY invoice_month
ORDER BY invoice_month;
