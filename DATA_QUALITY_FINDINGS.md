# Data Quality Findings

These are the actual results of running [sql/02_data_quality_checks.sql](sql/02_data_quality_checks.sql) against `online_retail_raw` after loading the full CSV, plus the sanity check at the end of [sql/03_clean_views.sql](sql/03_clean_views.sql). Every number here came from a query I actually ran against the loaded dataset — nothing is estimated. This is the evidence behind the cleaning rules in `vw_valid_sales` and behind the "Limitations" section of the README.

## Raw table

- **Total rows loaded:** 541,909 (matches the row count published for the UCI Online Retail dataset)
- **Date range:** 2010-12-01 08:26:00 to 2011-12-09 12:50:00 — just over a year of transactions

## Missing values (raw table)

| Field | Missing rows | % of raw rows |
|---|---|---|
| invoice_no | 0 | 0.00% |
| stock_code | 0 | 0.00% |
| description | 1,454 | 0.27% |
| customer_id | 135,080 | 24.93% |
| country | 0 | 0.00% |

`customer_id` is the big one — almost a quarter of all line items have no customer attached. These are dropped from `vw_valid_sales` and from every customer-level query, because there's no way to attribute them to a customer. It also means the customer-level totals in this project (4,338 identified customers, £8.9m net sales) understate the retailer's true total activity — they only cover the ~75% of transactions that carry a customer ID.

## Cancellations

- **Cancelled invoices:** 3,836 distinct invoice numbers starting with `C`
- **Cancellation lines:** 9,288 rows (1.71% of raw rows)
- **Cancellation value:** £896,812.49 (from `vw_cancellations`, `ABS(quantity * unit_price)`)
- **Cancellation rate:** 17.15% — calculated as cancelled invoices ÷ (cancelled invoices + valid orders) = 3,836 ÷ (3,836 + 18,532)

Cancellations are a genuinely material part of this business, not a rounding error — roughly 1 in 6 orders ends up cancelled. That's the headline reason cancellations get their own dashboard page rather than being folded quietly into the sales numbers.

## Non-positive quantity and price

- **Non-positive quantity:** 10,624 rows
- **Non-positive price:** 2,521 rows

Non-positive quantity is larger than the cancellation line count (9,288) because it also catches rows that have negative quantity but don't start with `C` — for example manual stock adjustments and write-offs recorded under stock codes like `D` (Discount), `M` (Manual), `BANK CHARGES` and `AMAZON FEE`. Non-positive price mostly reflects £0.00 unit prices, which UCI's own documentation associates with free samples, damaged-stock write-offs and similar non-sale adjustments rather than genuine transactions. Both get excluded from `vw_valid_sales` because they don't represent a real completed sale at a real price.

## Countries

38 distinct country values are present, including a few that aren't really countries: `Unspecified` (13 invoices) and `European Community` (5 invoices). These weren't recoded or dropped — they're left as-is in the raw data and simply show up as small, low-volume rows in the country breakdown. `United Kingdom` dominates the dataset by a wide margin (23,494 of the ~24,969 invoices across all countries in the raw counts), which matches this being "a UK-based non-store retailer" per the dataset description — international sales are a small, deliberately separate slice of the business (see the "excluding UK" queries in `04_sales_analysis.sql`).

## After cleaning: `vw_valid_sales`

Running the sanity check at the bottom of `03_clean_views.sql`:

| Metric | Value |
|---|---|
| Valid sales lines | 397,880 |
| Valid orders (distinct invoices) | 18,532 |
| Identified customers | 4,338 |
| Net sales | £8,911,407.90 |

397,880 of 541,909 raw rows (73.4%) survive the cleaning rules in `vw_valid_sales`. The other ~26.6% is accounted for by cancellations, missing customer IDs, missing descriptions, and non-positive quantity/price — these categories overlap (e.g. a cancelled row often also has negative quantity), so they don't sum cleanly to the excluded total, but each one is independently verifiable by re-running `02_data_quality_checks.sql`.

## Things that looked statistically odd and are worth flagging honestly

- **Customer ID numbers show up as "17850.0" instead of "17850"** in the CSV file. This looks odd but isn't a data error — it happened during the Excel-to-CSV conversion step. Some customer ID cells were blank (no customer attached to that order), and when a column mixes numbers with blanks, the conversion tool automatically treats the whole column as decimal numbers rather than plain IDs, adding a ".0" to every value. Every customer's ID is still correct and unique — it's just a cosmetic formatting quirk from the conversion, not a sign of duplicated or broken customer records.
- **One single order for "PAPER CRAFT , LITTLE BIRDIE" was for 80,995 units** — more than six times the size of the next-largest order in the entire dataset. This is almost certainly one bulk or wholesale purchase, not how a typical customer shops. I kept it in the data, because it's a real, valid order (a real quantity, a real price, linked to a real customer) — but it single-handedly inflates that product's ranking on any "top products by quantity" chart, so that particular chart shouldn't be read as "what customers usually buy."
- **One customer placed only 2 orders but spent £168,472.50 in total** (average order value £84,236.25) — the 4th-highest spender in the whole dataset, despite barely qualifying as a "repeat" customer at all. Almost all of that spend comes from just one of the two orders. It's a genuine customer, not an error, but it's the kind of single outlier that can throw off an "average spend" statistic if you're not careful.
- **One customer placed exactly 1 order worth £77,183.60** — the 10th-highest spend in the whole dataset — yet gets grouped into the "One-time customer" category alongside people who spent a few pounds once and never came back. This is a genuine limitation of a simple rule based only on how many times someone ordered: it can't tell the difference between "bought once, cheaply" and "bought once, enormously." That's called out directly in the README's limitations section.

## What this means for the dashboard

- Every chart on the Sales and Customer pages of the dashboard is built from the cleaned data, which represents about 73% of the original transaction lines and about 75% of transactions that had a customer attached to them. That exclusion is real and disclosed here, not silently dropped.
- Cancellations are shown on their own separate dashboard page rather than being subtracted from the sales figures, so the sales numbers reflect everything sold (before cancellations), and the cancellations page shows their scale independently.
- The "high-value" and "at-risk" customer categories come from a simple, clearly documented rule (2 or more orders, £1,000 or more spent in total, and no order in the last 90 days counting from the dataset's own final transaction date) — not a predictive model. The two outlier customers above are the clearest examples of where a simple rule like this starts to break down.
