# Power BI Build Guide

Everything up to this point (PostgreSQL, the five SQL scripts, the three views) is done and sitting in `online_retail_db`. Everything from here on has to happen by hand in Power BI Desktop — this is the click-by-click guide for that part. Follow it in order; don't skip to Page 1 before the data model (views, date table, relationships, measures) is in place, or you'll be rebuilding visuals later.

At the end of each page there's a **verify your numbers** checkpoint — a small table comparing what your visual should show against the actual numbers already sitting in `outputs/query_results/`. If your Power BI number doesn't match, the bug is almost always in the model (wrong relationship direction, filter left on a slicer, wrong aggregation on a field) rather than in the data.

---

## 1. Connect Power BI to PostgreSQL

1. Open Power BI Desktop. On the **Home** ribbon, click **Get Data**.
2. Search for **PostgreSQL database** and select it, then click **Connect**.
3. **Server:** `localhost` (or `localhost:5432` if it asks for a port explicitly). If Power BI Desktop is running on a different machine from PostgreSQL (e.g. Windows PC connecting to a Mac on the same WiFi), use that machine's local network IP address instead of `localhost`.
4. **Database:** `online_retail_db`.
5. Leave **Data Connectivity mode** on **Import** (not DirectQuery) — this is a one-off historical dataset, not a live feed, so Import gives you faster visuals with no downside.
6. Click **OK**.

**If you see an error asking for the Npgsql driver:** Power BI's PostgreSQL connector needs the Npgsql .NET data provider installed separately — it doesn't ship with Power BI Desktop. Click the link in the error dialog (or go to [https://www.npgsql.org/](https://www.npgsql.org/) and get the latest Npgsql installer for Windows), run the installer, then **fully close and reopen Power BI Desktop** before retrying Get Data. This is a one-time setup step.

7. Enter your PostgreSQL credentials when prompted (the username you connect to `online_retail_db` with locally; leave the password blank if your local instance uses trust/peer authentication, otherwise enter it). Select **Database** as the authentication level if asked, so the credential is remembered for this database specifically.

## 2. Load the three views

In the Navigator window that appears:

1. Tick these three objects only:
   - `vw_valid_sales`
   - `vw_cancellations`
   - `vw_customer_profile`
2. **Do not** tick `online_retail_raw` — it's the unfiltered raw table and has no place in the report; if you need to double-check something against it, query it directly in psql, not in Power BI.
3. Click **Transform Data** rather than Load, just so you can eyeball the preview of each view first (check that `sales_value`, `order_date`, `customer_segment` etc. all look right), then click **Close & Apply** on the Home ribbon of Power Query Editor.

Wait for the load to finish — with ~398K rows in `vw_valid_sales` this can take a minute or two.

## 3. Create the date table

A dedicated date table lets Power BI's time-intelligence features work properly and gives you clean Year/Month/Quarter fields to put on axes and slicers, instead of relying on the raw `order_date` column directly.

1. On the **Home** ribbon, find the **Calculations** group and click **New table**. (Older/other versions of Power BI Desktop put this under a separate **Modeling** ribbon tab instead — same button, different location.)
2. Paste in:

```
DateTable =
ADDCOLUMNS(
    CALENDAR(
        MIN(vw_valid_sales[order_date]),
        MAX(vw_valid_sales[order_date])
    ),
    "Year", YEAR([Date]),
    "Month Number", MONTH([Date]),
    "Month Name", FORMAT([Date], "MMMM"),
    "Year Month", FORMAT([Date], "YYYY-MM"),
    "Quarter", "Q" & FORMAT([Date], "Q")
)
```

3. Press Enter. A new `DateTable` should appear in the Fields pane on the right, spanning 2010-12-01 to 2011-12-09 (matches the dataset's date range — see `DATA_QUALITY_FINDINGS.md`).

## 4. Set the relationship

1. Go to the **Model** view (the icon on the left rail that looks like three connected boxes).
2. Drag from `DateTable[Date]` to `vw_valid_sales[order_date]` to create a relationship, or use **Manage relationships** > **New** and pick them from the dropdowns.
3. Make sure the relationship is **one-to-many** (DateTable is the "one" side, since each date appears once in DateTable but many times in vw_valid_sales) with a **single** cross-filter direction (DateTable filters vw_valid_sales, not the other way round). Power BI usually gets this right automatically — just confirm it in the relationship dialog before saving.

## 5. Mark DateTable as the official date table

1. Click on `DateTable` in the Fields pane to select it.
2. Go to **Table tools** on the ribbon (appears when the table is selected) and click **Mark as date table**.
3. In the dialog, pick `Date` as the date column, then **OK**. This tells Power BI's engine to treat this table specially for time intelligence and stops it complaining about ambiguous date handling.

## 6. Create the _Measures table

1. **Home** ribbon (Calculations group) > **New table** again.
2. Paste in:

```
_Measures = { "Measure holder" }
```

3. Note the leading underscore — Power BI reserves the exact name "Measures" internally for its own hidden system table, and will reject `Measures = { "Measure holder" }` with an error ("the name of the object 'Table' cannot be the reserved string 'Measures'") if you try to use it directly. `_Measures` avoids the clash and also sorts neatly to the top of the Fields list.
4. This creates an empty-looking table that exists purely to hold your DAX measures, so they're not scattered across `vw_valid_sales`, `vw_cancellations` and `vw_customer_profile` in the Fields pane. It's a Power BI/DAX convention, not a technical requirement — but it keeps a report with a dozen-plus measures navigable.

## 7. Add every measure

Open [powerbi/dax_measures.txt](powerbi/dax_measures.txt) — it has all twelve measures with the exact DAX and an explanation of what each one does and why it uses DIVIDE/CALCULATE/DISTINCTCOUNT.

For each measure:

1. Click on the `_Measures` table in the Fields pane to select it (this matters — it decides which table the new measure gets filed under).
2. **Home** ribbon (Calculations group) > **New measure**.
3. Delete the placeholder text in the formula bar and paste in the measure name and DAX from `dax_measures.txt` exactly (e.g. `Net Sales = SUM(vw_valid_sales[sales_value])`).
4. Press Enter.
5. Repeat for all twelve: Net Sales, Total Orders, Unique Customers, Average Order Value, Total Items Sold, Cancelled Value, Cancelled Invoices, Cancellation Rate, High-Value Active Customers, High-Value At-Risk Customers, At-Risk Repeat Customers, One-Time Customers.

**Formatting while you're in there:**
- Net Sales, Average Order Value, Cancelled Value: select the measure, go to the **Measure tools** ribbon, set **Format** to Currency, symbol £, 2 decimal places (or 0 for card visuals if you want cleaner KPI numbers).
- Cancellation Rate: set **Format** to Percentage, 2 decimal places (the DAX already produces a 0–1 fraction via DIVIDE, so Power BI's percentage format will display it correctly as e.g. 17.15%).
- Total Orders, Unique Customers, Total Items Sold, the four customer-segment counts: leave as **Whole number**.

---

## Page 1: Sales performance overview

1. Add a new page (bottom tab, `+`). Rename it "Sales Overview" (double-click the tab name).
2. Add a **Text box** at the top: title "UK Online Retail | Sales Performance Overview", subtitle "Transaction data: Dec 2010–Dec 2011".

**KPI cards** (Insert > Visual > Card, four separate cards across the top):

| Card | Field |
|---|---|
| 1 | `_Measures[Net Sales]` |
| 2 | `_Measures[Total Orders]` |
| 3 | `_Measures[Unique Customers]` |
| 4 | `_Measures[Average Order Value]` |

Drag the measure straight into the **Fields** well of each Card visual (there's only one well on a Card visual, labelled "Fields" or "Data").

**Monthly Net Sales Trend** — Line chart:
- **X-axis:** `DateTable[Year Month]`
- **Y-axis:** `_Measures[Net Sales]`
- This is the direct visual equivalent of the "Monthly sales trend" query in `sql/04_sales_analysis.sql`.

**Sales by Country** — Clustered bar chart (or Map, if you want to be more visual, but a bar chart matches the wireframe and is easier to read precisely):
- **Y-axis (categories):** `vw_valid_sales[country]`
- **X-axis (values):** `_Measures[Net Sales]`
- Sort descending by Net Sales (click the "..." on the visual > Sort by > Net Sales).

**Top 10 Products by Net Sales** — Clustered bar chart:
- **Y-axis:** `vw_valid_sales[product_name]`
- **X-axis:** `_Measures[Net Sales]`
- On the visual's **Filters** pane, add a **Top N** filter on `product_name`: Top 10 by `Net Sales`.

**Top International Countries** — Clustered bar chart:
- Same setup as "Sales by Country" but add a filter: `vw_valid_sales[country]` is not `United Kingdom`, plus a Top N filter (Top 10 by Net Sales).

**Product sales table** — Table visual (this is the "detailed verification" table from the plan's visual-choices list):
- Columns: `vw_valid_sales[product_name]`, then three measures — you'll need `Total Items Sold`, `Net Sales`, and `Total Orders` doesn't exist as a per-product breakdown by default, so instead add `vw_valid_sales[invoice_no]` set to **Count (distinct)** via the field well's dropdown, or just reuse `Total Orders` (it will correctly recalculate per product row because table visuals apply row-level filter context automatically).

**Slicers** — three separate Slicer visuals along the top or side of the page:
- Slicer 1: `DateTable[Date]` (Power BI will offer a between/range slicer for date fields — use that).
- Slicer 2: `vw_valid_sales[country]`
- Slicer 3: `vw_valid_sales[product_name]`

**Formatting tips:**
- Keep all four cards the same size and evenly spaced — use the **Align** and **Distribute** options (Format ribbon, with multiple visuals selected) rather than eyeballing it.
- Give the whole page one consistent accent colour for bars/lines rather than Power BI's default rainbow — Format pane > visual > Colors.
- Cap this page at four KPI cards and four to six visuals per the plan's own guidance — resist adding a fifth chart "just in case."

**Verify your numbers — Page 1:**

| Card/visual | Expected value | Source |
|---|---|---|
| Net Sales | £8,911,407.90 | `outputs/query_results/02_overall_kpis.csv` |
| Total Orders | 18,532 | same file |
| Unique Customers | 4,338 | same file |
| Average Order Value | £480.87 | same file |
| Top product by net sales | PAPER CRAFT , LITTLE BIRDIE (£168,469.60) | `outputs/query_results/05_top_10_products_by_net_sales.csv` — note this is a single bulk order, flagged in `DATA_QUALITY_FINDINGS.md` |
| Top country (excl. cards) | United Kingdom, £7,308,391.55 | `outputs/query_results/06_sales_by_country.csv` |
| Top international country | Netherlands, £285,446.34 | `outputs/query_results/07_top_10_countries_excl_uk.csv` |

If Net Sales doesn't match: check the DateTable relationship isn't accidentally filtering rows out (e.g. cross-filter direction set to Both), and make sure no slicer on the page is left partially selected from testing.

---

## Page 2: Customer retention and value

1. New page, rename "Customer Retention".
2. Text box title: "Customer Retention and Value".

**KPI cards** (four cards):

| Card | Field |
|---|---|
| 1 | `_Measures[High-Value Active Customers]` |
| 2 | `_Measures[High-Value At-Risk Customers]` |
| 3 | `_Measures[At-Risk Repeat Customers]` |
| 4 | `_Measures[One-Time Customers]` |

**Customer Count by Segment** — Clustered bar chart:
- **Axis:** `vw_customer_profile[customer_segment]`
- **Values:** count of rows — drag `vw_customer_profile[customer_id]` into the values well and set it to **Count (distinct)**, since this needs "how many customers" not "how many rows," even though they should be equal here (one row per customer in this view).

**Top 10 Customers by Spend** — Clustered bar chart:
- **Axis:** `vw_customer_profile[customer_id]`
- **Values:** `vw_customer_profile[total_spend]` (set aggregation to Sum, or just don't aggregate since it's already one row per customer)
- Add a Top N filter: Top 10 by total_spend.
- Because `customer_id` is really an ID, not a label anyone reads meaningfully, consider adding a card or tooltip note that this is anonymised — there's no customer name field in this dataset (see README limitations).

**High-Value At-Risk Customer Table** — Table visual (this is also the "Top 10 high-value at-risk customers" chart from the plan's chart list — one table serves both purposes if you sort it and optionally cap it with a Top N filter):
- Columns: `customer_id`, `total_spend`, `total_orders`, `last_order_date`, `days_since_last_order`
- **Filter:** `customer_segment` is `High-value at risk`
- Sort descending by `total_spend`.
- This table is the direct visual equivalent of the "Retention priority list" query in `sql/05_customer_analysis.sql` — it's meant to be a literal, actionable to-do list for the Sales Manager, not just a chart.

**Slicers:** reuse the Country and Date slicers from Page 1 if you want cross-page filtering consistency (Format pane > General > sync slicers via the **Sync slicers** pane, Ctrl+click the slicer, View ribbon > Sync slicers, tick the pages you want it synced to) — optional, but a nice touch that shows you understand report-level interactivity, not just single-page builds.

**Formatting tips:**
- Colour the four KPI cards to match their urgency: e.g. green-ish for High-Value Active, amber/red for High-Value At-Risk — this is a genuinely useful visual cue for a retention page, not just decoration.
- Format `total_spend` as Currency (£) in the table and bar chart.
- Format `days_since_last_order` as a plain whole number (it's a day count, not currency or a date).

**Verify your numbers — Page 2:**

| Card/visual | Expected value | Source |
|---|---|---|
| High-Value Active Customers | 1,399 | `outputs/query_results/13_customer_segment_summary.csv` |
| High-Value At-Risk Customers | 195 | same file |
| At-Risk Repeat Customers | 407 | same file |
| One-Time Customers | 1,493 | same file |
| Top customer by spend | Customer 14646.0, £280,206.02 | `outputs/query_results/15_top_20_customers_by_spend.csv` |
| Sum of all 5 segments | 1,399 + 1,493 + 844 + 195 + 407 = 4,338 | should equal Unique Customers from Page 1 |

If the four segment counts don't sum to 4,338 (the total unique-customer count from Page 1), something's filtering `vw_customer_profile` inconsistently with `vw_valid_sales` — check you haven't accidentally added a relationship from DateTable to `vw_customer_profile` (there shouldn't be one; the date table only relates to `vw_valid_sales`, since `vw_customer_profile` is already a one-row-per-customer summary, not a transaction-level table).

---

## Page 3: Cancellations and product demand

1. New page, rename "Cancellations".
2. Text box title: "Cancellations and Product Demand".

**KPI cards** (three cards this time, matching the plan's wireframe):

| Card | Field |
|---|---|
| 1 | `_Measures[Cancelled Invoices]` |
| 2 | `_Measures[Cancelled Value]` |
| 3 | `_Measures[Cancellation Rate]` |

**Cancelled Value by Month** — Line chart or Column chart:
- **X-axis:** you'll need a month field from `vw_cancellations[cancellation_month]` directly (this view isn't related to DateTable, so don't try to drag DateTable fields in here — it will just show blanks). Use `vw_cancellations[cancellation_month]` on the axis.
- **Y-axis:** `_Measures[Cancelled Value]`

**Top Cancelled Products** — Clustered bar chart:
- **Axis:** `vw_cancellations[product_name]`
- **Values:** `_Measures[Cancelled Value]`
- Top N filter: Top 10 by Cancelled Value.

**Top Products by Quantity** — Clustered bar chart:
- **Axis:** `vw_valid_sales[product_name]`
- **Values:** `vw_valid_sales[quantity]` set to Sum.
- Top N filter: Top 10 by sum of quantity.
- This is deliberately a different ranking from Page 1's "Top 10 Products by Net Sales" — a product can sell a huge volume of cheap units without being a top revenue earner (see the "PAPER CRAFT , LITTLE BIRDIE" outlier flagged in `DATA_QUALITY_FINDINGS.md`, which tops this chart but is much further down the net-sales ranking).

**Product Detail Table** — Table visual:
- Columns: `product_name`, sum of `quantity` (as Total Items), sum of `sales_value` (as Net Sales), distinct count of `invoice_no` (as Orders) — all from `vw_valid_sales`.
- This is the full product rollup, not Top-N limited — it's meant to be a browsable/searchable reference table, matching `outputs/query_results/12_full_product_sales_table.csv`.

**Formatting tips:**
- Because `vw_cancellations` and `vw_valid_sales` are two separate, unrelated tables in this model, a chart that tries to combine fields from both at once (e.g. cancellation value alongside net sales on the same axis) won't filter cleanly against each other — keep charts on this page single-sourced from one view or the other, which is exactly what the wireframe already does.
- Cancellation Rate on the KPI card should read as a percentage (17.15%), not a decimal (0.1715) — double check the measure's format property if it displays wrong.

**Verify your numbers — Page 3:**

| Card/visual | Expected value | Source |
|---|---|---|
| Cancelled Invoices | 3,836 | `outputs/query_results/08_cancellation_kpis.csv` |
| Cancelled Value | £896,812.49 | same file |
| Cancellation Rate | 17.15% | same file |
| Top cancelled product | check against | `outputs/query_results/10_most_cancelled_products.csv` |
| Top product by quantity | PAPER CRAFT , LITTLE BIRDIE, 80,995 units | `outputs/query_results/11_top_10_products_by_quantity.csv` |

---

## After all three pages are built

1. Save the file as `powerbi/Online_Retail_Dashboard.pbix` (this file is git-ignored per `.gitignore` — Power BI files are large binaries and don't belong in the repo history; the screenshots in `outputs/figures/` is what actually gets committed for the README).
2. Take a screenshot of each page and save them to `outputs/figures/` as `page1_sales_overview.jpg`, `page2_customer_retention.jpg` and `page3_cancellations_products.jpg` — these are the three the README embeds.
3. Once you've actually looked at the finished dashboard, write up the **Key Findings** section of `README.md` in the Finding / Evidence / Why it matters / Recommended action format, grounding every finding in a number you can point to on the dashboard or in `outputs/query_results/`. That section is now filled in, so treat this step as the process to repeat if the data is ever refreshed.
