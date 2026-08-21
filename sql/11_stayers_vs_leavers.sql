-- ============================================================================
-- 11_stayers_vs_leavers.sql
--
-- What this does:
--   Compares customers who stayed against customers who lapsed, on three
--   things observable early in the relationship: the value of their first
--   order, the number of items in it, and how quickly they placed a second
--   order.
--
--   Built on vw_valid_sales_net (reversal-corrected). Uses
--   vw_customer_cadence_net, which applies the 06_retention_cadence.sql rule
--   (overdue by more than 2x the customer's own median gap, minimum 30 days)
--   to the corrected data.
--
-- Business question answered:
--   Can we tell early on which customers are going to stick?
--
-- ****  THIS IS CORRELATION, NOT CAUSATION.  ****
--   Everything below describes how two groups differ. None of it shows that
--   changing one of these things would change whether a customer stays.
--   A bigger first order is associated with staying; that does not mean
--   pushing a bigger first order would make someone stay. The likeliest
--   explanation runs the other way - customers who were always going to be
--   committed buyers place bigger first orders because of who they already
--   are. No experiment here can separate those, and no claim below should
--   be presented as "do X and retention improves".
--
--   No significance testing is performed. The overlap query in section 5
--   is included instead, because it shows honestly how weak the separation
--   is without needing a p-value to interpret.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. THE FIRST HURDLE - customers who never came back at all
--
--    Unfiltered. Note the last column: customers who never returned were
--    observed for 156 days on average against 260 for those who did, so
--    this comparison is contaminated by recency. Section 2 fixes that.
-- ----------------------------------------------------------------------------
SELECT
    CASE WHEN is_one_and_done THEN 'Never returned' ELSE 'Returned at least once' END AS customer_group,
    COUNT(*)                               AS customers,
    ROUND(AVG(first_order_value), 2)       AS mean_first_order_value,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY first_order_value)::numeric, 2) AS median_first_order_value,
    ROUND(AVG(first_order_items), 1)       AS mean_first_order_items,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY first_order_items)::numeric, 1) AS median_first_order_items,
    ROUND(AVG(observation_days), 0)        AS mean_days_observed
FROM vw_first_second_purchase
GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- 2. The same comparison, with recency stripped out
--    Only customers we watched for at least 90 days after their first order.
-- ----------------------------------------------------------------------------
SELECT
    CASE WHEN is_one_and_done THEN 'Never returned' ELSE 'Returned at least once' END AS customer_group,
    COUNT(*)                               AS customers,
    ROUND(AVG(first_order_value), 2)       AS mean_first_order_value,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY first_order_value)::numeric, 2) AS median_first_order_value,
    ROUND(AVG(first_order_items), 1)       AS mean_first_order_items,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY first_order_items)::numeric, 1) AS median_first_order_items
FROM vw_first_second_purchase
WHERE observation_days >= 90
GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- 3. ESTABLISHED CUSTOMERS - still with us, or lapsed?
--    Restricted to customers with 3+ purchases, where a cadence exists.
-- ----------------------------------------------------------------------------
SELECT
    c.cadence_segment AS customer_group,
    COUNT(*)                                    AS customers,
    ROUND(AVG(f.first_order_value), 2)          AS mean_first_order_value,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.first_order_value)::numeric, 2) AS median_first_order_value,
    ROUND(AVG(f.first_order_items), 1)          AS mean_first_order_items,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.first_order_items)::numeric, 1) AS median_first_order_items,
    ROUND(AVG(f.days_to_second_purchase), 1)    AS mean_days_to_second,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.days_to_second_purchase)::numeric, 1) AS median_days_to_second,
    ROUND(AVG(c.purchase_occasions), 1)         AS mean_purchases,
    ROUND(AVG(c.total_spend), 2)                AS mean_total_spend
FROM vw_customer_cadence_net AS c
JOIN vw_first_second_purchase AS f ON f.customer_id = c.customer_id
WHERE c.cadence_segment IN ('Active - within own cadence',
                            'At risk - overdue on own cadence')
GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- 4. CONTROL CHECK - are the two groups comparable in the first place?
--    If lapsed customers were simply acquired earlier, the comparison would
--    be measuring the calendar rather than behaviour. They are not: both
--    groups were observed for a near-identical length of time.
-- ----------------------------------------------------------------------------
SELECT
    cadence_segment AS customer_group,
    COUNT(*)                                  AS customers,
    MIN(first_order_date)                     AS earliest_first_order,
    ROUND(AVG(dataset_end_date - first_order_date), 0) AS mean_observation_days
FROM vw_customer_cadence_net
WHERE cadence_segment IN ('Active - within own cadence',
                          'At risk - overdue on own cadence')
GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- 5. HOW WEAK IS THE SIGNAL? - the full spread, not just the middle
--    Read p75 and p90 across the two rows. They are almost identical. The
--    groups differ only at the bottom of the range, which means first-order
--    value cannot be used to score an individual customer.
-- ----------------------------------------------------------------------------
SELECT
    c.cadence_segment AS customer_group,
    COUNT(*) AS customers,
    ROUND(PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY f.first_order_value)::numeric, 0) AS p10,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY f.first_order_value)::numeric, 0) AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY f.first_order_value)::numeric, 0) AS p50,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY f.first_order_value)::numeric, 0) AS p75,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY f.first_order_value)::numeric, 0) AS p90
FROM vw_customer_cadence_net AS c
JOIN vw_first_second_purchase AS f ON f.customer_id = c.customer_id
WHERE c.cadence_segment IN ('Active - within own cadence',
                            'At risk - overdue on own cadence')
GROUP BY 1 ORDER BY 1;


-- ----------------------------------------------------------------------------
-- 6. THE TRAP IN SECTION 3 - why "lapsed customers returned FASTER"
--    is an artifact and not a finding.
--
--    Section 3 shows lapsed customers reached their second purchase in a
--    median of 30 days against 50 for active ones - the opposite of the
--    obvious hypothesis. It is not behaviour. The at-risk rule flags anyone
--    silent for more than 2x their own median gap, so a fast-cadence
--    customer trips it after a short absence while a slow one does not.
--    The lapsed group is therefore loaded with naturally fast buyers, whose
--    second purchase was always going to be quick.
--
--    First query: proof that the lapsed group is structurally faster.
--    Second query: the comparison redone WITHIN cadence bands, where the
--    difference shrinks from 20 days to a handful and stops being a story.
-- ----------------------------------------------------------------------------
SELECT
    cadence_segment AS customer_group,
    COUNT(*) AS customers,
    ROUND(AVG(median_gap_days), 1) AS mean_of_their_median_gaps,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY median_gap_days)::numeric, 1) AS median_of_their_median_gaps,
    ROUND(AVG(days_since_last_order), 1) AS mean_days_currently_quiet
FROM vw_customer_cadence_net
WHERE cadence_segment IN ('Active - within own cadence',
                          'At risk - overdue on own cadence')
GROUP BY 1 ORDER BY 1;

SELECT
    CASE WHEN c.median_gap_days < 20 THEN 'a. Fast (under 20d)'
         WHEN c.median_gap_days < 40 THEN 'b. Medium (20-40d)'
         WHEN c.median_gap_days < 70 THEN 'c. Slow (40-70d)'
         ELSE                             'd. Very slow (70d+)' END AS cadence_band,
    COUNT(*) FILTER (WHERE c.cadence_segment = 'Active - within own cadence') AS n_active,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.days_to_second_purchase)
          FILTER (WHERE c.cadence_segment = 'Active - within own cadence')::numeric, 0)
          AS active_median_days_to_second,
    COUNT(*) FILTER (WHERE c.cadence_segment = 'At risk - overdue on own cadence') AS n_lapsed,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.days_to_second_purchase)
          FILTER (WHERE c.cadence_segment = 'At risk - overdue on own cadence')::numeric, 0)
          AS lapsed_median_days_to_second
FROM vw_customer_cadence_net AS c
JOIN vw_first_second_purchase AS f ON f.customer_id = c.customer_id
WHERE c.cadence_segment IN ('Active - within own cadence',
                            'At risk - overdue on own cadence')
GROUP BY 1 ORDER BY 1;
