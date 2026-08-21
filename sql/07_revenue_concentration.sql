-- ============================================================================
-- 07_revenue_concentration.sql
--
-- What this does:
--   Answers "how concentrated is our revenue, and what is our exposure if we
--   lose the biggest customers?"
--
--   While building the top-10 list this file uncovered a defect in
--   vw_valid_sales that inflates net sales by 5%. That finding is documented
--   and quantified here, and a corrected view (vw_valid_sales_net) is added
--   alongside the original. The original view is NOT modified - the old
--   numbers stay reproducible.
--
-- THE DEFECT:
--   vw_valid_sales excludes invoices beginning with 'C' (the cancellation
--   record) but does NOT exclude the ORIGINAL order that the cancellation
--   reverses. So a fully cancelled order is removed once and counted once.
--   Its revenue stays in the totals.
--
--   Two examples sit in the published top 10 by spend:
--     Customer 16446.0 - invoice 581483, 80,995 units of PAPER CRAFT LITTLE
--       BIRDIE at GBP 2.08 = GBP 168,469.60 on 2011-12-09 09:15. Reversed by
--       C581484 at 09:27 the SAME MORNING, twelve minutes later. This
--       customer's genuine lifetime spend is GBP 2.90 - two brushes.
--     Customer 12346.0 - invoice 541431, 74,215 units at GBP 1.04 =
--       GBP 77,183.60 on 2011-01-18 10:01. Reversed by C541433 at 10:17 the
--       same morning. This customer's genuine lifetime spend is GBP 0.00.
--
--   Ranked 4th and 10th largest customers in the business. Neither ever
--   bought anything.
--
-- Business question answered:
--   What share of revenue depends on how few customers, and what is the
--   realistic financial exposure if the largest accounts leave?
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Quantify the defect before correcting it
--
--    Matching rule: a sales line is treated as reversed if the same customer
--    has a cancellation line for the same product, at the same unit price,
--    for the same quantity, dated on or after the sale. EXISTS is used rather
--    than a JOIN so that a sale matching several cancellation lines is still
--    counted once - a JOIN here fans out and overstates the total.
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*)                       AS reversed_sale_lines,
    COUNT(DISTINCT s.customer_id)  AS customers_affected,
    ROUND(SUM(s.sales_value), 2)   AS revenue_wrongly_counted,
    ROUND(100.0 * SUM(s.sales_value)
          / (SELECT SUM(sales_value) FROM vw_valid_sales), 2) AS pct_of_reported_net_sales
FROM vw_valid_sales AS s
WHERE EXISTS (
    SELECT 1
    FROM vw_cancellations AS c
    WHERE c.customer_id    = s.customer_id
      AND c.stock_code     = s.stock_code
      AND c.unit_price     = s.unit_price
      AND ABS(c.quantity)  = s.quantity
      AND c.quantity       < 0
      AND c.invoice_date  >= s.invoice_date
);


-- ----------------------------------------------------------------------------
-- 2. The corrected sales view. Added alongside vw_valid_sales, not replacing it.
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_valid_sales_net CASCADE;

CREATE VIEW vw_valid_sales_net AS
SELECT s.*
FROM vw_valid_sales AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM vw_cancellations AS c
    WHERE c.customer_id    = s.customer_id
      AND c.stock_code     = s.stock_code
      AND c.unit_price     = s.unit_price
      AND ABS(c.quantity)  = s.quantity
      AND c.quantity       < 0
      AND c.invoice_date  >= s.invoice_date
);


-- ----------------------------------------------------------------------------
-- 3. Restated headline totals: as published vs corrected
-- ----------------------------------------------------------------------------
SELECT 'As published (vw_valid_sales)' AS basis,
       COUNT(*) AS sales_lines, COUNT(DISTINCT customer_id) AS customers,
       ROUND(SUM(sales_value), 2) AS net_sales
FROM vw_valid_sales
UNION ALL
SELECT 'Corrected (vw_valid_sales_net)',
       COUNT(*), COUNT(DISTINCT customer_id), ROUND(SUM(sales_value), 2)
FROM vw_valid_sales_net;


-- ----------------------------------------------------------------------------
-- 4. THE PARETO TEST - is it really 80/20?
--
--    Rank customers by spend, accumulate, and find where the running total
--    crosses 80% of all revenue. SUM(...) OVER (ORDER BY spend DESC ROWS
--    UNBOUNDED PRECEDING) is a running total: each row adds itself to
--    everything ranked above it.
-- ----------------------------------------------------------------------------
WITH customer_spend AS (
    SELECT customer_id, SUM(sales_value) AS spend
    FROM vw_valid_sales_net GROUP BY customer_id
),
ranked AS (
    SELECT spend,
           ROW_NUMBER() OVER (ORDER BY spend DESC) AS rn,
           SUM(spend) OVER (ORDER BY spend DESC ROWS UNBOUNDED PRECEDING) AS cum_spend,
           SUM(spend) OVER ()   AS total_spend,
           COUNT(*)  OVER ()    AS total_customers
    FROM customer_spend
)
SELECT
    (SELECT MIN(rn) FROM ranked WHERE cum_spend >= 0.80 * total_spend) AS customers_making_80pct,
    ROUND(100.0 * (SELECT MIN(rn) FROM ranked WHERE cum_spend >= 0.80 * total_spend)
          / (SELECT MAX(total_customers) FROM ranked), 1)              AS pct_of_customer_base,
    ROUND(100.0 * (SELECT cum_spend FROM ranked
                   WHERE rn = ROUND((SELECT MAX(total_customers) FROM ranked) * 0.20))
          / (SELECT MAX(total_spend) FROM ranked), 1)                  AS pct_revenue_from_top_20pct;


-- ----------------------------------------------------------------------------
-- 5. The concentration curve, for the chart
-- ----------------------------------------------------------------------------
WITH customer_spend AS (
    SELECT customer_id, SUM(sales_value) AS spend
    FROM vw_valid_sales_net GROUP BY customer_id
),
ranked AS (
    SELECT ROW_NUMBER() OVER (ORDER BY spend DESC) AS rn,
           SUM(spend) OVER (ORDER BY spend DESC ROWS UNBOUNDED PRECEDING) AS cum_spend,
           SUM(spend) OVER () AS total_spend,
           COUNT(*)  OVER ()  AS total_customers
    FROM customer_spend
)
SELECT v.cut AS top_n_customers,
       ROUND(100.0 * v.cut / MAX(r.total_customers), 1) AS pct_of_customers,
       ROUND(MAX(CASE WHEN r.rn = v.cut THEN r.cum_spend END), 2) AS cumulative_revenue,
       ROUND(100.0 * MAX(CASE WHEN r.rn = v.cut THEN r.cum_spend END)
             / MAX(r.total_spend), 1) AS pct_of_revenue
FROM ranked AS r
CROSS JOIN (VALUES (1),(5),(10),(20),(50),(100),(433),(865),(1170)) AS v(cut)
GROUP BY v.cut
ORDER BY v.cut;


-- ----------------------------------------------------------------------------
-- 6. The top 10 customers, corrected
-- ----------------------------------------------------------------------------
WITH customer_spend AS (
    SELECT customer_id,
           SUM(sales_value)           AS spend,
           COUNT(DISTINCT invoice_no) AS orders,
           MIN(order_date)            AS first_order,
           MAX(order_date)            AS last_order
    FROM vw_valid_sales_net GROUP BY customer_id
),
-- A customer can appear under more than one country; take their most recent.
home AS (
    SELECT DISTINCT ON (customer_id) customer_id, country
    FROM vw_valid_sales_net ORDER BY customer_id, invoice_date DESC
)
SELECT ROW_NUMBER() OVER (ORDER BY cs.spend DESC) AS rank,
       cs.customer_id,
       ROUND(cs.spend, 2) AS lifetime_spend,
       ROUND(100.0 * cs.spend / SUM(cs.spend) OVER (), 2) AS pct_of_revenue,
       cs.orders,
       h.country,
       cs.first_order,
       cs.last_order
FROM customer_spend AS cs
JOIN home AS h ON h.customer_id = cs.customer_id
ORDER BY cs.spend DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- 7. EXPOSURE - what losing the top 10 would mean, in comparable units
-- ----------------------------------------------------------------------------
WITH customer_spend AS (
    SELECT customer_id, SUM(sales_value) AS spend
    FROM vw_valid_sales_net GROUP BY customer_id
),
ranked AS (
    SELECT customer_id, spend, ROW_NUMBER() OVER (ORDER BY spend DESC) AS rn
    FROM customer_spend
),
totals AS (
    SELECT SUM(spend) AS all_revenue, COUNT(*) AS all_customers,
           AVG(spend) AS avg_customer_value
    FROM customer_spend
)
SELECT
    ROUND(SUM(r.spend), 2)                                    AS top10_revenue,
    ROUND(100.0 * SUM(r.spend) / MAX(t.all_revenue), 2)       AS pct_of_total_revenue,
    ROUND(AVG(r.spend), 2)                                    AS avg_top10_customer,
    ROUND(MAX(t.avg_customer_value), 2)                       AS avg_customer_overall,
    ROUND(AVG(r.spend) / MAX(t.avg_customer_value), 0)        AS each_worth_x_average_customers,
    ROUND(SUM(r.spend) / MAX(t.avg_customer_value), 0)        AS avg_customers_needed_to_replace_all_10
FROM ranked AS r CROSS JOIN totals AS t
WHERE r.rn <= 10;


-- ----------------------------------------------------------------------------
-- 8. Where the concentration sits geographically
-- ----------------------------------------------------------------------------
WITH customer_spend AS (
    SELECT customer_id, SUM(sales_value) AS spend
    FROM vw_valid_sales_net GROUP BY customer_id
),
home AS (
    SELECT DISTINCT ON (customer_id) customer_id, country
    FROM vw_valid_sales_net ORDER BY customer_id, invoice_date DESC
),
ranked AS (
    SELECT cs.customer_id, cs.spend, h.country,
           ROW_NUMBER() OVER (ORDER BY cs.spend DESC) AS rn
    FROM customer_spend cs JOIN home h ON h.customer_id = cs.customer_id
)
SELECT country,
       COUNT(*) AS customers_in_top_10,
       ROUND(SUM(spend), 2) AS revenue,
       ROUND(100.0 * SUM(spend) / (SELECT SUM(spend) FROM customer_spend), 2) AS pct_of_all_revenue
FROM ranked WHERE rn <= 10
GROUP BY country ORDER BY revenue DESC;
