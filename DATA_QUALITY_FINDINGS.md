# Data Quality Findings

These are the actual results of running [sql/02_data_quality_checks.sql](sql/02_data_quality_checks.sql) against `online_retail_raw` after loading the full CSV, plus the sanity check at the end of [sql/03_clean_views.sql](sql/03_clean_views.sql). Every number here came from a query I actually ran against the loaded dataset — nothing is estimated. This is the evidence behind the cleaning rules in `vw_valid_sales` and behind the "Limitations" section of the README.

> **Revised August 2026.** Three of the observations at the bottom of this file were wrong. I had recorded two reversed orders as genuine outlier customers and an 80,995-unit keying error as a bulk purchase. The later analysis in `sql/07_revenue_concentration.sql` showed what they actually are. The corrections are in place below and marked as corrections rather than quietly edited out.

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
- **Cancellation rate:** **14.81%** — 3,836 cancelled invoices ÷ 25,900 total invoices, both counted from `vw_all_invoices`

**This was originally reported as 17.15%, and that was wrong.** The old calculation divided cancellations counted from the raw table by valid orders counted from `vw_valid_sales`, after rows with no customer ID had been removed — a smaller denominator drawn from a narrower population, which inflated the rate. It also could not be filtered by date without producing nonsense (February 2011 returned 79%). `vw_all_invoices` in `sql/03_clean_views.sql` counts both halves from one population, each row carrying a date, which fixes both faults. See the README's [Known issues](README.md#known-issues-found-after-the-dashboard-was-built) section.

Either way, cancellations are a material part of this business rather than a rounding error — roughly 1 in 7 invoices raised is a cancellation. That's the reason cancellations get their own dashboard page rather than being folded quietly into the sales numbers. What that £896,812.49 actually consists of is a separate question, and mostly not returns — see `sql/04_sales_analysis.sql` and [`outputs/query_results/17_cancellation_composition.csv`](outputs/query_results/17_cancellation_composition.csv).

## Non-positive quantity and price

- **Non-positive quantity:** 10,624 rows
- **Non-positive price:** 2,521 rows

Non-positive quantity is larger than the cancellation line count (9,288) because it also catches rows that have negative quantity but don't start with `C` — for example manual stock adjustments and write-offs recorded under stock codes like `D` (Discount), `M` (Manual), `BANK CHARGES` and `AMAZON FEE`. Non-positive price mostly reflects £0.00 unit prices, which UCI's own documentation associates with free samples, damaged-stock write-offs and similar non-sale adjustments rather than genuine transactions. Both get excluded from `vw_valid_sales` because they don't represent a real completed sale at a real price.

## Countries

38 distinct country values are present, including a few that aren't really countries: `Unspecified` (13 invoices) and `European Community` (5 invoices). These weren't recoded or dropped — they're left as-is in the raw data and simply show up as small, low-volume rows in the country breakdown. `United Kingdom` dominates the dataset by a wide margin (23,494 of the 25,900 invoices across all countries in the raw counts), which matches this being "a UK-based non-store retailer" per the dataset description — international sales are a small, deliberately separate slice of the business (see the "excluding UK" queries in `04_sales_analysis.sql`).

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

- **Customer IDs used to read "17850.0" instead of "17850". Fixed.** Roughly a quarter of the CustomerID cells are blank, and a plain whole-number column has nowhere to store "missing", so pandas converted the entire column to decimals to make room — turning every ID into `17850.0`. The `quantity` column is the control case: same kind of number, no blanks, and it came through as `6` / `56` / `80995` untouched. `src/01_excel_to_csv.py` now casts the column to pandas' nullable integer type (`Int64`), which holds whole numbers and blanks at the same time. Re-running the pipeline changed 406,829 ID values from `NNNNN.0` to `NNNNN` and **changed no other value anywhere** — 57 of the 64 exported CSVs are byte-identical, and the other 7 differ only in that column.
- **One single order for "PAPER CRAFT , LITTLE BIRDIE" was for 80,995 units** — more than five times the size of the largest genuine order in the dataset, which was 15,049 units. (The next-largest line, 74,215 units, turns out to be a reversed order too.) When I wrote this file I recorded it as a bulk or wholesale purchase and kept it in the data. **That was wrong.** Invoice `581483` was keyed at 09:15 on 2011-12-09 and reversed by `C581484` at 09:27 the same morning — a data-entry error corrected twelve minutes later, not a sale. It is still in `vw_valid_sales`, because that view excludes cancellation lines without subtracting the orders they reverse. See `sql/07_revenue_concentration.sql` and the "Known issues" section of the README.
- **One customer appeared to have spent £168,472.50 across 2 orders** (average order value £84,236.25) — the 4th-highest spender in the whole dataset. I originally recorded this as a genuine outlier customer. **It is not a customer at all.** Customer `16446`'s large order is the reversed invoice `581483` above. Their genuine lifetime spend is **£2.90** — two brushes. Measured on the corrected view `vw_valid_sales_net`, they do not appear in the top 10.
- **One customer appeared to have placed exactly 1 order worth £77,183.60** — the 10th-highest spend in the whole dataset. Same defect again: customer `12346`'s invoice `541431` (74,215 units) was reversed by `C541433` sixteen minutes later. Their genuine lifetime spend is **£0.00**.
- **The "one-time customer" rule still cannot tell "bought once, cheaply" from "bought once, enormously."** That limitation is real and separate from the reversal defect above, and it is called out in the README's limitations section.

## What this means for the dashboard

- Every chart on the Sales and Customer pages of the dashboard is built from the cleaned data, which represents about 73% of the original transaction lines and about 75% of transactions that had a customer attached to them. That exclusion is real and disclosed here, not silently dropped.
- Cancellations are shown on their own separate dashboard page rather than being subtracted from the sales figures, so the sales numbers reflect everything sold (before cancellations), and the cancellations page shows their scale independently.
- The "high-value" and "at-risk" customer categories come from a simple, clearly documented rule (2 or more orders, £1,000 or more spent in total, and no order in the last 90 days counting from the dataset's own final transaction date) — not a predictive model. The two outlier customers above are the clearest examples of where a simple rule like this starts to break down.
