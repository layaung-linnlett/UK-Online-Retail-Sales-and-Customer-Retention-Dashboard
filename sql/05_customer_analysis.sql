-- ============================================================================
-- 05_customer_analysis.sql
--
-- What this does:
--   Builds vw_customer_profile, a per-customer summary (first/last order,
--   order count, spend, average order value, spend quintile) and assigns
--   each customer a retention segment. Inactivity is measured against the
--   dataset's own maximum order date, not today's date, because the data
--   ends in December 2011 - comparing to today's date would mark every
--   customer as inactive. Then runs the segment summary, retention priority
--   list, and top-customer queries that feed Power BI Page 2.
--
-- Business question answered:
--   Which customers are the most valuable, and which high-value repeat
--   customers have gone quiet and should be prioritised for retention
--   outreach?
--
-- At-risk definition:
--   A customer with at least two orders who has not placed an order in more
--   than 90 days relative to the last transaction in the dataset. This is an
--   inactivity-based segmentation rule, not a machine-learning churn model.
--   The GBP 1,000 high-value threshold is a starter business rule - spend_quintile
--   (built with NTILE(5)) is included so it can be swapped in later as a
--   relative "top 20% by spend" definition instead of a fixed cutoff.
-- ============================================================================

DROP VIEW IF EXISTS vw_customer_profile;

CREATE VIEW vw_customer_profile AS
WITH dataset_end AS (
    SELECT MAX(order_date) AS dataset_end_date
    FROM vw_valid_sales
),
customer_summary AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        COUNT(DISTINCT invoice_no) AS total_orders,
        SUM(quantity) AS total_items,
        ROUND(SUM(sales_value), 2) AS total_spend,
        ROUND(SUM(sales_value) / COUNT(DISTINCT invoice_no), 2) AS average_order_value
    FROM vw_valid_sales
    GROUP BY customer_id
)
SELECT
    cs.customer_id,
    cs.first_order_date,
    cs.last_order_date,
    de.dataset_end_date,
    (de.dataset_end_date - cs.last_order_date) AS days_since_last_order,
    cs.total_orders,
    cs.total_items,
    cs.total_spend,
    cs.average_order_value,
    NTILE(5) OVER (ORDER BY cs.total_spend DESC) AS spend_quintile,
    CASE
        WHEN cs.total_orders >= 2
             AND cs.total_spend >= 1000
             AND (de.dataset_end_date - cs.last_order_date) <= 90
            THEN 'High-value active'
        WHEN cs.total_orders >= 2
             AND cs.total_spend >= 1000
             AND (de.dataset_end_date - cs.last_order_date) > 90
            THEN 'High-value at risk'
        WHEN cs.total_orders >= 2
             AND (de.dataset_end_date - cs.last_order_date) <= 90
            THEN 'Active repeat customer'
        WHEN cs.total_orders >= 2
             AND (de.dataset_end_date - cs.last_order_date) > 90
            THEN 'At-risk repeat customer'
        ELSE 'One-time customer'
    END AS customer_segment
FROM customer_summary AS cs
CROSS JOIN dataset_end AS de;

-- Customer segment summary
SELECT
    customer_segment,
    COUNT(*) AS customers,
    ROUND(SUM(total_spend), 2) AS total_sales,
    ROUND(AVG(total_spend), 2) AS average_customer_spend
FROM vw_customer_profile
GROUP BY customer_segment
ORDER BY total_sales DESC;

-- Retention priority list: high-value customers who have gone quiet
SELECT
    customer_id,
    total_spend,
    total_orders,
    average_order_value,
    last_order_date,
    days_since_last_order,
    customer_segment
FROM vw_customer_profile
WHERE customer_segment = 'High-value at risk'
ORDER BY total_spend DESC;

-- Top 20 customers by spend
SELECT
    customer_id,
    total_spend,
    total_orders,
    average_order_value,
    last_order_date,
    DENSE_RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
FROM vw_customer_profile
ORDER BY total_spend DESC
LIMIT 20;
