-- ============================================================================
-- 04_sales_analysis.sql
--
-- What this does:
--   Runs the sales-side analysis queries against vw_valid_sales: overall
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
FROM vw_valid_sales;

-- Monthly sales trend
SELECT
    order_month,
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS orders,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(SUM(sales_value) / COUNT(DISTINCT invoice_no), 2) AS average_order_value
FROM vw_valid_sales
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
    FROM vw_valid_sales
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
FROM vw_valid_sales
GROUP BY product_name
ORDER BY net_sales DESC
LIMIT 10;

-- Sales by country
SELECT
    country,
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS orders,
    COUNT(DISTINCT customer_id) AS customers
FROM vw_valid_sales
GROUP BY country
ORDER BY net_sales DESC;

-- Top 10 international countries excluding the UK
SELECT
    country,
    ROUND(SUM(sales_value), 2) AS net_sales,
    COUNT(DISTINCT invoice_no) AS orders,
    ROUND(100.0 * SUM(sales_value) / SUM(SUM(sales_value)) OVER (), 2) AS share_of_international_sales_pct
FROM vw_valid_sales
WHERE country <> 'United Kingdom'
GROUP BY country
ORDER BY net_sales DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Supplementary queries for Power BI Page 3 (Cancellations and products)
-- The project plan doesn't hand these ones over ready-made, so they're
-- written here in the same style as the rest of this file, against
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
FROM vw_valid_sales
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
FROM vw_valid_sales
GROUP BY product_name
ORDER BY net_sales DESC;
