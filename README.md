# UK Online Retail: Sales and Customer Retention Dashboard

A three-page Power BI dashboard built from **541,909 UK retail transactions**. I used PostgreSQL and SQL to clean and analyse the data, then built the dashboard in Power BI to look at sales, customers, retention, cancellations and product demand.

One of the main findings was that **195 high-value repeat customers had not purchased for more than 90 days**, representing **£471,684.33 in historical customer value**.

## What I found

| Priority | Finding                               |                                  Number | Possible action                                                                     |
| -------- | ------------------------------------- | --------------------------------------: | ----------------------------------------------------------------------------------- |
| 1        | High-value customers have gone quiet  |         **195 customers / £471,684.33** | Target them with personalised re-engagement                                         |
| 2        | Almost half of "cancellations" are not returns |                **£411k of £896,812.49** | Finance to code fees separately, so the returns figure reflects actual returns      |
| 3        | Many customers only purchased once    |               **1,493 customers / 34%** | Test an incentive to encourage a second purchase  rather than acquiring new customers with more marketing spend                                   |
| 4        | Sales are strongly seasonal           | **2.6× difference** between Feb and Nov | Plan stock and staffing around the Q4 increase                                      |
| 5        | International sales are concentrated  |    **£551k from 12 customers** in NL and EIRE | Protect NL and EIRE as key accounts; grow DE and FR as markets                      |

I ranked these based on a simple effort-versus-impact judgement rather than just choosing the biggest number.

The high-value customer list is the quickest opportunity because the customers can already be identified from the data. Cancellations matter for a different reason: the reported figure is measuring two different things at once, so the first job there is correcting the number rather than acting on it.

Some of the figures in this README differ from the ones shown in the dashboard screenshots. That is deliberate. I found several issues after the report was built and chose to document them rather than quietly restate the numbers — see [Known issues found after the dashboard was built](#known-issues-found-after-the-dashboard-was-built).

---

## 1. 195 high-value customers have gone quiet

I identified **195 customers** who:

* had placed at least two orders
* had spent at least £1,000 historically
* had not placed an order for more than 90 days

Together, these customers had generated **£471,684.33** in historical sales.

The two largest examples were:

* Customer `15749.0` — **£44,534.30** lifetime spend, 235 days since last order
* Customer `15098.0` — **£39,916.50** lifetime spend, 182 days since last order

### Why this matters

These are not one-time shoppers. They had already bought repeatedly and spent significant amounts, so losing them could matter much more than losing a customer who only made one small purchase.

### Example of the possible value

If 20% of the 195 customers returned and spent their historical average again (**£2,418.89 per customer**), that would be around **£94,337** in recovered sales.

This is only an example to show the size of the opportunity. It is **not a forecast**.

### What I would do

**This changes where the retention budget goes.** Instead of spreading it across all 4,338 customers or sending one promotion to everyone, it concentrates on the **4.5% of the customer base that holds £471,684.33 of already-proven spend.**

The scale is easier to judge as a comparison. At the average first order value of £412.80, recovering these 195 customers is worth roughly **1,143 brand-new customers** — and it is a call list one account manager can work through in a fortnight, not a campaign that has to be built first.

I would work the list top-down by lifetime value, with a personalised message or offer rather than the same promotion to everyone.

### How I would measure it

Track:

* percentage of customers contacted
* percentage who make another purchase
* revenue generated within 30 days

---

## 2. Almost half of the £896,812.49 in "cancellations" are not customer returns

There were **3,836 cancelled invoices** worth **£896,812.49** in total. But **£410,747.67 of that — 45.8% — is not a customer returning anything.**

The largest item in the cancelled-product chart is **"AMAZON FEE"**, with **£235,281.59 across 32 invoices**. It is a marketplace fee adjustment, not a return. The same is true of other entries:

* Manual — £146,784.46
* CRUK Commission
* Bank Charges

All of these are recorded using the same cancellation-style invoice structure as genuine cancelled orders, which is why they appear on a chart about customer returns.

### The December spike is a keying error, not a business event

My first reading of this data was that December 2011 was the problem, because cancelled value reached **£205,124.67** — more than double any other month. That reading was wrong, and checking it changed the recommendation.

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

Someone entered an order more than six times larger than any legitimate order in the dataset and corrected it the same morning. There is no seasonal cancellation problem in December, and no saving available from "bringing it under control".

### Why this matters

If the business plans around the reported £896,812.49, it is sizing a returns problem at roughly twice its actual scale, and pointing effort at a December that does not need investigating.

The genuine returns figure is closer to **£486,065**.

### What I would do

**Finance, and whoever owns the invoicing system:** code marketplace fees and manual adjustments to their own ledger line rather than to cancellation-style invoice numbers. This is a data-entry standard, not an analysis task, and it stops the returns figure measuring two unrelated things.

**Operations:** add a validation rule at order entry so a quantity far outside normal range is challenged before it is saved. The 80,995-unit entry distorted three separate charts and a third of one month's revenue before anyone noticed.

### How I would measure it

Fees appearing on a separate ledger line within one reporting cycle, and a returns figure that Finance recognises as matching their own records.

---

## 3. 34% of customers only purchased once

The customer analysis found **1,493 one-time customers**, which is around **34% of customers** in the customer-level dataset.

Average spend by customer segment was:

| Customer segment            | Average spend |
| --------------------------- | ------------: |
| One-time customers          |       £412.80 |
| Active repeat customers     |       £582.45 |
| High-value active customers |     £5,093.19 |

### Why this matters

These customers have already made a first purchase. The business has therefore already managed to convert them once, but they did not return.

That makes a second-purchase campaign worth testing.

### Example of the possible value

If 10% of the 1,493 customers made another purchase and reached the **£582.45 average spend of an active repeat customer**, that would represent roughly **£25,329** in additional sales.

Again, this is an illustration of the potential size of the opportunity rather than a prediction.

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

## 5. International sales are concentrated in a small number of markets

The **Netherlands, EIRE, Germany and France** account for most of the international sales in this dataset. But grouping them together hides the more important point, which is that they are two completely different situations:

| Country | Net sales | Customers | Sales per customer |
| --- | ---: | ---: | ---: |
| Netherlands | £285,446.34 | **9** | £31,716 |
| EIRE | £265,545.90 | **3** | £88,515 |
| Germany | £228,867.14 | 94 | £2,435 |
| France | £209,024.05 | 87 | £2,403 |

### Why this matters

The Netherlands and EIRE are not really markets. **£550,992 of international revenue rests on twelve customers**, and three of those account for the whole of Ireland. Losing one Irish customer would remove roughly a third of Irish revenue.

Germany and France look like genuine markets. Around 90 customers each, at an average value per customer roughly in line with a normal repeat buyer, means the demand is spread rather than resting on a handful of accounts.

Treating all four the same way would be a mistake, because concentrated revenue needs protecting and distributed revenue needs growing.

### Example of the possible value

If the Netherlands increased from 9 customers to around 14 customers and those new customers spent a similar amount on average, the additional sales could be around **£142,723**.

This is only an illustration. Customer acquisition would not necessarily scale in exactly this way, and with only nine existing customers the average is not a reliable basis for forecasting.

### What I would do

**Split the four countries into two different jobs.**

The Netherlands and EIRE go to account management. Name the twelve customers, give each a named owner, and treat them the way the business would treat any concentrated account risk. The immediate goal is retention, not growth.

Germany and France take the international acquisition budget, because there is evidence there of a market that can be bought into repeatedly rather than a few relationships that happen to be large.

### How I would measure it

Track:

* number of customers by country
* sales by country
* customer acquisition cost
* sales generated from new customers

---

# Dashboard Screenshots

### 1. Sales Performance Overview

![Sales performance overview](outputs/figures/page1_sales_overview.jpg)

### 2. Customer Retention and Value

![Customer retention and value](outputs/figures/page2_customer_retention.jpg)

### 3. Cancellations and Product Demand

![Cancellations and product demand](outputs/figures/page3_cancellations_products.jpg)

---

# Tech Stack

| Tool                | What I used it for                                          |
| ------------------- | ----------------------------------------------------------- |
| **PostgreSQL**      | Storing the raw transaction data and creating cleaned views |
| **SQL**             | Data cleaning, quality checks and analysis                  |
| **Python (pandas)** | Converting the original Excel file to CSV                   |
| **Power BI**        | Building the three-page dashboard                           |
| **Power Query**     | Connecting Power BI to PostgreSQL and preparing columns     |
| **DAX**             | Creating the measures used by the dashboard                 |

---

# Methodology

## Business problem

I built this project as if I were analysing data for a **UK online gift retailer**.

The aim was to answer practical questions about sales and customers rather than just build a dashboard for the sake of visualisation.

The main questions were:

* How are sales and orders changing over time?
* Which products and countries generate the most sales?
* Which customers are the most valuable?
* Which valuable customers have stopped purchasing?
* How large are cancellations and how do they change over time?

The dataset contains sales information but **does not contain costs**, so this project focuses on sales, revenue, customers, orders and cancellations rather than profit or margin.

---

## Dataset

I used the **UCI Online Retail dataset**.

It contains transaction-level data from a UK-based online retailer covering **1 December 2010 to 9 December 2011**.

The original dataset contains **541,909 rows**.

Each row represents a product line on an invoice and includes fields such as:

* Invoice number
* Stock code
* Product description
* Quantity
* Invoice date
* Unit price
* Customer ID
* Country

### Source

Chen, D. (2015). *Online Retail* [Dataset]. UCI Machine Learning Repository.

[https://doi.org/10.24432/C5BW33](https://doi.org/10.24432/C5BW33)

Licensed under **CC BY 4.0**.

---

# Data Preparation

I kept the original table unchanged and used SQL views for the cleaning steps. This makes it easier to see what was changed and allows the raw data to be preserved.

The main checks and cleaning steps were:

### Cancelled invoices

I excluded invoices beginning with `C` from the sales analysis.

There were **3,836 cancellation invoices**, with a total value of **£896,812.49**.

I kept them separately so cancellations could be analysed rather than simply removing them and hiding the issue.

### Non-positive quantities and prices

I removed rows with:

* non-positive quantities: **10,624**
* non-positive prices: **2,521**

These rows mainly represented things such as adjustments, write-offs and free samples rather than normal sales.

### Missing customer IDs

There were **135,080 rows without a Customer ID**, which is almost 25% of the original data.

Because these transactions cannot be linked to a specific customer, I excluded them from customer-level analysis.

This means the customer figures in this project represent the transactions that **can be linked to a customer**, rather than the entire dataset.

### Sales value

Sales value was calculated as:

```sql
quantity * unit_price
```

### At-risk customers

I defined an at-risk customer as someone who:

* had placed at least 2 orders
* had spent at least £1,000
* had not ordered for more than 90 days

The 90-day period was measured from the **last transaction date in the dataset**, rather than from today's date.

This is important because the dataset is from 2010–2011. Comparing it with today's date would incorrectly make every customer look inactive.

More detail on the data quality checks is available in [DATA_QUALITY_FINDINGS.md](DATA_QUALITY_FINDINGS.md).

---

# Project Structure

```text
retail-sales-performance-dashboard/
├── data/
│   └── raw Excel file + converted CSV (not tracked in git)
├── src/
│   └── Excel → CSV conversion script
├── sql/
│   └── SQL scripts for cleaning and analysis
├── outputs/
│   ├── figures/
│   │   └── dashboard screenshots
│   └── query_results/
│       └── CSV exports of analysis queries
├── powerbi/
│   └── DAX measures reference
├── DATA_QUALITY_FINDINGS.md
├── POWERBI_BUILD_GUIDE.md
├── requirements.txt
├── .gitignore
└── README.md
```

There is no `notebooks/` folder because I did not use a Jupyter notebook for the analysis.

The main analysis is in the `sql/` folder, while the `powerbi/` folder contains the DAX measures used in the dashboard.

---

# How to Run

## 1. Download the dataset

Download `Online Retail.xlsx` from the [UCI repository](https://archive.ics.uci.edu/dataset/352/online+retail) and place it in the `data/` folder.

See `data/README.md` for the expected file location.

## 2. Convert Excel to CSV

```bash
pip install -r requirements.txt
python src/01_excel_to_csv.py
```

## 3. Create the PostgreSQL database

```bash
createdb online_retail_db
psql -d online_retail_db -f sql/01_create_table.sql
```

## 4. Run the SQL scripts

Run them in this order:

```bash
psql -d online_retail_db -f sql/02_data_quality_checks.sql
psql -d online_retail_db -f sql/03_clean_views.sql
psql -d online_retail_db -f sql/04_sales_analysis.sql
psql -d online_retail_db -f sql/05_customer_analysis.sql
```

The data quality results are documented in `DATA_QUALITY_FINDINGS.md`.

The `outputs/query_results/` folder contains CSV exports of the analysis queries that I used to check the Power BI results.

## 5. Open the Power BI report

Open Power BI Desktop and follow `POWERBI_BUILD_GUIDE.md`.

The guide covers:

* connecting Power BI to PostgreSQL
* creating the date table
* creating the DAX measures
* building each report page

The DAX measures are also listed separately in:

```text
powerbi/dax_measures.txt
```

---

# Known issues found after the dashboard was built

Reviewing this project after building it, I found three problems in my own numbers. I have left the dashboard as it was built and documented the issues here, rather than quietly restating the figures, so that the screenshots and the write-up can still be checked against each other.

### The cancellation rate of 17.15% is overstated

The dashboard calculates it as cancelled invoices ÷ (cancelled invoices + valid orders), which is **3,836 ÷ (3,836 + 18,532)**.

Those two numbers come from different places. The 3,836 cancellations are counted from the raw table, but the 18,532 orders are counted from the cleaned view, after rows with no customer ID and other invalid rows have been removed. The denominator is therefore smaller than the numerator's population, which pushes the rate up.

Counted consistently from the raw table — 3,836 cancelled invoices out of 25,900 total invoices — the rate is **14.81%**.

### "Net Sales" is not net of returns

`Net Sales` is `SUM(quantity × unit_price)` over `vw_valid_sales`. That view **excludes** cancellation lines, but excluding them is not the same as subtracting them.

A cancellation is recorded as a separate invoice beginning with `C`. The original positive sale line stays in the data under its own invoice number and passes every cleaning filter. So an order that was placed and then cancelled is still counted as revenue, and the cancellation that reversed it is simply not counted at all.

The clearest example is order `581483`: 80,995 units, **£168,469.60**, cancelled twelve minutes later, and still sitting in the sales total today.

Properly netting off the cancellations that can be attributed to a customer would reduce the figure by about **£611,342**, from £8,911,407.90 to roughly **£8,300,066**. A strictly accurate name for the measure as built would be *gross sales, excluding cancellation lines, identified customers only*.

### The sales figures exclude rows they did not need to

`vw_valid_sales` requires a customer ID. That is correct for the customer and retention pages, because you cannot group by an ID that is not there — but it is wrong for the sales pages, where those rows still carry a valid date, product, quantity and price.

The 135,080 rows without a customer ID are worth **£1,755,277**. Including them, total sales are **£10,666,684.54** rather than £8,911,407.90.

The two errors above work in opposite directions and partly cancel out, which is worse than either on its own — it means the headline total looks plausible while resting on two separate mistakes.

**The fix for all three** is to split the cleaning into two views: a sales view with no customer-ID requirement, and a customer view that keeps it. The cancellation rate would then be calculated from a single consistent population. I have described the fix rather than applied it, because rebuilding the report would invalidate the screenshots in this README.

---

# Limitations

There are several important limitations to this project.

### No profit data

The dataset contains sales and unit prices but no costs, so I cannot calculate profit or margin.

### Limited customer information

There are no customer names, demographics or marketing channels. Customers are identified only by `CustomerID`.

### The at-risk definition is rule-based

The at-risk customer list uses a fixed rule:

> 2+ orders + £1,000+ historical spend + 90+ days since last order

This is useful for identifying a group to investigate, but it is **not a predictive churn model**.

One limitation of this rule is that a customer who made only one very large purchase can still be classified as a one-time customer.

### Missing Customer IDs

Around a quarter of the original rows do not contain a Customer ID.

This means customer-level results only describe the transactions that can be attributed to a known customer. That restriction is unavoidable for the customer and retention analysis, but it should not have been applied to the sales totals as well — see [Known issues found after the dashboard was built](#known-issues-found-after-the-dashboard-was-built).

### Old dataset

The data covers **2010–2011**, so the seasonal patterns and country mix may not represent today's retail market.

---

# Future Work

There are three main improvements I would make next.

### 1. Improve the cancellation analysis

Separate genuine customer cancellations from fee adjustments and other accounting entries at the source.

### 2. Build a churn model

Replace the simple 90-day rule with a model that estimates the probability of a customer returning or becoming inactive.

### 3. Add cost data

If cost or margin data were available, the dashboard could move from measuring revenue to analysing **profitability and customer value**.

---

# What I Learned

This project helped me practise working through a data project from the raw dataset to a finished dashboard.

The main things I worked on were:

* cleaning a large transaction dataset using SQL
* writing CTEs and window functions
* checking data quality before analysing it
* building customer-level metrics
* connecting PostgreSQL to Power BI
* creating DAX measures
* turning analysis into business recommendations
* being careful about what the data can and cannot actually tell us

One of the biggest lessons was that **getting the numbers right comes before building the dashboard**. For example, finding that "AMAZON FEE" was included in the cancellation data changed how I interpreted the cancellation results.

---

# Contact

**La Yaung Linn Lett**

[GitHub](https://github.com/layaung-linnlett) · [LinkedIn](https://www.linkedin.com/in/layaung-linnlett/) · [layaunglinnlett1@gmail.com](mailto:layaunglinnlett1@gmail.com)
