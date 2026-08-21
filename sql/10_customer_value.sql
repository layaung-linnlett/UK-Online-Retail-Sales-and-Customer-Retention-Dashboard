-- ============================================================================
-- 10_customer_value.sql
--
-- What this does:
--   Reports what a customer is actually worth, using only observed spend in
--   the period covered by the data. Compares one-time buyers with repeat
--   buyers, then breaks value down by how many times a customer bought.
--
--   Built on vw_valid_sales_net (reversal-corrected).
--
-- Business question answered:
--   What is a customer worth to us, and how much of that value depends on
--   them coming back?
--
-- DELIBERATELY NOT A CLV MODEL:
--   Every figure here is money already taken, over the twelve months the
--   data covers. Nothing is projected forward, no discount rate is applied,
--   no expected future lifetime is assumed. "Customer value" below means
--   observed revenue to date, not predicted lifetime value. With one year
--   of history and no post-period observation, a CLV model would have
--   nothing to validate against - it would be an assumption wearing a
--   number's clothing.
--
-- WHY THE MEDIAN IS QUOTED ALONGSIDE THE MEAN EVERYWHERE:
--   Revenue is heavily concentrated (see 07_revenue_concentration.sql).
--   Removing just ten customers moves the mean by 16% and the median by
--   0.3%. The mean describes the total divided up; the median describes a
--   customer you would actually recognise. Query 2 makes this explicit.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. What a customer is worth - the full distribution, not just the average
-- ----------------------------------------------------------------------------
WITH customer_value AS (
    SELECT customer_id,
           SUM(sales_value)           AS spend,
           COUNT(DISTINCT order_date) AS purchase_occasions,
           SUM(quantity)              AS items
    FROM vw_valid_sales_net GROUP BY customer_id
)
SELECT
    COUNT(*)                      AS customers,
    ROUND(SUM(spend), 2)          AS total_revenue,
    ROUND(AVG(spend), 2)          AS mean_spend,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY spend)::numeric, 2) AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY spend)::numeric, 2) AS median_spend,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY spend)::numeric, 2) AS p75,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY spend)::numeric, 2) AS p90,
    ROUND(MAX(spend), 2)          AS largest_customer
FROM customer_value;


-- ----------------------------------------------------------------------------
-- 2. Why the mean is the wrong number to quote to a board
--    Ten customers out of 4,327 move it by 16%. They barely touch the median.
-- ----------------------------------------------------------------------------
WITH customer_value AS (
    SELECT customer_id, SUM(sales_value) AS spend
    FROM vw_valid_sales_net GROUP BY customer_id
),
ranked AS (
    SELECT customer_id, spend, ROW_NUMBER() OVER (ORDER BY spend DESC) AS rn
    FROM customer_value
)
SELECT 'All customers' AS basis, COUNT(*) AS customers,
       ROUND(AVG(spend), 2) AS mean_spend,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY spend)::numeric, 2) AS median_spend
FROM ranked
UNION ALL
SELECT 'Excluding the top 10', COUNT(*), ROUND(AVG(spend), 2),
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY spend)::numeric, 2)
FROM ranked WHERE rn > 10
UNION ALL
SELECT 'Excluding the top 1% (43 customers)', COUNT(*), ROUND(AVG(spend), 2),
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY spend)::numeric, 2)
FROM ranked WHERE rn > 43;


-- ----------------------------------------------------------------------------
-- 3. THE HEADLINE - one-time buyers versus repeat buyers
-- ----------------------------------------------------------------------------
WITH customer_value AS (
    SELECT customer_id, SUM(sales_value) AS spend,
           COUNT(DISTINCT order_date) AS purchase_occasions
    FROM vw_valid_sales_net GROUP BY customer_id
)
SELECT
    CASE WHEN purchase_occasions = 1 THEN 'One-time buyer' ELSE 'Repeat buyer' END AS customer_group,
    COUNT(*)                                                    AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_of_customers,
    ROUND(SUM(spend), 2)                                        AS revenue,
    ROUND(100.0 * SUM(spend) / SUM(SUM(spend)) OVER (), 1)      AS pct_of_revenue,
    ROUND(AVG(spend), 2)                                        AS mean_spend,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY spend)::numeric, 2) AS median_spend,
    ROUND(AVG(purchase_occasions), 1)                           AS avg_purchases
FROM customer_value
GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- 4. THE VALUE LADDER - and the finding that matters
--
--    Read the last column. Value per purchase is flat at roughly GBP 390-420
--    from the first purchase all the way to the tenth. It only rises in the
--    11+ band. Customer value is therefore built almost entirely from HOW
--    OFTEN someone buys, not from how much they spend each time.
-- ----------------------------------------------------------------------------
WITH customer_value AS (
    SELECT customer_id, SUM(sales_value) AS spend,
           COUNT(DISTINCT order_date) AS purchase_occasions
    FROM vw_valid_sales_net GROUP BY customer_id
)
SELECT
    CASE WHEN purchase_occasions = 1                     THEN '1 purchase'
         WHEN purchase_occasions = 2                     THEN '2 purchases'
         WHEN purchase_occasions BETWEEN 3 AND 5         THEN '3-5 purchases'
         WHEN purchase_occasions BETWEEN 6 AND 10        THEN '6-10 purchases'
         ELSE                                                 '11+ purchases' END AS purchase_band,
    COUNT(*)                                                   AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)         AS pct_of_customers,
    ROUND(SUM(spend), 2)                                       AS revenue,
    ROUND(100.0 * SUM(spend) / SUM(SUM(spend)) OVER (), 1)     AS pct_of_revenue,
    ROUND(AVG(spend), 2)                                       AS mean_spend,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY spend)::numeric, 2) AS median_spend,
    ROUND(AVG(spend / purchase_occasions), 2)                  AS mean_value_per_purchase
FROM customer_value
GROUP BY 1
ORDER BY MIN(purchase_occasions);
