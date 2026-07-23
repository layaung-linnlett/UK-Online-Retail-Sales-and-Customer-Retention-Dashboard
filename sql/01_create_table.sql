-- ============================================================================
-- 01_create_table.sql
--
-- What this does:
--   Creates the raw landing table for the UCI Online Retail dataset and loads
--   the CSV export into it with \copy. Nothing is cleaned or filtered here -
--   this table is a faithful copy of the source file, kept untouched so the
--   cleaning logic in 03_clean_views.sql can always be re-run or audited
--   against the original data.
--
-- Business question answered:
--   None directly - this is the foundation every other script depends on.
-- ============================================================================

DROP TABLE IF EXISTS online_retail_raw;

CREATE TABLE online_retail_raw (
    invoice_no      TEXT,
    stock_code      TEXT,
    description     TEXT,
    quantity        INTEGER,
    invoice_date    TIMESTAMP,
    unit_price      NUMERIC(12, 2),
    customer_id     TEXT,
    country         TEXT
);

-- Load the CSV. Run this with psql's working directory set to the project
-- root, or replace the path below with the absolute path to your own
-- data/online_retail.csv. Header must be specified because the first row
-- of the CSV is column names.
\copy online_retail_raw FROM 'data/online_retail.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- Confirm the load
SELECT *
FROM online_retail_raw
LIMIT 10;

SELECT COUNT(*) AS raw_rows
FROM online_retail_raw;
