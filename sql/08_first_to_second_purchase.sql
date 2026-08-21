-- ============================================================================
-- 08_first_to_second_purchase.sql
--
-- What this does:
--   Answers three linked questions about first-time buyers:
--     (a) what share of customers ever bought only once
--     (b) for those who came back, how long the second purchase took
--     (c) whether there is a point after which a first-time buyer stops
--         being worth chasing
--
--   Built on vw_valid_sales_net (the reversal-corrected view from
--   07_revenue_concentration.sql), because a customer whose only order was
--   later cancelled is not a one-time buyer - they are not a buyer at all.
--
-- Business question answered:
--   How big is the one-and-done problem really, when is the second purchase
--   won or lost, and how long should a first-time buyer stay on the
--   re-engagement list before we give up on them?
--
-- THE MEASUREMENT TRAP IN THIS QUESTION:
--   A naive one-and-done rate is badly overstated, because a customer who
--   first bought in November 2011 had three weeks to come back before the
--   data ends, while one who first bought in December 2010 had a year.
--   Counting them the same way scores recent customers as failures for the
--   crime of being recent. Query 2 below corrects for this by requiring a
--   minimum observation window before a customer is judged.
--
--   A purchase occasion is a distinct ORDER DATE, consistent with
--   06_retention_cadence.sql. Same-day invoices are one purchase.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Reusable base: each customer's first and second purchase dates
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_first_second_purchase;

CREATE VIEW vw_first_second_purchase AS
WITH dataset_end AS (
    SELECT MAX(order_date) AS dataset_end_date FROM vw_valid_sales_net
),
purchase_occasions AS (
    SELECT DISTINCT customer_id, order_date FROM vw_valid_sales_net
),
-- ROW_NUMBER() labels each customer's purchases 1, 2, 3 ... in date order,
-- so purchase 1 and purchase 2 can be pulled out by name.
sequenced AS (
    SELECT customer_id, order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS purchase_no
    FROM purchase_occasions
),
folded AS (
    SELECT customer_id,
           MAX(CASE WHEN purchase_no = 1 THEN order_date END) AS first_purchase_date,
           MAX(CASE WHEN purchase_no = 2 THEN order_date END) AS second_purchase_date,
           COUNT(*) AS purchase_occasions
    FROM sequenced GROUP BY customer_id
),
first_order_value AS (
    SELECT v.customer_id,
           ROUND(SUM(v.sales_value), 2) AS first_order_value,
           SUM(v.quantity)              AS first_order_items
    FROM vw_valid_sales_net AS v
    JOIN (SELECT customer_id, MIN(order_date) AS d
          FROM vw_valid_sales_net GROUP BY customer_id) AS f
      ON f.customer_id = v.customer_id AND f.d = v.order_date
    GROUP BY v.customer_id
)
SELECT
    f.customer_id,
    f.first_purchase_date,
    f.second_purchase_date,
    f.purchase_occasions,
    (f.second_purchase_date - f.first_purchase_date) AS days_to_second_purchase,
    -- how long we were able to watch this customer after their first buy
    (de.dataset_end_date - f.first_purchase_date)    AS observation_days,
    fov.first_order_value,
    fov.first_order_items,
    (f.purchase_occasions = 1)                       AS is_one_and_done
FROM folded AS f
CROSS JOIN dataset_end AS de
LEFT JOIN first_order_value AS fov ON fov.customer_id = f.customer_id;


-- ----------------------------------------------------------------------------
-- 1. The headline rate, and the same figure counted by invoice for comparison
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*)                                                       AS customers,
    COUNT(*) FILTER (WHERE is_one_and_done)                        AS one_and_done,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_one_and_done) / COUNT(*), 1) AS pct_one_and_done,
    COUNT(*) FILTER (WHERE NOT is_one_and_done)                    AS repeat_buyers
FROM vw_first_second_purchase;

SELECT COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE invoices = 1) AS single_invoice_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE invoices = 1) / COUNT(*), 1) AS pct_single_invoice
FROM (SELECT customer_id, COUNT(DISTINCT invoice_no) AS invoices
      FROM vw_valid_sales_net GROUP BY customer_id) AS t;


-- ----------------------------------------------------------------------------
-- 2. THE CENSORING CORRECTION - the rate once customers get a fair chance
--
--    Each row asks: among customers we were able to watch for at least N
--    days after their first purchase, how many never came back?
-- ----------------------------------------------------------------------------
SELECT
    v.w                                        AS min_observation_days,
    COUNT(*)                                   AS customers_judged,
    COUNT(*) FILTER (WHERE is_one_and_done)    AS never_returned,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_one_and_done) / COUNT(*), 1) AS pct_one_and_done
FROM vw_first_second_purchase
CROSS JOIN (VALUES (0),(30),(60),(90),(120),(180),(270)) AS v(w)
WHERE observation_days >= v.w
GROUP BY v.w
ORDER BY v.w;


-- ----------------------------------------------------------------------------
-- 3. How long the second purchase took, for those who made it
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*)                                                              AS repeat_buyers,
    MIN(days_to_second_purchase)                                          AS fastest_days,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY days_to_second_purchase) AS p25_days,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY days_to_second_purchase) AS median_days,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY days_to_second_purchase) AS p75_days,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY days_to_second_purchase) AS p90_days,
    MAX(days_to_second_purchase)                                          AS slowest_days,
    ROUND(AVG(days_to_second_purchase), 1)                                AS mean_days
FROM vw_first_second_purchase
WHERE second_purchase_date IS NOT NULL;


-- ----------------------------------------------------------------------------
-- 4. The second purchase is the slow one - proof
--    Compares the 1->2 gap against every gap that comes after it.
-- ----------------------------------------------------------------------------
WITH purchase_occasions AS (
    SELECT DISTINCT customer_id, order_date FROM vw_valid_sales_net
),
sequenced AS (
    SELECT customer_id, order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS purchase_no
    FROM purchase_occasions
),
gaps AS (
    SELECT purchase_no,
           (order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date)) AS gap_days
    FROM sequenced
)
SELECT
    CASE WHEN purchase_no = 2 THEN 'Gap 1->2 (winning the second purchase)'
         ELSE 'All later gaps (2->3, 3->4, ...)' END AS which_gap,
    COUNT(*)                                              AS gaps_measured,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_days,
    ROUND(AVG(gap_days), 1)                               AS mean_days
FROM gaps WHERE gap_days IS NOT NULL
GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- 5. IS THERE A CUT-OFF WINDOW?
--
--    Restricted to customers observed for at least 270 days, so a late
--    return would actually have been visible in the data.
--
--    The last column is the one that matters commercially: of the customers
--    still silent at day N, what share eventually came back anyway? That is
--    the probability you are writing off if you drop them at day N.
-- ----------------------------------------------------------------------------
WITH cohort AS (
    SELECT * FROM vw_first_second_purchase WHERE observation_days >= 270
)
SELECT
    v.w AS by_day,
    COUNT(*) FILTER (WHERE days_to_second_purchase <= v.w) AS returned_by_then,
    ROUND(100.0 * COUNT(*) FILTER (WHERE days_to_second_purchase <= v.w)
          / COUNT(*), 1) AS pct_of_all_first_time_buyers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE days_to_second_purchase <= v.w)
          / NULLIF(COUNT(*) FILTER (WHERE days_to_second_purchase IS NOT NULL), 0), 1)
          AS pct_of_eventual_repeaters,
    ROUND(100.0 * COUNT(*) FILTER (WHERE days_to_second_purchase > v.w)
          / NULLIF(COUNT(*) FILTER (WHERE days_to_second_purchase IS NULL
                                       OR days_to_second_purchase > v.w), 0), 1)
          AS pct_of_still_silent_who_return_later
FROM cohort
CROSS JOIN (VALUES (30),(60),(90),(120),(150),(180),(210),(240)) AS v(w)
GROUP BY v.w ORDER BY v.w;


-- ----------------------------------------------------------------------------
-- 6. What the one-and-done group is worth, and therefore what is at stake
-- ----------------------------------------------------------------------------
SELECT
    CASE WHEN is_one_and_done THEN 'One and done' ELSE 'Came back at least once' END AS group_name,
    COUNT(*)                                    AS customers,
    ROUND(SUM(first_order_value), 2)            AS total_first_order_value,
    ROUND(AVG(first_order_value), 2)            AS avg_first_order_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY first_order_value) AS median_first_order_value,
    ROUND(AVG(first_order_items), 1)            AS avg_items_in_first_order
FROM vw_first_second_purchase
GROUP BY 1 ORDER BY 1;
