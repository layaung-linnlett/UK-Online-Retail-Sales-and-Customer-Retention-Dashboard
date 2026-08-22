-- ============================================================================
-- 09_cohort_retention.sql
--
-- What this does:
--   Groups every customer by the month of their first purchase and tracks
--   what share of each group came back in each following month, then makes
--   a fair equal-age comparison between cohorts.
--
--   Built on vw_valid_sales_net (reversal-corrected).
--
-- Business question answered:
--   Are the customers we acquired recently sticking around better or worse
--   than the ones we acquired a year ago?
--
-- THREE TRAPS IN THIS QUESTION, ALL HANDLED BELOW:
--
--   1. LEFT TRUNCATION - the December 2010 cohort is not a real cohort.
--      The data begins 2010-12-01. Every customer already trading on that
--      day is recorded as "new in December 2010", including customers who
--      had been buying for years. Evidence: 573 of its 884 "new" customers
--      appear in the first eight trading days, while a genuine month
--      acquires 169-450 across the whole month. It is an opening balance of
--      the existing customer base, not an intake of new customers, and it
--      must be excluded from any trend claim.
--
--   2. UNOBSERVED IS NOT ZERO - a cohort formed in October 2011 has no
--      month-6 figure because month 6 has not happened. Writing 0 there
--      makes recent cohorts look catastrophic. Those cells are NULL below,
--      not 0.
--
--   3. THE LAST MONTH IS A STUB - the data stops on 2011-12-09, so
--      December 2011 holds nine days of trading, not a month. Any cell
--      landing on it reads about 10-12% purely because the month is short.
--      December 2011 activity is excluded from the triangle entirely.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Cohort sizes - and the evidence that December 2010 is not a real cohort
-- ----------------------------------------------------------------------------
WITH first_month AS (
    SELECT customer_id, DATE_TRUNC('month', MIN(order_date))::date AS cohort_month
    FROM vw_valid_sales_net GROUP BY customer_id
)
SELECT cohort_month, COUNT(*) AS cohort_size,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_customer_base
FROM first_month GROUP BY cohort_month ORDER BY cohort_month;

-- The pile-up that proves it: daily first-order counts at the start of the data
WITH first_order AS (
    SELECT customer_id, MIN(order_date) AS first_date
    FROM vw_valid_sales_net GROUP BY customer_id
)
SELECT first_date, COUNT(*) AS customers_recorded_as_new
FROM first_order
WHERE first_date < DATE '2010-12-13'
GROUP BY first_date ORDER BY first_date;


-- ----------------------------------------------------------------------------
-- 2. THE RETENTION TRIANGLE
--    Each cell: % of the cohort that placed an order in that month of life.
--    NULL means "not observable yet", never 0.
-- ----------------------------------------------------------------------------
WITH bounds AS (
    -- last COMPLETE trading month; Dec 2011 is a nine-day stub
    SELECT DATE '2011-11-01' AS last_complete_month
),
first_month AS (
    SELECT customer_id, DATE_TRUNC('month', MIN(order_date))::date AS cohort_month
    FROM vw_valid_sales_net GROUP BY customer_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_size FROM first_month GROUP BY cohort_month
),
activity AS (
    SELECT DISTINCT f.cohort_month, f.customer_id,
           ((EXTRACT(YEAR  FROM v.order_month) - EXTRACT(YEAR  FROM f.cohort_month)) * 12
          + (EXTRACT(MONTH FROM v.order_month) - EXTRACT(MONTH FROM f.cohort_month)))::int AS month_index
    FROM vw_valid_sales_net AS v
    JOIN first_month AS f ON f.customer_id = v.customer_id
    WHERE v.order_month <= (SELECT last_complete_month FROM bounds)
),
grid AS (
    SELECT s.cohort_month, s.cohort_size, i.month_index,
           (s.cohort_month + (i.month_index || ' month')::interval)::date AS activity_month
    FROM cohort_size AS s
    CROSS JOIN generate_series(1, 11) AS i(month_index)
),
cells AS (
    SELECT g.cohort_month, g.cohort_size, g.month_index,
           CASE WHEN g.activity_month <= (SELECT last_complete_month FROM bounds)
                THEN ROUND(100.0 * (SELECT COUNT(*) FROM activity AS a
                                    WHERE a.cohort_month = g.cohort_month
                                      AND a.month_index  = g.month_index)
                           / g.cohort_size, 1)
           END AS retention_pct
    FROM grid AS g
)
SELECT cohort_month, cohort_size,
       MAX(retention_pct) FILTER (WHERE month_index = 1)  AS m1,
       MAX(retention_pct) FILTER (WHERE month_index = 2)  AS m2,
       MAX(retention_pct) FILTER (WHERE month_index = 3)  AS m3,
       MAX(retention_pct) FILTER (WHERE month_index = 4)  AS m4,
       MAX(retention_pct) FILTER (WHERE month_index = 5)  AS m5,
       MAX(retention_pct) FILTER (WHERE month_index = 6)  AS m6,
       MAX(retention_pct) FILTER (WHERE month_index = 9)  AS m9,
       MAX(retention_pct) FILTER (WHERE month_index = 11) AS m11
FROM cells GROUP BY cohort_month, cohort_size ORDER BY cohort_month;


-- ----------------------------------------------------------------------------
-- 3. THE FAIR COMPARISON - equal age, per customer
--
--    The triangle above still compares cohorts at different ages. This asks
--    one question of every cohort on identical terms: of the customers we
--    watched for at least N days, what share bought again within N days?
--    A customer is only counted if they personally had the full N days.
-- ----------------------------------------------------------------------------
SELECT
    DATE_TRUNC('month', first_purchase_date)::date AS cohort_month,
    COUNT(*) FILTER (WHERE observation_days >= 30) AS judged_at_30d,
    ROUND(100.0 * COUNT(*) FILTER (WHERE observation_days >= 30
                                     AND days_to_second_purchase <= 30)
          / NULLIF(COUNT(*) FILTER (WHERE observation_days >= 30), 0), 1) AS repeat_within_30d,
    COUNT(*) FILTER (WHERE observation_days >= 60) AS judged_at_60d,
    ROUND(100.0 * COUNT(*) FILTER (WHERE observation_days >= 60
                                     AND days_to_second_purchase <= 60)
          / NULLIF(COUNT(*) FILTER (WHERE observation_days >= 60), 0), 1) AS repeat_within_60d,
    COUNT(*) FILTER (WHERE observation_days >= 90) AS judged_at_90d,
    ROUND(100.0 * COUNT(*) FILTER (WHERE observation_days >= 90
                                     AND days_to_second_purchase <= 90)
          / NULLIF(COUNT(*) FILTER (WHERE observation_days >= 90), 0), 1) AS repeat_within_90d
FROM vw_first_second_purchase
GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- 4. THE CONFOUND - trading volume by month
--
--    Cohort quality cannot be read straight off section 3, because the
--    business is strongly seasonal. A customer acquired in September or
--    October is buying into the Christmas peak and has an obvious reason to
--    return quickly. One acquired in February does not. Some of the autumn
--    "improvement" is the calendar, not better customers.
-- ----------------------------------------------------------------------------
SELECT order_month,
       COUNT(DISTINCT invoice_no)  AS orders,
       COUNT(DISTINCT customer_id) AS active_customers,
       ROUND(SUM(sales_value), 2)  AS net_sales
FROM vw_valid_sales_net
GROUP BY order_month ORDER BY order_month;
