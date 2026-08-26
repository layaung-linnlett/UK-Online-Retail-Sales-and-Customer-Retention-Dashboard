# The five findings, in full

This is the long-form version of the five findings summarised in
[the README](../README.md#key-findings). Each one gives the working, the
supporting tables, the illustrative sums, and the reasoning behind the
recommendation.

Every figure links to the CSV that produced it, in
[`../outputs/query_results/`](../outputs/query_results/).

**On which basis the numbers use:** unless a section says otherwise, figures
here are on the *published* basis (`vw_valid_sales`), so they reconcile with the
dashboard. The revised figures from the 2026 follow-up are on the *corrected*
basis and are labelled where they appear. The two bases are set out in
[analysis_summary.md](analysis_summary.md#read-this-first-two-bases-for-every-revenue-number).

---

## 1. 195 high-value customers have gone quiet

I identified **195 customers** who:

* had placed at least two orders
* had spent at least £1,000 historically
* had not placed an order for more than 90 days

Together, these customers had generated **£471,684.33** in historical sales.

The two largest examples were:

* Customer `15749` — **£44,534.30** lifetime spend, 235 days since last order
* Customer `15098` — **£39,916.50** lifetime spend, 182 days since last order

### Why this matters

These are not one-time shoppers. They had already bought repeatedly and spent significant amounts, so losing them could matter much more than losing a customer who only made one small purchase.

### Example of the possible value

If 20% of the 195 customers (39 customers) returned and spent their historical average again (**£2,418.89 per customer**), that would be around **£94,337** in recovered sales.

    39 x £2,418.89 = £94,337

This is only an example to show the size of the opportunity. It is **not a forecast**.

### What I would do

**This changes where the retention budget goes.** Instead of spreading it across all 4,338 customers or sending one promotion to everyone, it concentrates on the **4.5% of the customer base that holds £471,684.33 of already-proven spend.**

These 195 are **4.5% of the customer base** and account for **5.3% of net sales**. That is spend the business has already paid to acquire once.

I am not going to put a return figure on a win-back campaign. That needs the win-back rate and the cost of acquiring a customer, and neither is in this dataset. If a comparison is wanted: £471,684.33 is roughly what **230 average customers** are worth across their whole time with the business, since mean spend per customer is £2,054.27.

> **An earlier version of this README said 1,143 customers.** That divided these customers' *lifetime* spend by £412.80 and called it the average first order value. Two things were wrong with it. £412.80 is the average *total* spend of a one-time customer, not a first order value — the actual average first order is £400.54. And dividing a lifetime figure by a single transaction inflates the comparison, because a new customer goes on to have a lifetime too. Compared like for like it is 230, not 1,143.

I would work the list top-down by lifetime value, with a personalised message or offer rather than the same promotion to everyone.

### How I would measure it

Track:

* percentage of customers contacted
* percentage who make another purchase
* revenue generated within 30 days

---

## 2. Only a third of the £896,812.49 in "cancellations" is a customer returning anything

There were **3,836 cancelled invoices** worth **£896,812.49** in total. Splitting that total by what the line actually is:

| What it is | Lines | Value | Share |
| --- | ---: | ---: | ---: |
| Fees and accounting adjustments | 455 | £406,148.78 | 45.29% |
| Shipping and carriage refunds | 129 | £11,939.53 | 1.33% |
| The 80,995-unit keying error (invoice `C581484`) | 1 | £168,469.60 | 18.79% |
| **Merchandise returned by a customer** | **8,703** | **£310,254.58** | **34.60%** |

The fee and adjustment entries are recorded under stock codes that are not product codes:

| Stock code | Item | Value |
| --- | --- | ---: |
| `AMAZONFEE` | AMAZON FEE | £235,281.59 |
| `M` | Manual | £146,784.46 |
| `CRUK` | CRUK Commission | £7,933.43 |
| `BANK CHARGES` | Bank Charges | £7,340.64 |
| `D` | Discount | £5,696.22 |
| `S` | SAMPLES | £3,112.44 |

All of these use the same cancellation-style invoice structure as genuine cancelled orders, which is why they appear on a chart about customer returns.

*Query: `sql/04_sales_analysis.sql`, "What is actually inside the cancellation total?". Output: [`outputs/query_results/17_cancellation_composition.csv`](../outputs/query_results/17_cancellation_composition.csv) and [`18_cancellation_non_merchandise.csv`](../outputs/query_results/18_cancellation_non_merchandise.csv).*

### The December spike is a keying error, not a business event

My first reading of this data was that December 2011 was the problem, because cancelled value reached **£205,124.67** — more than four times the typical month, and 56% above the next highest. That reading was wrong, and checking it changed the recommendation.

Almost all of that month is three lines:

| Invoice | Item | Quantity | Value | Share of December |
| --- | --- | ---: | ---: | ---: |
| C581484 | PAPER CRAFT , LITTLE BIRDIE | −80,995 | £168,469.60 | 82.1% |
| C580605 | AMAZON FEE | −1 | £17,836.46 | 8.7% |
| C580604 | AMAZON FEE | −1 | £11,586.50 | 5.6% |

**96.5% of the December spike is one data-entry error plus two marketplace fees.**

The order it reversed was keyed twelve minutes earlier:

```
581483    80,995 units @ £2.08    2011-12-09 09:15
C581484  −80,995 units @ £2.08    2011-12-09 09:27
```

Someone entered an order more than five times larger than any legitimate order in the dataset — the largest genuine order all year was 15,049 units — and corrected it the same morning. There is no seasonal cancellation problem in December, and no saving available from "bringing it under control".

### Why this matters

If the business plans around the reported £896,812.49, it is sizing a returns problem at roughly **2.9× its actual scale**, and pointing effort at a December that does not need investigating.

The genuine merchandise returns figure is **£310,254.58**.

### What I would do

**Finance, and whoever owns the invoicing system:** code marketplace fees and manual adjustments to their own ledger line rather than to cancellation-style invoice numbers. This is a data-entry standard, not an analysis task, and it stops the returns figure measuring several unrelated things at once.

**Operations:** add a validation rule at order entry so a quantity far outside normal range is challenged before it is saved. The 80,995-unit entry distorted three separate charts and a third of one month's revenue before anyone noticed.

### How I would measure it

Fees appearing on a separate ledger line within one reporting cycle, and a returns figure that Finance recognises as matching their own records.

---

## 3. 34% of customers only purchased once

The customer analysis found **1,493 one-time customers**, which is around **34% of customers** in the customer-level dataset.

All five customer segments, so the 1,493 can be seen in proportion:

| Customer segment       | Customers | Total sales | Average spend |
| ---------------------- | --------: | ----------: | ------------: |
| High-value active      |     1,399 | £7,125,379.57 |     £5,093.19 |
| One-time customer      |     1,493 |   £616,311.73 |       £412.80 |
| Active repeat customer |       844 |   £491,584.69 |       £582.45 |
| High-value at risk     |       195 |   £471,684.33 |     £2,418.89 |
| At-risk repeat customer |      407 |   £206,447.58 |       £507.24 |
| **Total**              | **4,338** | **£8,911,407.90** | |

*Source: [`outputs/query_results/13_customer_segment_summary.csv`](../outputs/query_results/13_customer_segment_summary.csv)*

One-time customers are 34% of the customer base but only 6.9% of sales.

### Why this matters

These customers have already made a first purchase. The business has therefore already managed to convert them once, but they did not return.

That makes a second-purchase campaign worth testing.

### Example of the possible value

If 10% of the 1,493 one-time customers (149 customers) came back and spent again, that would be roughly **£86,960** in additional sales.

    149 x £582.45 average repeat-customer spend = £86,960

Measured as the *increase* over what a one-time customer already spends, rather than as new revenue, it is smaller:

    149 x (£582.45 - £412.80) = £25,329

The first figure is the sales the campaign would generate; the second is what it adds per customer over the status quo. Both are illustrations of the size of the opportunity rather than predictions.

### What I would do

Test a targeted second-purchase incentive shortly after the customer's first order.

For example, the business could test a limited-time discount or another offer designed specifically to encourage a second purchase.

### How I would measure it

Compare the percentage of first-time customers making a second purchase within 60 days before and after the campaign.

---

## 4. Sales are strongly seasonal

Monthly net sales increased from a low of **£447,137.35 in February** to a high of **£1,161,817.38 in November**.

That is around a **2.6× difference** between the low and high months.

November also increased by **11.79% compared with October**.

### Why this matters

The business appears to have a strong pre-Christmas sales period.

**December looks like a collapse and is not one.** Two things make it look worse than it was. The dataset ends on **9 December 2011**, so December is only a partial month. And £168,469.60 of the £518,192.79 recorded is the phantom order described in finding 2 — an order that was cancelled twelve minutes after it was keyed, but which still counts as revenue because the cleaning rules exclude cancellation lines rather than subtracting them.

Adjusting for both:

| | Net sales | Days | Per day |
| --- | ---: | ---: | ---: |
| November | £1,161,817.38 | 30 | **£38,727** |
| December (excluding the phantom order) | £349,723.19 | 9 | **£38,858** |

**On a per-day basis, December was running at November's rate**, within a third of a percent. Anyone reading the December bar at face value would conclude demand fell off a cliff and plan the following year around a crash that never happened.

### What I would do

The business should plan for the increase earlier in the year by considering:

* stock levels
* staffing
* marketing activity
* operational capacity

The main goal is to make sure the business can handle the higher demand during the autumn and Christmas period.

### How I would measure it

For the following year, I would look at:

* stockout incidents during September–November
* staffing levels
* November sales growth
* whether demand was met without operational problems

---

## 5. Two of the four "international markets" are single accounts

The **Netherlands, EIRE, Germany and France** account for most of the international sales in this dataset. Grouping them together hides that they are two completely different situations:

| Country | Net sales | Customers | Sales per customer |
| --- | ---: | ---: | ---: |
| Netherlands | £285,446.34 | **9** | £31,716 |
| EIRE | £265,545.90 | **3** | £88,515 |
| Germany | £228,867.14 | 94 | £2,435 |
| France | £209,024.05 | 87 | £2,403 |

*Source: [`06_sales_by_country.csv`](../outputs/query_results/06_sales_by_country.csv). Published basis.*

### The two averages in that table describe nobody

The right-hand column is where I originally stopped, and stopping there was wrong. £31,716 per Dutch customer and £88,515 per Irish customer are arithmetic means over a handful of customers, and in both countries a single account dominates the total.

From [`33_top_10_customers_corrected.csv`](../outputs/query_results/33_top_10_customers_corrected.csv), three of the ten largest customers in the whole business are in these two countries:

| Rank | Customer | Country | Lifetime spend | Orders |
| ---: | --- | --- | ---: | ---: |
| 1 | `14646` | Netherlands | £278,953.22 | 73 |
| 4 | `14911` | EIRE | £131,839.01 | 197 |
| 6 | `14156` | EIRE | £114,395.83 | 55 |

Setting those against the country totals:

| | Country total | Largest accounts | Share | What is left for the rest |
| --- | ---: | ---: | ---: | --- |
| Netherlands | £285,446.34 | £278,953.22 (1 customer) | **≥ 97.7%** | ≤ £6,493 across 8 customers, about £810 each |
| EIRE | £265,545.90 | £246,234.84 (2 customers) | **≥ 92.7%** | ≤ £19,311 for the remaining customer |

**These are lower bounds, not point estimates.** The country totals come from `vw_valid_sales` (published basis) and the customer figures from `vw_valid_sales_net` (corrected basis). Correcting only ever removes revenue from a customer, never adds it, so each customer's published spend is at least their corrected spend and the true concentration is at least what the table shows. A same-basis figure would need a country breakdown of `vw_valid_sales_net`, which this project does not currently export.

### Why this matters

**The Netherlands is not a market of nine customers. It is one customer worth £278,953 and eight worth about £810 each.** Ireland is two large accounts and one much smaller one.

That changes what the number means. £550,992 of international revenue does not rest on twelve customers in any meaningful sense — it rests on three, with nine more attached. Losing customer `14646` would remove almost all Dutch revenue, not a ninth of it.

Germany and France are the genuine markets. Around 90 customers each at roughly £2,400 per customer means demand is spread across many buyers rather than resting on a few relationships, so acquisition there buys something repeatable.

### A correction to my own earlier version

An earlier version of this section said **"losing one Irish customer would remove roughly a third of Irish revenue"** and projected that adding five Dutch customers at the £31,716 average would be worth about **£158,581**.

Both were wrong, and wrong in the same way. They divided a country total by its customer count and treated the result as what a typical customer there is worth. No Irish customer is worth a third of Irish revenue: the largest is about half of it, the smallest about 7%. And there is no Dutch customer available to acquire at £31,716 — eight of the nine are worth about £810.

The whole point of this finding is that grouping hides concentration. The first version committed exactly that error one level further down. I have removed the projection rather than repairing it, because there is no defensible per-customer figure in either country to project from.

### What I would do

**Split the four countries into two different jobs.**

The Netherlands and EIRE are account management, not market development. Name the three customers that carry them, give each a named owner, and treat the position the way the business would treat any concentrated account risk. The immediate goal is retention, not growth. It is also worth establishing whether anyone in the business already knows how large these three accounts are relative to their countries.

Germany and France take the international acquisition budget, because there is evidence of a market that can be bought into repeatedly rather than a few relationships that happen to be large.

### How I would measure it

Track:

* revenue by country **and** the share held by the largest account in each
* number of customers by country
* customer acquisition cost, and sales generated from new customers, in Germany and France specifically

---
