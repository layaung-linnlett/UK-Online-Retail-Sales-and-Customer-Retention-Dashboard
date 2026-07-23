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

- **`customer_id` has a trailing `.0` in the CSV** (e.g. `17850.0` instead of `17850`). This isn't a data entry error — pandas reads the `CustomerID` column as a float because it contains both numbers and blanks (`NaN`), and `df.to_csv()` then writes every value in float notation. The values are still correct and unique per customer; it's a cosmetic side effect of the Excel→CSV conversion, not evidence of duplicate or corrupted customer records.
- **One order for "PAPER CRAFT , LITTLE BIRDIE" contains 80,995 units** in a single invoice line, more than six times the next-largest quantity in the top-products list. This is almost certainly a single wholesale/bulk order rather than typical retail behaviour, and it inflates that product's units-sold ranking. It wasn't excluded, because it's a genuine positive-quantity, positive-price, customer-attributed transaction — but it's worth calling out rather than treating the "top products by quantity" chart at face value.
- **Customer `16446.0` has only 2 orders but £168,472.50 total spend** (average order value £84,236.25), the 4th-highest spender in the dataset despite having placed almost the fewest possible orders to qualify as "repeat." One of those two orders is doing almost all of that value. It's a legitimate customer record, but it's an outlier that can visibly skew any "average spend per high-value customer" statistic.
- **Customer `12346.0` placed exactly 1 order worth £77,183.60** — the 10th-highest spend in the dataset — and is therefore classified as a "One-time customer" by the segmentation rule in `05_customer_analysis.sql`, alongside customers who spent a few pounds once. This is a real limitation of an orders-count-based segmentation rule: it can't distinguish "bought once, cheaply" from "bought once, enormously." Worth a line in the README limitations section.

## What this means for the dashboard

- Every visual built on `vw_valid_sales` and `vw_customer_profile` implicitly represents ~73% of raw transaction lines and ~75% of transactions that have a customer attached — this is a real, disclosed exclusion, not silently dropped data.
- Cancellations are reported separately, not netted off net sales, so the sales-overview numbers reflect gross completed sales and the cancellations page shows their own scale independently.
- The high-value/at-risk segmentation is a simple, documented business rule (≥2 orders, ≥£1,000 spend, >90 days since last order relative to the dataset's own end date), not a predictive model — the two single-order outliers above are the clearest evidence of where that rule's edges show.
