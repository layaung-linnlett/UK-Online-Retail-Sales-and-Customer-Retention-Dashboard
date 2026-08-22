-- ============================================================================
-- 06_retention_cadence.sql
--
-- What this does:
--   Replaces the fixed 90-day inactivity rule with a per-customer cadence
--   rule. Each customer is judged against their own normal buying rhythm
--   instead of one company-wide number of days.
--
--   This file ADDS views. It does not modify vw_customer_profile or the
--   90-day segments in 05_customer_analysis.sql - those stay exactly as
--   they were so the original 195-customer figure remains reproducible and
--   the before/after comparison is honest.
--
--   vw_customer_cadence - one row per customer, with their median gap
--                         between purchases, how long they have been quiet,
--                         and a cadence-based segment.
--
-- Business question answered:
--   Which customers have gone quiet relative to THEIR OWN buying pattern,
--   rather than relative to an arbitrary 90-day cut-off that treats a
--   weekly buyer and a quarterly buyer identically?
--
-- Key definitions and why they were chosen:
--
--   Purchase occasion = a distinct ORDER DATE, not a distinct invoice.
--     697 customers raised more than one invoice on the same day. Counting
--     those as separate purchases creates zero-day gaps that drag the
--     median toward zero and make the customer look abandoned the moment
--     they pause. 18,532 invoices collapse to 16,763 purchase occasions.
--
--   Median, not mean, inter-purchase gap.
--     Gaps are heavily right-skewed (mean 45.7 days vs median 28 days,
--     max 366). One long holiday would drag a mean upward and hide a
--     genuine lapse. The median describes the typical rhythm.
--
--   Minimum 3 purchase occasions to be scored.
--     3 occasions gives 2 gaps, which is the minimum needed for a median to
--     mean anything. Customers with 1 or 2 occasions are reported in a
--     separate bucket rather than forced through logic their data cannot
--     support.
--
--   The multiple: 2x the customer's own median.
--     Chosen empirically, not by assumption. Across all 11,551 historical
--     gaps belonging to customers with 2+ gaps, the share of REAL gaps that
--     exceeded each multiple of that customer's own median was:
--         1.5x -> 22.4%   2.0x -> 11.6%   2.5x -> 7.6%
--         3.0x ->  5.0%   4.0x ->  2.8%
--     At 1.5x nearly a quarter of ordinary gaps cross the line, so it
--     signals nothing. 2x means the customer is doing something they
--     historically only do about 1 time in 9.
--     2x was preferred over the rarer 3x because the costs are asymmetric:
--     a false positive is one wasted phone call to a customer who was fine,
--     a false negative is a proven repeat spender lost. Where over-flagging
--     is cheap and under-flagging is expensive, the threshold should lean
--     permissive. 3x would be the right choice if outreach were expensive
--     (a deep discount, for example) rather than a call list.
--
--   Absolute floor of 30 days.
--     A guard so a customer with a very short median gap is not flagged
--     after a single quiet week. Measured, not assumed: without the floor
--     the 2x rule flags 235 customers; with it, 224. The floor therefore
--     suppresses 11 customers holding GBP 67,972 of historical spend -
--     all of them fast-cadence buyers quiet for under 30 days. It is a
--     safety rail that removes about 5% of the raw flags, not a driver of
--     the result.
--
-- Known limitation, stated up front:
--   Every customer's CURRENT silence is right-censored. The data stops on
--   2011-12-09, so a customer who last ordered on 2011-12-01 may simply not
--   have reordered YET. This rule cannot distinguish "gone" from "not due
--   back". The censoring query at the end of this file quantifies it.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Purchase occasions, gaps, and per-customer median cadence
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS vw_customer_cadence;

CREATE VIEW vw_customer_cadence AS
WITH dataset_end AS (
    SELECT MAX(order_date) AS dataset_end_date
    FROM vw_valid_sales
),
-- One row per customer per DAY they bought, collapsing same-day invoices.
purchase_occasions AS (
    SELECT DISTINCT customer_id, order_date
    FROM vw_valid_sales
),
-- LAG() reads the previous purchase date within the same customer, so each
-- row can be compared with the one before it without collapsing the rows.
gaps AS (
    SELECT
        customer_id,
        order_date,
        (order_date - LAG(order_date) OVER (PARTITION BY customer_id
                                            ORDER BY order_date)) AS gap_days
    FROM purchase_occasions
),
cadence AS (
    SELECT
        customer_id,
        COUNT(*)                                                    AS gap_count,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days)::numeric, 1) AS median_gap_days,
        ROUND(AVG(gap_days)::numeric, 1)                            AS mean_gap_days,
        MIN(gap_days)                                               AS shortest_gap_days,
        MAX(gap_days)                                               AS longest_gap_days
    FROM gaps
    WHERE gap_days IS NOT NULL          -- first purchase has no preceding gap
    GROUP BY customer_id
),
customer_summary AS (
    SELECT
        v.customer_id,
        MIN(v.order_date)                        AS first_order_date,
        MAX(v.order_date)                        AS last_order_date,
        COUNT(DISTINCT v.order_date)             AS purchase_occasions,
        COUNT(DISTINCT v.invoice_no)             AS total_invoices,
        SUM(v.quantity)                          AS total_items,
        ROUND(SUM(v.sales_value), 2)             AS total_spend
    FROM vw_valid_sales AS v
    GROUP BY v.customer_id
)
SELECT
    cs.customer_id,
    cs.first_order_date,
    cs.last_order_date,
    de.dataset_end_date,
    (de.dataset_end_date - cs.last_order_date)   AS days_since_last_order,
    cs.purchase_occasions,
    cs.total_invoices,
    cs.total_items,
    cs.total_spend,
    ROUND(cs.total_spend / cs.purchase_occasions, 2) AS avg_value_per_occasion,
    c.gap_count,
    c.median_gap_days,
    c.mean_gap_days,
    c.shortest_gap_days,
    c.longest_gap_days,
    -- How many times their own normal gap they are currently overdue by.
    -- NULL when they have too little history to have a cadence.
    CASE
        WHEN c.median_gap_days IS NULL OR c.median_gap_days = 0 THEN NULL
        ELSE ROUND((de.dataset_end_date - cs.last_order_date) / c.median_gap_days, 2)
    END AS cadence_ratio,
    CASE
        WHEN cs.purchase_occasions = 1
            THEN 'Single purchase - no cadence'
        WHEN cs.purchase_occasions = 2
            THEN 'Two purchases - cadence unreliable'
        WHEN (de.dataset_end_date - cs.last_order_date) > 2 * c.median_gap_days
             AND (de.dataset_end_date - cs.last_order_date) >= 30
            THEN 'At risk - overdue on own cadence'
        ELSE 'Active - within own cadence'
    END AS cadence_segment
FROM customer_summary AS cs
CROSS JOIN dataset_end AS de
LEFT JOIN cadence AS c ON c.customer_id = cs.customer_id;


-- ----------------------------------------------------------------------------
-- 1. Evidence for the 2x choice: how often do REAL gaps exceed each multiple?
--    This is the query that justifies the threshold. Run it when challenged.
-- ----------------------------------------------------------------------------
WITH purchase_occasions AS (
    SELECT DISTINCT customer_id, order_date FROM vw_valid_sales
),
gaps AS (
    SELECT customer_id,
           (order_date - LAG(order_date) OVER (PARTITION BY customer_id
                                               ORDER BY order_date)) AS gap_days
    FROM purchase_occasions
),
clean_gaps AS (
    SELECT customer_id, gap_days FROM gaps WHERE gap_days IS NOT NULL
),
med AS (
    SELECT customer_id,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days) AS median_gap
    FROM clean_gaps
    GROUP BY customer_id
    HAVING COUNT(*) >= 2
)
SELECT
    COUNT(*) AS historical_gaps_examined,
    ROUND(100.0 * AVG(CASE WHEN g.gap_days > 1.5 * m.median_gap THEN 1 ELSE 0 END), 1) AS pct_exceeding_1_5x,
    ROUND(100.0 * AVG(CASE WHEN g.gap_days > 2.0 * m.median_gap THEN 1 ELSE 0 END), 1) AS pct_exceeding_2x,
    ROUND(100.0 * AVG(CASE WHEN g.gap_days > 2.5 * m.median_gap THEN 1 ELSE 0 END), 1) AS pct_exceeding_2_5x,
    ROUND(100.0 * AVG(CASE WHEN g.gap_days > 3.0 * m.median_gap THEN 1 ELSE 0 END), 1) AS pct_exceeding_3x,
    ROUND(100.0 * AVG(CASE WHEN g.gap_days > 4.0 * m.median_gap THEN 1 ELSE 0 END), 1) AS pct_exceeding_4x
FROM clean_gaps AS g
JOIN med AS m ON m.customer_id = g.customer_id;


-- ----------------------------------------------------------------------------
-- 2. The new segment summary
-- ----------------------------------------------------------------------------
SELECT
    cadence_segment,
    COUNT(*)                          AS customers,
    ROUND(SUM(total_spend), 2)        AS total_spend,
    ROUND(AVG(total_spend), 2)        AS avg_spend_per_customer,
    ROUND(AVG(median_gap_days), 1)    AS avg_of_median_gaps,
    ROUND(AVG(days_since_last_order), 1) AS avg_days_quiet
FROM vw_customer_cadence
GROUP BY cadence_segment
ORDER BY total_spend DESC;


-- ----------------------------------------------------------------------------
-- 3. The new at-risk call list, ranked by value at stake
-- ----------------------------------------------------------------------------
SELECT
    customer_id,
    total_spend,
    purchase_occasions,
    median_gap_days,
    days_since_last_order,
    cadence_ratio,
    last_order_date
FROM vw_customer_cadence
WHERE cadence_segment = 'At risk - overdue on own cadence'
ORDER BY total_spend DESC;


-- ----------------------------------------------------------------------------
-- 4. BEFORE / AFTER - headline comparison against both 90-day baselines
--
--    Baseline A: 'High-value at risk' (195) = 2+ orders AND spend >= 1000
--                AND quiet > 90 days. This is the README headline.
--    Baseline B: all at-risk repeat customers (602) = 2+ orders AND quiet
--                > 90 days, with no spend floor. This is the like-for-like
--                methodology comparison, because the cadence rule has no
--                spend floor either.
-- ----------------------------------------------------------------------------
SELECT 'A. Old rule: high-value at risk (90d + GBP1k)' AS list,
       COUNT(*) AS customers, ROUND(SUM(total_spend), 2) AS total_spend
FROM vw_customer_profile WHERE customer_segment = 'High-value at risk'
UNION ALL
SELECT 'B. Old rule: all at-risk repeat (90d, no spend floor)',
       COUNT(*), ROUND(SUM(total_spend), 2)
FROM vw_customer_profile
WHERE customer_segment IN ('High-value at risk', 'At-risk repeat customer')
UNION ALL
SELECT 'C. New rule: overdue on own cadence (2x median)',
       COUNT(*), ROUND(SUM(total_spend), 2)
FROM vw_customer_cadence
WHERE cadence_segment = 'At risk - overdue on own cadence';


-- ----------------------------------------------------------------------------
-- 5. WHO MOVED - against baseline B (like-for-like, no spend floor either side)
-- ----------------------------------------------------------------------------
WITH old_list AS (
    SELECT customer_id FROM vw_customer_profile
    WHERE customer_segment IN ('High-value at risk', 'At-risk repeat customer')
),
new_list AS (
    SELECT customer_id FROM vw_customer_cadence
    WHERE cadence_segment = 'At risk - overdue on own cadence'
)
SELECT
    CASE
        WHEN o.customer_id IS NOT NULL AND n.customer_id IS NOT NULL THEN 'On both lists'
        WHEN n.customer_id IS NOT NULL                               THEN 'ADDED by cadence rule'
        ELSE                                                              'DROPPED by cadence rule'
    END AS movement,
    COUNT(*)                   AS customers,
    ROUND(SUM(c.total_spend), 2) AS total_spend,
    ROUND(AVG(c.median_gap_days), 1) AS avg_median_gap,
    ROUND(AVG(c.days_since_last_order), 1) AS avg_days_quiet
FROM old_list AS o
FULL OUTER JOIN new_list AS n ON o.customer_id = n.customer_id
JOIN vw_customer_cadence AS c
  ON c.customer_id = COALESCE(o.customer_id, n.customer_id)
GROUP BY 1
ORDER BY total_spend DESC;


-- ----------------------------------------------------------------------------
-- 6. WHO MOVED - against baseline A, the 195 README headline list
-- ----------------------------------------------------------------------------
WITH old_list AS (
    SELECT customer_id FROM vw_customer_profile
    WHERE customer_segment = 'High-value at risk'
),
new_list AS (
    SELECT customer_id FROM vw_customer_cadence
    WHERE cadence_segment = 'At risk - overdue on own cadence'
)
SELECT
    CASE
        WHEN o.customer_id IS NOT NULL AND n.customer_id IS NOT NULL THEN 'On both lists'
        WHEN n.customer_id IS NOT NULL                               THEN 'ADDED by cadence rule'
        ELSE                                                              'DROPPED by cadence rule'
    END AS movement,
    COUNT(*)                   AS customers,
    ROUND(SUM(c.total_spend), 2) AS total_spend
FROM old_list AS o
FULL OUTER JOIN new_list AS n ON o.customer_id = n.customer_id
JOIN vw_customer_cadence AS c
  ON c.customer_id = COALESCE(o.customer_id, n.customer_id)
GROUP BY 1
ORDER BY total_spend DESC;


-- ----------------------------------------------------------------------------
-- 7. The customers the 90-day rule got WRONG, with examples
--    7a: flagged by 90-day rule but genuinely still within their own rhythm
-- ----------------------------------------------------------------------------
SELECT
    c.customer_id,
    c.total_spend,
    c.purchase_occasions,
    c.median_gap_days,
    c.days_since_last_order,
    c.cadence_ratio
FROM vw_customer_cadence AS c
JOIN vw_customer_profile AS p ON p.customer_id = c.customer_id
WHERE p.customer_segment IN ('High-value at risk', 'At-risk repeat customer')
  AND c.cadence_segment = 'Active - within own cadence'
ORDER BY c.total_spend DESC
LIMIT 15;

--    7b: missed by the 90-day rule but badly overdue on their own cadence
SELECT
    c.customer_id,
    c.total_spend,
    c.purchase_occasions,
    c.median_gap_days,
    c.days_since_last_order,
    c.cadence_ratio
FROM vw_customer_cadence AS c
JOIN vw_customer_profile AS p ON p.customer_id = c.customer_id
WHERE p.customer_segment NOT IN ('High-value at risk', 'At-risk repeat customer')
  AND c.cadence_segment = 'At risk - overdue on own cadence'
ORDER BY c.cadence_ratio DESC
LIMIT 15;


-- ----------------------------------------------------------------------------
-- 8. The too-few-orders bucket, reported separately rather than forced in
-- ----------------------------------------------------------------------------
SELECT
    cadence_segment,
    COUNT(*)                        AS customers,
    ROUND(SUM(total_spend), 2)      AS total_spend,
    ROUND(AVG(total_spend), 2)      AS avg_spend,
    ROUND(AVG(days_since_last_order), 1) AS avg_days_quiet
FROM vw_customer_cadence
WHERE cadence_segment IN ('Single purchase - no cadence',
                          'Two purchases - cadence unreliable')
GROUP BY cadence_segment
ORDER BY customers DESC;


-- ----------------------------------------------------------------------------
-- 9. CENSORING CHECK - how much of the "Active" group is genuinely active
--    versus simply not yet due back? Honesty check on the whole method.
-- ----------------------------------------------------------------------------
SELECT
    CASE
        WHEN days_since_last_order <= median_gap_days      THEN '1. Not yet due - no signal either way'
        WHEN days_since_last_order <= 2 * median_gap_days  THEN '2. Late, but inside tolerance'
        WHEN days_since_last_order < 30                    THEN '3. Past 2x but under the 30-day floor'
        ELSE                                                    '4. Past 2x and past the floor - FLAGGED'
    END AS censoring_bucket,
    COUNT(*)                     AS customers,
    ROUND(SUM(total_spend), 2)   AS total_spend
FROM vw_customer_cadence
WHERE purchase_occasions >= 3
GROUP BY 1
ORDER BY censoring_bucket;
