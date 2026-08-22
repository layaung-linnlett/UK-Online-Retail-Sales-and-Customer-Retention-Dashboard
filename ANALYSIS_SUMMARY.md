# Retention Analysis — Headline Numbers and Limitations

Every number below was produced by a query in this repository and re-run against
the database on 2026-08-21. Each row names the file and section that produced it,
so any figure can be reproduced in front of the person asking about it.

## Read this first: two bases for every revenue number

This analysis found a defect in the original cleaning logic (see §2 below).
`vw_valid_sales` counts fully cancelled orders as revenue. It was **not**
modified — the original view still reproduces every published dashboard number.
A corrected view, `vw_valid_sales_net`, was added alongside it.

| Basis | View | Lines | Customers | Net sales |
|---|---|---:|---:|---:|
| As published | `vw_valid_sales` | 397,880 | 4,338 | £8,911,407.90 |
| Corrected | `vw_valid_sales_net` | 393,993 | 4,327 | £8,465,533.16 |

**Always say which basis a number is on.** Q1's before/after comparison uses the
published basis so it is like-for-like with the original 195. Everything from Q2
onward uses the corrected basis.

---

## 1. Data foundation

| Number | Value | Source |
|---|---:|---|
| Raw rows loaded | 541,909 | `sql/02_data_quality_checks.sql` |
| Rows missing customer ID | 135,080 (24.93%) | `sql/02_data_quality_checks.sql` |
| Valid sales lines (published) | 397,880 | `sql/03_clean_views.sql` sanity check |
| Identified customers (published) | 4,338 | `sql/03_clean_views.sql` sanity check |
| Net sales (published) | £8,911,407.90 | `sql/03_clean_views.sql` sanity check |
| Date range | 2010-12-01 to 2011-12-09 | `sql/02_data_quality_checks.sql` |

## 2. The defect found during this work

| Number | Value | Source |
|---|---:|---|
| Sale lines reversed by a later cancellation, still counted | 3,887 | `sql/07_revenue_concentration.sql` §1 |
| Customers affected | 792 | `sql/07_revenue_concentration.sql` §1 |
| **Revenue wrongly counted** | **£445,874.74** | `sql/07_revenue_concentration.sql` §1 |
| As share of reported net sales | **5.00%** | `sql/07_revenue_concentration.sql` §1 |
| Corrected net sales | £8,465,533.16 | `sql/07_revenue_concentration.sql` §3 |

Two worked examples, both previously in the published top 10 by spend:

| Customer | Published as | Reality |
|---|---:|---|
| 16446.0 | £168,472 — 4th largest | Invoice 581483 (80,995 units) reversed by C581484 **12 minutes later**. True spend **£2.90** |
| 12346.0 | £77,184 — 10th largest | Invoice 541431 (74,215 units) reversed by C541433 **16 minutes later**. True spend **£0.00** |

## 3. Q1 — At-risk customers by their own cadence

**Rule:** silent for more than **2×** their own median gap between purchases, and
at least 30 days. Only customers with 3+ purchase occasions are scored.

| Number | Value | Source |
|---|---:|---|
| Overall median gap between purchases | 28 days | `sql/06_retention_cadence.sql` §1 |
| Historical gaps examined to set the multiple | 11,551 | `sql/06_retention_cadence.sql` §1 |
| Share of real gaps exceeding 1.5× own median | 22.4% | `sql/06_retention_cadence.sql` §1 |
| **Share exceeding 2× own median** | **11.6%** | `sql/06_retention_cadence.sql` §1 |
| Share exceeding 3× own median | 5.0% | `sql/06_retention_cadence.sql` §1 |
| Share exceeding 4× own median | 2.8% | `sql/06_retention_cadence.sql` §1 |
| Invoices collapsed to purchase occasions | 18,532 → 16,763 | `sql/06_retention_cadence.sql` header |
| Customers with same-day multiple invoices | 697 | `sql/06_retention_cadence.sql` header |
| Customers suppressed by the 30-day floor | 11 (£67,972) | `sql/06_retention_cadence.sql` §9 |

### Before / after

| List | Customers | Revenue | Basis | Source |
|---|---:|---:|---|---|
| **A.** Old: high-value at risk (90d + £1,000) | 195 | £471,684.33 | published | `sql/05_customer_analysis.sql` |
| **B.** Old: all at-risk repeat (90d, no spend floor) | 602 | £678,131.91 | published | `sql/07` §4 |
| **C.** New: overdue on own cadence (2×) | 224 | £462,554.75 | published | `sql/06` §4 |
| **C-net.** Same rule, corrected data | **219** | **£427,266.82** | corrected | `sql/11` via `vw_customer_cadence_net` |

Re-running the cadence rule on corrected data changes the list from 224 to 219,
with **217 of the same customers** — the finding is robust to the defect fix.

### Who moved (vs baseline B, like-for-like)

| Movement | Customers | Revenue | Their median gap | Days quiet |
|---|---:|---:|---:|---:|
| Dropped by cadence rule | 435 | £431,160.40 | 89.5 | 175.3 |
| On both lists | 167 | £246,971.51 | 39.1 | 169.8 |
| Added by cadence rule | 57 | £215,583.24 | 21.6 | 63.4 |

*Source: `sql/06_retention_cadence.sql` §5*

### Who moved (vs baseline A, the 195)

| Movement | Customers | Revenue |
|---|---:|---:|
| Dropped | 109 | £270,666.46 |
| Added | 138 | £261,536.88 |
| On both | 86 | £201,017.87 |

*Source: `sql/06_retention_cadence.sql` §6.* Only 86 of the original 195 survive.

### The lead example

**Customer 16029.0** — £60,653.40 lifetime spend on the corrected basis, the
**11th largest customer in the business**. Buys every 7.5 days. Silent 38 days —
**5.07× their own rhythm**. The 90-day rule classified them **"High-value active"**.

Three others in the same position, all classed "High-value active":
16729.0, 16745.0, 15939.0.

*Source: `sql/06_retention_cadence.sql` §7b*

### Reported separately (too little history to score)

| Bucket | Customers | Revenue | Source |
|---|---:|---:|---|
| Single purchase — no cadence | 1,545 | £618,836.25 | `vw_customer_cadence_net` |
| Two purchases — cadence unreliable | 878 | £680,903.63 | `vw_customer_cadence_net` |

*Corrected basis. On the published basis these read 1,548 / £704,741.62 and
874 / £869,915.49 (`sql/06` §8) — the difference is the reversal fix.*

## 4. Q2 — Revenue concentration and exposure

*All corrected basis.*

| Number | Value | Source |
|---|---:|---|
| Customers producing 80% of revenue | **1,170 (27.0%)** | `sql/07` §4 |
| Revenue from the top 20% of customers | **73.7%** | `sql/07` §4 |
| Revenue from the top 10 customers | **£1,374,876.04 (16.24%)** | `sql/07` §5, §7 |
| Revenue from the top 1 customer | £278,953.22 (3.30%) | `sql/07` §5 |
| Revenue from the top 100 customers | £3,267,102.95 (38.6%) | `sql/07` §5 |
| Average top-10 customer | £137,487.60 | `sql/07` §7 |
| Average customer overall | £1,956.44 | `sql/07` §7 |
| Each top-10 customer is worth | **70 average customers** | `sql/07` §7 |
| Replacing all ten would take | **703 average customers** (16% of the base) | `sql/07` §7 |
| Top-10 customers outside the UK | 4 of 10, 6.7% of all revenue | `sql/07` §8 |

**It is 80/27, not 80/20.**

## 5. Q3 — One-and-done rate

*All corrected basis.*

| Number | Value | Source |
|---|---:|---|
| One-and-done, naive (all customers) | 1,545 — **35.7%** | `sql/08` §1 |
| Same, counted by invoice | 1,490 — 34.4% | `sql/08` §1 |
| One-and-done, 90-day fair window | 26.1% | `sql/08` §2 |
| **One-and-done, 270-day fair window** | **17.9%** (336 of 1,873) | `sql/08` §2 |
| Median days to second purchase | **57** | `sql/08` §3 |
| 25th / 75th / 90th percentile | 27 / 117 / 193 days | `sql/08` §3 |
| **Median gap, 1st → 2nd purchase** | **57 days** | `sql/08` §4 |
| **Median gap, all later purchases** | **22 days** | `sql/08` §4 |
| Silent at day 90 → still eventually returned | **63.9%** | `sql/08` §5 |
| Silent at day 150 → still eventually returned | 48.3% | `sql/08` §5 |
| Silent at day 180 → still eventually returned | 42.9% | `sql/08` §5 |
| Revenue held in one-and-done first orders | £618,836.25 | `sql/08` §6 |

**The true one-and-done rate is ~18%, not 34%.** **The second purchase takes
2.6× longer than every purchase after it.** **There is no cliff** — the decay is
smooth; the crossover to "more likely gone than returning" is around day 150.

## 6. Q4 — Cohort retention

*All corrected basis.*

| Number | Value | Source |
|---|---:|---|
| Dec 2010 cohort size | 884 (20.4% of base) — **excluded, see below** | `sql/09` §1 |
| Of which appearing in first 8 trading days | **573** | `sql/09` §1 |
| Normal monthly cohort size | 169–450 | `sql/09` §1 |
| 90-day repeat rate, genuine cohorts | **33.6% – 46.7%** | `sql/09` §3 |
| Lowest (May 2011) | 33.6% | `sql/09` §3 |
| Highest (Jan 2011) | 46.7% | `sql/09` §3 |
| Nov 2011 vs Feb 2011 order volume | 2,643 vs 992 — **2.7×** | `sql/09` §4 |

**Verdict: no reliable trend.** The December 2010 "cohort" is a left-truncation
artifact — the data begins that month, so every pre-existing customer is recorded
as new. Among genuine cohorts the variation is modest and tracks the trading
calendar rather than customer quality.

## 7. Q5 — Customer value

*All corrected basis. Observed revenue over 12 months — not a CLV model.*

| Number | Value | Source |
|---|---:|---|
| **Mean spend per customer** | **£1,956.44** | `sql/10` §1 |
| **Median spend per customer** | **£664.26** | `sql/10` §1 |
| 25th / 75th / 90th percentile | £305.58 / £1,634.72 / £3,572.72 | `sql/10` §1 |
| Mean excluding top 10 customers | £1,642.50 (−16%) | `sql/10` §2 |
| Median excluding top 10 customers | £662.59 (−0.3%) | `sql/10` §2 |
| One-time buyers | 1,545 (35.7%) — **7.3% of revenue** | `sql/10` §3 |
| Repeat buyers | 2,782 (64.3%) — **92.7% of revenue** | `sql/10` §3 |
| Median spend, one-time | £257.70 | `sql/10` §3 |
| Median spend, repeat | £1,163.34 | `sql/10` §3 |
| Repeat buyer worth vs one-time | 7.0× on mean, **4.5× on median** | `sql/10` §3 |

### The value ladder

| Band | Customers | % of revenue | Median spend | **Value per purchase** |
|---|---:|---:|---:|---:|
| 1 purchase | 1,545 | 7.3% | £257.70 | **£400.54** |
| 2 purchases | 878 | 8.0% | £584.89 | **£387.76** |
| 3–5 purchases | 1,115 | 19.5% | £1,125.07 | **£389.80** |
| 6–10 purchases | 510 | 18.4% | £2,428.18 | **£417.53** |
| 11+ purchases | 279 (6.4%) | **46.7%** | £6,135.38 | **£667.46** |

*Source: `sql/10_customer_value.sql` §4*

**Value per purchase is flat at £388–418 from the first purchase to the tenth.**
Customer value is built from frequency, not basket size. **279 customers (6.4%)
produce 46.7% of revenue.**

## 8. Q6 — Stayers vs leavers — CORRELATION ONLY

*All corrected basis. None of this establishes causation.*

### Never returned vs returned (90-day fair window)

| Group | Customers | Median first order | Median items |
|---|---:|---:|---:|
| Never returned | 879 | £236.26 | 126 |
| Returned at least once | 2,485 | £306.40 | 162 |

*Source: `sql/11` §2.* Returners' first orders are ~30% larger.

### Active vs lapsed (3+ purchases)

| Group | Customers | Median first order | Median items | Median days to 2nd | Mean total spend |
|---|---:|---:|---:|---:|---:|
| Active | 1,685 | £318.06 | 174 | 50 | £3,999.13 |
| Lapsed | 219 | £277.60 | 135 | 30 | £1,950.99 |

*Source: `sql/11` §3.* Control check passes: both groups observed 283 vs 287 days
on average (`sql/11` §4).

### How weak the signal is — first-order value spread

| Group | p10 | p25 | p50 | p75 | p90 |
|---|---:|---:|---:|---:|---:|
| Active | £125 | £201 | £318 | £505 | £873 |
| Lapsed | £97 | £148 | £278 | £490 | £853 |

*Source: `sql/11` §5.* **p75 and p90 are nearly identical.** First-order value
separates the groups only at the bottom of the range and **cannot be used to
score an individual customer**.

### The artifact caught and corrected

Lapsed customers appear to reach their second purchase **faster** (30 vs 50 days).
This is an artifact of the at-risk rule, not behaviour: a fast-cadence customer
trips a 2×-median threshold after a shorter absence, so the lapsed group is
loaded with naturally fast buyers (median of their median gaps: 34 days vs 48).

Compared within cadence bands, the effect collapses:

| Cadence band | Active | Lapsed |
|---|---:|---:|
| Fast (under 20d) | 15 days *(n=247)* | 10 days *(n=60)* |
| Medium (20–40d) | 31 days *(n=434)* | 29 days *(n=71)* |
| Slow (40–70d) | 56 days *(n=491)* | 46 days *(n=75)* |
| Very slow (70d+) | 104 days *(n=513)* | 91 days *(n=13)* |

*Source: `sql/11` §6.* **Time to second order does not meaningfully separate
stayers from leavers** once cadence is controlled for.

---

# Limitations that remain

Ordered by how much they constrain the conclusions.

## 1. A quarter of the business is invisible

**135,080 rows (24.93%) carry no customer ID** and are excluded from every
customer-level figure here. Every customer count, concentration measure,
retention rate and value figure describes only the ~75% of transactions that can
be attributed to somebody. The unattributed quarter may be more concentrated or
less, more loyal or less — there is no way to tell from this data. This is the
single largest caveat and it affects every number in this document.

## 2. Everything is right-censored — nobody is confirmed to have left

The data stops on **2011-12-09**. No customer's silence is complete. "At risk"
and "lapsed" throughout mean *overdue as of the last day of data*, never
*departed*. Of the 1,916 customers with enough history to score, **1,422
(£6,026,271) are simply not due back yet** — the method says nothing about them
either way.

This also means **the one-and-done rate depends entirely on how long you watch**
(35.7% naive → 17.9% at 270 days), and **twelve-month retention is not answerable
at all** — the only cohort observable for twelve months is the one excluded as an
artifact.

## 3. One year means one Christmas

Every seasonal claim rests on a single observation of the peak. November 2011 did
2.7× February's order volume, but nothing here shows that is the normal shape of
the year. Cohort comparisons are confounded with season: a customer acquired in
October is buying into Christmas and has an obvious reason to return quickly.

## 4. December 2010 is not a cohort

The data begins 2010-12-01, so every customer already trading that day is recorded
as new — 573 of its 884 customers appear in the first eight trading days. It is an
opening balance of the existing customer base. It must be excluded from any trend
claim, and its flattering 57.8% retention must never be quoted.

## 5. The at-risk rule is a business rule, not a model

The 2× multiple was chosen empirically (only 11.6% of real gaps exceed it) and
tuned to cost asymmetry, not fitted or validated. It has never been tested against
customers who actually churned, because no such labels exist in one year of data.
It identifies customers behaving unlike themselves. It does not predict churn and
should not be described as doing so.

The 30-day floor is a judgement call. It suppresses 11 customers holding £67,972.

## 6. Cadence needs history most customers do not have

**2,423 of 4,327 customers (56%) cannot be scored** — 1,545 bought once (no gaps)
and 878 bought twice (one gap, and the median of one number is that number).
Together they hold **£1,299,739.88**. They are reported separately rather than forced
through logic their data cannot support, but that means the majority of the
customer base sits outside the at-risk analysis entirely.

Even scored customers may be thin: three purchases gives two gaps, and the median
of two numbers is their average.

## 7. Q6 is correlation and nothing more

First-order value and item count are associated with staying. Nothing here shows
that engineering a bigger first order would cause anyone to stay. The likeliest
explanation runs the other way — committed buyers place bigger first orders
because of who they already are. Separating those requires an experiment with a
holdout group, which this data cannot provide.

No significance testing was performed. The lapsed group is 219 customers and its
slowest-cadence band contains 13 — that row should not be defended.

## 8. The reversal fix is a matching rule, not ground truth

Reversed sales are identified by matching customer + product + unit price + exact
quantity, with the cancellation dated on or after the sale. The source data has no
field linking a cancellation to the order it reverses. **Partial cancellations and
price-adjusted returns are not caught**, so £445,874.74 is a floor on the
overstatement, not a complete figure. Conversely, a customer who genuinely bought
the same item twice at the same price and cancelled once could be over-corrected.

The overstatement is therefore bracketed, not pinned:

| Measure | Value | What it is |
|---|---:|---|
| Upper bound | £611,342.09 | All cancellations carrying a customer ID |
| **Measured fix** | **£445,874.74** | Sale lines positively matched to a specific reversal |
| Unmatched | £207,858.81 (6,088 lines) | No exact match — partial and price-adjusted returns |

**True net sales for identified customers is between £8,300,066 and £8,465,533.**
`vw_valid_sales_net` takes the conservative end. The README's earlier estimate of
£611,342 is the upper bound and reconciles exactly — it is the same quantity
measured a different way, not a contradiction.

## 9. Known issues inherited from the original build

- **£0.00 unit prices and non-positive quantities** are excluded as non-sales.
  UCI associates them with free samples and write-offs, but this is inference from
  documentation, not confirmation from the business.
- **Cancellation rate is reported two ways** — 17.15% in the dashboard
  (invoice-based) and 14.8% elsewhere. See `DATA_QUALITY_FINDINGS.md`.
- **Country is recorded per transaction, not per customer.** Customers appearing
  under more than one country are assigned their most recent.
- **`customer_id` is stored as float-formatted text** (`15749.0`). Harmless for
  grouping, but it is not a clean key.

## 10. This is one retailer, one year, one dataset

A UK-based online gift retailer selling substantially to wholesale accounts.
Nothing here generalises to another business, and the top of the value ladder
(279 customers at £667 per purchase) almost certainly behaves like trade
customers rather than consumers — a distinction the data does not label.
