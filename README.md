# UK Online Retail: Sales and Customer Retention Dashboard

**Which customers is this business about to lose, and how much is that worth?**

A Power BI dashboard and SQL analysis built on 541,909 transactions from a UK
online gift retailer, covering December 2010 to December 2011.

Reviewing the finished work, I found four errors in my own numbers. Two are
fixed. The other two are measured and disclosed: see
[What I got wrong](#what-i-got-wrong-and-what-i-did-about-it).

---

## Business context

A small online retailer has a year of transaction history and no analyst. The
sales figure is known. What isn't known is which customers sit behind it, which
of them have quietly stopped buying, and whether the numbers on the monthly
report mean what they appear to mean.

**Who would use this:** a commercial or marketing manager deciding where the
retention budget goes next quarter, and a finance lead who needs the returns
figure to match what actually came back through the door.

**The decision it supports:** whether to spend the retention budget on winning
back customers who already buy, or on acquiring new ones. Before either,
whether the reported numbers are sound enough to spend against.

**Why it matters here:** revenue is concentrated. It takes 27% of customers to
reach 80% of revenue. The ten largest are worth 70 average customers each, and
replacing all ten would take 703 of them. At that
concentration, a handful of established buyers carry revenue it would take
hundreds of average customers to replace. Knowing *which* ones are drifting is
worth more than knowing the total.

---

## Data and method

**Data.** The UCI Online Retail dataset: 541,909 invoice lines from a UK-based
online gift retailer, 1 December 2010 to 9 December 2011. One row per product
line per invoice: invoice number, stock code, description, quantity, date, unit
price, customer ID, country. It contains **no cost data**, so nothing here is
about profit or margin.

**Method.** The raw CSV is loaded into PostgreSQL and left untouched. All
cleaning happens in SQL views on top of it, so every filter stays visible and
auditable rather than being baked into a saved copy. Eleven SQL scripts run in
order; Power BI connects to the views and holds fourteen DAX measures.

**What was excluded, and why:**

| Excluded | Rows | Reason |
|---|---:|---|
| Cancellation invoices (prefix `C`) | 3,836 invoices | Analysed separately rather than deleted |
| Non-positive quantity | 10,624 | Adjustments, write-offs, samples — not sales |
| Non-positive price | 2,521 | Same |
| No customer ID | 135,080 (24.93%) | Cannot be attributed to a customer |

**One thing to know before reading any number below.** Net sales is
£8,465,533.16: every sale line that a later cancellation reversed is removed.
The first version of the dashboard reported £8,911,407.90 because it counted
those lines as revenue, an error I found afterwards and have since fixed. The
original view (`vw_valid_sales`) is kept unchanged so the old figures, and the
size of the error, stay reproducible. The comparison is in
[docs/analysis_summary.md](docs/analysis_summary.md).

**Verification.** Every number quoted here is produced by a query in `sql/` and
written to a CSV in [`outputs/query_results/`](outputs/query_results/) by a
single script: 66 files, one per query. The script reads the queries out of the
`.sql` files rather than holding its own copies, so a CSV cannot drift from the
query it claims to come from. Nothing here is typed from memory.

---

## Key findings

Full working for each of these, with the supporting tables and the illustrative
sums, is in [docs/findings.md](docs/findings.md).

### 1. The customers most worth keeping were not on the at-risk list

**Observation.** A fixed rule (two or more orders, £1,000+ spent, silent
for 90+ days) returned 191 customers holding £440,689.14 of historical spend.
Testing each customer against their *own* median gap between purchases instead
returns 219 customers and £427,266.82. Only 84 names appear on both lists.

**Insight.** A single 90-day threshold treats a customer who buys weekly and one
who buys quarterly as the same person. It is wrong in both directions. Customer
`16029`, the 11th largest customer in the business, buys every 8 days and
had been silent for 38 days, nearly five times their own rhythm. The 90-day rule
classified them "High-value active" and put them on no list at all.

**Implication.** The original list sent budget towards slow buyers behaving
normally, while missing frequent, high-value buyers who had genuinely stopped.

**Recommendation.** Score customers against their own buying rhythm, not a
company-wide number of days. Work the resulting list top-down by value with a
named owner per account. Measure contact rate, repurchase rate, and revenue
within 30 days.

### 2. Two-thirds of the "cancellations" figure is not a customer returning anything

**Observation.** £896,812.49 of cancelled invoices. Split by what the line
actually is: £406,148.78 is fees and accounting adjustments, £11,939.53 is
shipping refunds, £168,469.60 is a single keying error, and only £310,254.58
(34.6%) is merchandise a customer sent back.

**Insight.** Marketplace fees, bank charges and manual adjustments are recorded
under the same cancellation-style invoice numbers as genuine returns, so one
chart is measuring at least three unrelated things. The December spike that
looks like a seasonal returns problem is 96.5% one data-entry error plus two
Amazon fees: an 80,995-unit order keyed at 09:15 and reversed at 09:27 the same
morning.

**Implication.** Planning against the reported figure sizes the returns problem
at roughly 2.9× its real scale and points effort at a December that needs no
investigating.

**Recommendation.** Finance: code fees and manual adjustments to their own
ledger line. Operations: add a quantity validation rule at order entry, since
that single entry distorted three charts and a third of one month's revenue.
This is a data-entry standard, not an analysis task. Correct the number
before acting on it.

### 3. The repeat-purchase problem is half the size it appears

**Observation.** 34% of customers appear to buy only once (1,490 of 4,327).
Given a fair 270-day window in which to return, the rate is 17.9%.

**Insight.** The naive rate counts a customer who first bought in November as a
failure by December. The median second purchase takes 57 days, which is 2.6×
longer than every gap after it. Of customers still silent 90 days after their
first order, 63.9% eventually came back. There is no cliff; the point where a
first-time buyer becomes more likely gone than returning is around day 150.

**Implication.** A win-back campaign triggered at 30 or 60 days of silence is
largely spent on people who were going to return anyway, and the headline
one-and-done rate overstates the problem it is meant to size.

**Recommendation.** Time a second-purchase incentive to the 57-day median rather
than to an arbitrary month, and do not write a first-time buyer off before
roughly 150 days. Measure the share of first-time buyers making a second
purchase within 60 days, before and after.

### 4. December is not a collapse

**Observation.** Monthly sales run from £442,782.04 in February to
£1,144,117.11 in November, a 2.6× swing. The December bar then falls off a
cliff.

**Insight.** Two artefacts, not a business event. The dataset stops on 9
December, so December is a nine-day month charted against thirty-day ones, and
the phantom order from finding 2 (£168,469.60) sat inside it until the sales
figures were netted of reversed orders. Per calendar day, December ran at
£38,758 against November's £38,137, within 2%.

**Implication.** Anyone reading that bar at face value would plan the following
year around a crash that never happened.

**Recommendation.** Plan stock, staffing and capacity for the autumn ramp, and
never chart a partial period beside complete ones without marking it as partial.
Measure stockouts in September–November and whether demand was met without
operational strain.

### 5. Two of the four "international markets" are single accounts

**Observation.** Netherlands £284,143.74 from 9 customers; EIRE £250,576.05
from 3; Germany £225,087.17 from 94; France £205,352.44 from 87. Read as sales
per customer that gives the Netherlands £31,572 and EIRE £83,525, against
roughly £2,400 for Germany and France.

**Insight.** Those two averages describe nobody. The largest customer in the
entire business is Dutch, and two of the ten largest are Irish. One Dutch
customer accounts for 98.2% of Dutch revenue, leaving the other eight
about £650 each. Two Irish customers account for 98.3% of Irish
revenue. Germany and France are genuinely different: roughly 90 customers each,
at a value per customer in line with an ordinary repeat buyer.

*(Sources: [`06_sales_by_country.csv`](outputs/query_results/06_sales_by_country.csv)
and [`33_top_10_customers_corrected.csv`](outputs/query_results/33_top_10_customers_corrected.csv),
both on the same net-of-reversals basis.)*

**Implication.** "Grow the Netherlands" is not a strategy that can be costed
from this data, because there is no such thing as an average Dutch customer to
acquire more of. Nor is Dutch revenue diversified by having nine names on it.
The concentration is a retention risk sitting inside a number that looks like a
market, and the same is true of Ireland.

**Recommendation.** Treat the Netherlands and EIRE as three named accounts
rather than two countries, and manage them for retention with a named owner
each. Send the international acquisition budget to Germany and France, where
around 90 customers each is evidence of demand that can be bought into
repeatedly. Before anything else, find out whether anyone in the business
already knows those three accounts are that large.

---

## What I would tell a stakeholder to do

In priority order, judged on effort against impact rather than on which number
is biggest:

| # | Action | Owner | Why this order |
|---|---|---|---|
| 1 | Rebuild the at-risk list on per-customer cadence and work it top-down by value | Marketing / commercial | The customers are already identifiable from data in hand. No new collection, no new spend to find them. |
| 2 | Split fees and adjustments out of the cancellation figure | Finance + whoever owns invoicing | Nothing downstream is trustworthy until the number stops measuring three things at once. |
| 3 | Add an order-entry quantity validation rule | Operations | One bad row distorted three charts and a month of revenue. Cheap, permanent. |
| 4 | Give the three customers who carry the Netherlands and EIRE named account owners | Account management | Almost all of both countries' revenue sits on those three names. Concentrated revenue needs protecting before distributed revenue needs growing. |
| 5 | Test a second-purchase incentive timed to ~57 days | Marketing | Worth testing, but it is a test — the return rate is not knowable from this data. |

**What I am deliberately not doing: putting a return figure on any of this.**
Estimating the value of a win-back campaign needs a win-back rate and a customer
acquisition cost, and neither exists in this dataset. `docs/findings.md`
contains illustrative sums to show the *size* of each opportunity; they are
labelled as illustrations and none of them is a forecast.

---

## Dashboard

The dashboard has three pages. Every figure on them reconciles with the CSVs in
[`outputs/query_results/`](outputs/query_results/) and with the numbers above.
The report file is in the repository at
[`powerbi/online_retail_dashboard.pbix`](powerbi/online_retail_dashboard.pbix)
and opens without a database, since the data is imported rather than live.

**Note:** the SQL, the exported CSVs and the DAX measures use the corrected net
sales basis (£8,465,533.16). The report file and screenshots below were built
on the earlier basis (£8,911,407.90) and need refreshing in Power BI Desktop
before they match: see the checklist in
[docs/powerbi_build_guide.md](docs/powerbi_build_guide.md).

**1. Sales performance overview.** Net sales, orders, customers, average order
value, the monthly trend, top products and international markets.

![Sales performance overview](outputs/figures/page1_sales_overview.jpg)

**2. Customer retention and value.** All five customer segments (summing to
4,327, matching Unique Customers on page 1), highest-spending customers, and the
191-name call list behind finding 1.

![Customer retention and value](outputs/figures/page2_customer_retention.jpg)

**3. Cancellations and product demand.** Cancellation rate, the monthly trend
with its December spike, and the composition chart behind finding 2.

![Cancellations and product demand](outputs/figures/page3_cancellations_products.jpg)

---

## What I got wrong, and what I did about it

Reviewing the finished dashboard, I found four errors in my own work. The rule I
applied: **cheap and local, fix it; expensive and cascading, measure it and
bracket it first, then fix it once the size is known.** Two are now fixed; two
are measured and disclosed.

### Fixed: the cancellation rate was overstated, and broke under filtering

The rate was calculated as cancelled invoices ÷ (cancelled invoices + valid
orders). The problem is that the numerator was counted from the raw table
and the denominator
from the cleaned view, so the two halves came from different populations.

Worse, `vw_valid_sales` was related to the report's date table and
`vw_cancellations` was not, so any date filter shrank the denominator and left
the numerator whole. Filtered to February 2011 the card returned 79.37% against
a real rate of 15.72%. The card was useless under any date
filter.

Both are fixed. `vw_all_invoices` is one row per invoice for the whole dataset,
each carrying a date, and both halves now count from it.

| | Before | After |
|---|---:|---:|
| Full period | 17.15% | 14.81% |
| Filtered to February 2011 | 79.37% | 15.72% |

### Fixed: "Net Sales" was not net of returns

A cancellation is a separate invoice beginning with `C`. The original positive
sale line stays in the data under its own number and passes every cleaning
filter, so an order that was placed and then cancelled still counted as revenue,
while the cancellation that reversed it counted as nothing.

Matching each cancellation to the exact sale line it reverses (same customer,
product, unit price and quantity, cancelled on or after the sale) identifies
£445,874.74 across 3,887 lines and 792 customers, exactly 5.00% of reported net
sales. `vw_valid_sales_net` in
[sql/03_clean_views.sql](sql/03_clean_views.sql) removes those lines, and every
sales, customer, cadence and cohort query now runs on it.

| | Before | After |
|---|---:|---:|
| Net sales | £8,911,407.90 | £8,465,533.16 |
| Orders | 18,532 | 18,366 |
| Customers | 4,338 | 4,327 |

**What is not fixed.** Cancellations that carry a customer ID but match no sale
exactly are not removed, because they cannot be tied to a specific line.
Including them would raise the correction to £611,342, so true net sales for
identified customers lies between £8,300,066 and £8,465,533. The headline uses
the lower correction because every line of it can be listed and checked.

### Measured, not fixed: the sales totals exclude rows they did not need to

Requiring a customer ID is correct for the customer pages, since you cannot
group by an ID that is not there. It is wrong for the sales pages, where those
rows still carry a valid date, product, quantity and price. The 135,080 rows
without a customer ID are worth £1,755,277.

With the reversed orders now removed, this error works in one direction only:
net sales leaves out rows worth £1,755,277 that carry no customer ID, so it
understates the business's sales. It is a known limit and the largest
uncorrected figure in this project.

**Why I fixed one at first and not the others.** The cancellation rate is
self-contained: correcting it changed one card. Net Sales was the denominator of
nearly every figure in this project, so I first measured and bracketed the
error instead of restating everything. I have since restated it, because
leaving a known error in a headline number is the wrong trade-off for anyone who
might spend against it. The original view, `vw_valid_sales`, is kept so the old
numbers reproduce, and [docs/analysis_summary.md](docs/analysis_summary.md)
carries both bases side by side.

---

## Limitations

**No cost data.** The dataset has prices but no costs, so nothing here measures
profit or margin. A product with high sales may not be a product worth stocking.

**A quarter of the business is invisible.** 135,080 rows (24.93%) have no
customer ID. Every customer-level figure describes only the transactions that
can be attributed to someone.

**Nobody is confirmed to have left.** The data ends on 9 December 2011. A
customer "at risk" is one who has been silent, not one known to have gone. They
may have ordered on 10 December. Every retention figure here is
right-censored, and this is why I did not build a churn model: with one year of
data there is no later period in which to observe who actually churned, so there
is nothing to train or validate against.

**The at-risk rule is a business rule, not a model.** Both versions, the original
90-day rule and the cadence rule that replaced it, identify customers
behaving unlike themselves. Neither estimates a probability of returning.

**Cadence needs history most customers do not have.** The cadence rule only
scores customers with three or more purchase occasions. Those with one or two
are reported separately rather than judged.

**One year means one Christmas.** Seasonality is described from a single cycle,
so it cannot be separated from anything else that happened that year.

**What distinguishes stayers from leavers is correlation only.** That part of
the follow-up ([docs/analysis_summary.md](docs/analysis_summary.md) §8)
establishes no causation, and the signal is weak.

**The data is from 2010–2011**, one retailer, one country. The seasonal pattern
and country mix need not resemble today's market.

---

## Tech stack

| Tool | Used for |
|---|---|
| **PostgreSQL** | Storing the raw transaction data and building the cleaning views |
| **SQL** | Cleaning, quality checks and all analysis — CTEs, window functions |
| **Python (pandas)** | Excel-to-CSV conversion, and exporting every query result to CSV |
| **Power BI** | The three-page dashboard |
| **DAX** | The fourteen dashboard measures |

---

## How to run

### 1. Get the data

Download `Online Retail.xlsx` from the
[UCI repository](https://archive.ics.uci.edu/dataset/352/online+retail) and put
it in `data/`. See [data/README.md](data/README.md).

### 2. Convert it to CSV

```bash
pip install -r requirements.txt
python src/01_excel_to_csv.py
```

### 3. Create the database

```bash
createdb online_retail_db
psql -d online_retail_db -f sql/01_create_table.sql
```

### 4. Run the SQL, in order

Scripts `02`–`05` build the dashboard's views. Scripts `06`–`11` are the 2026
follow-up. The original, uncorrected sales view (`vw_valid_sales`) is kept
alongside the corrected `vw_valid_sales_net` that everything now builds on, so
the old figures still reproduce. They depend on the earlier views, so order
matters.

```bash
for f in sql/0[2-9]_*.sql sql/1[01]_*.sql; do psql -d online_retail_db -v ON_ERROR_STOP=1 -f "$f"; done
```

Re-running a script drops and recreates its views with `CASCADE`, which also
drops anything built on top. That is deliberate, because a stale dependent view is
worse than a missing one, but it means running forward in order rather than
individually out of sequence.

### 5. Export the query results

```bash
python src/02_export_query_results.py
```

Writes 66 CSVs to `outputs/query_results/`, one per query.

### 6. Open the report

```text
powerbi/online_retail_dashboard.pbix
```

Power BI Desktop is Windows-only. The data is imported, so the whole report
reads without PostgreSQL running; it only asks for credentials on Refresh, and
the stored server address is whichever machine it was built on. Change it under
**Transform data → Data source settings**. To rebuild it from scratch instead,
follow [docs/powerbi_build_guide.md](docs/powerbi_build_guide.md).

---

## Repository

```text
├── data/       download instructions (the dataset itself is not tracked)
├── src/        01 Excel→CSV, 02 exports every query to CSV
├── sql/        01–11, run in order: load, check, clean, analyse
├── outputs/    figures/ (dashboard screenshots), query_results/ (66 CSVs)
├── powerbi/    the .pbix report and the 14 DAX measures
└── docs/       findings.md, analysis_summary.md, data_quality.md,
                powerbi_build_guide.md
```

| Script | Answers |
|---|---|
| `01_create_table.sql` | Loads the raw CSV into an untouched landing table |
| `02_data_quality_checks.sql` | Is this data trustworthy, and what must be excluded? |
| `03_clean_views.sql` | What counts as a real sale, and how big are cancellations? |
| `04_sales_analysis.sql` | Sales over time, by product, by country; what cancellations consist of |
| `05_customer_analysis.sql` | Who is valuable, and who has gone quiet (90-day rule) |
| `06_retention_cadence.sql` | At-risk customers judged against their own buying rhythm |
| `07_revenue_concentration.sql` | Revenue concentration, top-customer exposure, the reversal defect |
| `08_first_to_second_purchase.sql` | One-and-done rate, and how long a second purchase takes |
| `09_cohort_retention.sql` | Retention by first-purchase month |
| `10_customer_value.sql` | Observed customer value, one-time versus repeat |
| `11_stayers_vs_leavers.sql` | What separates retained from lapsed customers (correlation only) |

Further reading: [docs/findings.md](docs/findings.md) (the five findings in
full) · [docs/analysis_summary.md](docs/analysis_summary.md) (the 2026
follow-up, every number and its query) ·
[docs/data_quality.md](docs/data_quality.md) (what the raw data looks like).

---

## Licence and source

Code and documentation are MIT licensed: see [LICENSE](LICENSE).

The dataset is not mine and is not covered by that licence:
Chen, D. (2015). *Online Retail* [Dataset]. UCI Machine Learning Repository.
[https://doi.org/10.24432/C5BW33](https://doi.org/10.24432/C5BW33), CC BY 4.0.
It is not redistributed here. `data/` is gitignored and the download step is
above.

---

## Contact

**La Yaung Linn Lett**

[GitHub](https://github.com/layaung-linnlett) ·
[LinkedIn](https://www.linkedin.com/in/layaung-linnlett/) ·
[layaunglinnlett1@gmail.com](mailto:layaunglinnlett1@gmail.com)
