# Power BI Build Guide

Click-by-click instructions for building the three-page dashboard from scratch. Written assuming you have never opened Power BI before.

**Everything before this point is already done.** The database `online_retail_db` exists, the SQL scripts have run, and the views are built. If that is not true yet, go back to [How to Run](README.md#how-to-run) in the README and finish it first — nothing here works without it.

---

## Contents

* [Part 0 — Before you start](#part-0--before-you-start)
* [Part 1 — Load the data](#part-1--load-the-data)
* [Part 2 — Build the model](#part-2--build-the-model)
* [Part 3 — Six techniques you will use on every page](#part-3--six-techniques-you-will-use-on-every-page) ← **read this before building any page**
* [Part 4 — Page 1: Sales Overview](#part-4--page-1-sales-overview)
* [Part 5 — Page 2: Customer Retention](#part-5--page-2-customer-retention)
* [Part 6 — Page 3: Cancellations](#part-6--page-3-cancellations)
* [Part 7 — Final check, save, screenshot](#part-7--final-check-save-screenshot)

---

# Part 0 — Before you start

## What you need

**Power BI Desktop is Windows-only.** There is no Mac version and there never has been. If you are on a Mac you need one of:

* a Windows PC or laptop
* Windows running in a virtual machine (Parallels, VMware, UTM)
* a cloud Windows desktop

Download Power BI Desktop free from the Microsoft Store, or from [powerbi.microsoft.com/desktop](https://powerbi.microsoft.com/desktop/). The Microsoft Store version updates itself, which is the easier option.

**If PostgreSQL is on your Mac and Power BI is on a Windows machine**, they must be on the same network, and you will use the Mac's local IP address instead of `localhost` in Part 1. Find it on the Mac with:

```bash
ipconfig getifaddr en0
```

You will also need PostgreSQL to accept connections from another machine, which is off by default. That is a `postgresql.conf` and `pg_hba.conf` change — if you would rather avoid it, the simplest alternative is to install PostgreSQL on the Windows machine too and load the CSV there.

## The five parts of the screen

Open Power BI Desktop. Learn these five names now, because every instruction below uses them.

| Name | Where it is | What it does |
|---|---|---|
| **Ribbon** | Strip of tabs across the top (Home, Insert, Modeling, View) | Buttons, like in Word or Excel |
| **Canvas** | The big white area in the middle | Where your charts go |
| **Data pane** | Far right | Lists every table and column you have loaded |
| **Visualizations pane** | Right, just left of the Data pane | Chart type icons on top, **wells** underneath |
| **Filters pane** | Right, left of Visualizations (may be collapsed — click to expand) | Restricts what a chart shows |

**"Well"** is the word for the drop-zones under the Visualizations pane — the boxes labelled *X-axis*, *Y-axis*, *Values*, *Legend*. You build a chart by dragging column names from the Data pane into these wells. That is the core motion of Power BI, and once it clicks the rest is detail.

## The three view buttons

Down the **far left edge** there are three small icons. You will switch between them:

1. **Report** (bar chart icon) — build charts here. This is where you spend most of your time.
2. **Table** (grid icon) — look at the raw loaded rows.
3. **Model** (three connected boxes) — set how tables link together.

## Two habits that will save you

**Save early, save often.** `Ctrl+S`. Power BI can and does crash.

**Undo is `Ctrl+Z`** and works for most things, including deleting a visual by accident.

---

# Part 1 — Load the data

## 1.1 Connect to PostgreSQL

1. **Home** ribbon → **Get Data** → **More…**
2. Search `PostgreSQL`, select **PostgreSQL database**, click **Connect**.
3. **Server:** `localhost` — or the Mac's IP address from Part 0 if PostgreSQL is on a different machine.
4. **Database:** `online_retail_db`
5. Leave **Data Connectivity mode** on **Import**. (The other option, DirectQuery, queries the database live on every click. This is a fixed historical dataset that never changes, so Import is faster with no downside.)
6. Click **OK**.

### Two prompts you will probably hit

**"Npgsql driver not found."** Power BI's PostgreSQL connector needs a separate component that does not ship with Power BI Desktop. Download it from [npgsql.org](https://www.npgsql.org/), run the installer, then **fully close and reopen Power BI Desktop** before retrying from step 1. One-time setup.

**Credentials.** Choose **Database** on the left, not Windows:

| Field | Value |
|---|---|
| User name | the PostgreSQL user you connect to `online_retail_db` with |
| Password | leave blank if your local instance uses trust authentication, otherwise enter it |

Leave the level set to the database itself, so the credential is remembered for `online_retail_db` specifically, then click **Connect**.

**"We were unable to connect using encryption."** Expected if your PostgreSQL is not set up for SSL. Click **OK** to connect unencrypted — this is your own machine, on your own network, holding public UCI data.

## 1.2 Load the four views

A **Navigator** window opens listing everything in the database.

1. Tick exactly these four:
   * `vw_valid_sales`
   * `vw_cancellations`
   * `vw_customer_profile`
   * `vw_all_invoices`
2. **Do not tick `online_retail_raw`.** That is the unfiltered raw table including cancellations, blank customer IDs and invalid rows. Putting it in the report is how you end up with two different "total sales" numbers on the same page.
3. **Do not tick the `06`–`11` views** (`vw_customer_cadence`, `vw_valid_sales_net`, etc.). Those belong to the 2026 follow-up analysis and are not part of this report.
4. Click **Load** (not Transform Data — there is nothing to transform; the cleaning already happened in SQL).

Loading takes a minute or two. `vw_valid_sales` has about 398,000 rows.

**Check it worked:** the Data pane on the right should now show four tables. Click the arrow next to `vw_valid_sales` to expand it — you should see `sales_value`, `order_date`, `product_name`, `country` and the rest.

---

# Part 2 — Build the model

This part creates no charts. It is the foundation, and doing it out of order means rebuilding visuals later.

## 2.1 Create the date table

A dedicated date table gives you clean Year/Month fields for axes and slicers, instead of wrestling with a raw timestamp.

1. **Home** ribbon → **New table** (in the Calculations group, near the right).
2. A formula bar appears. Delete whatever is in it and paste this **whole block**:

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

3. Press **Enter**.

**Check it worked:** `DateTable` appears in the Data pane. Click the Table view icon (left edge, middle) and select `DateTable` — it should run from **2010-12-01** to **2011-12-09** and have 374 rows.

## 2.2 Sort the month names correctly

Skip this and your charts will list months alphabetically — April, August, December — which looks broken.

1. In the Data pane, expand `DateTable` and click **Month Name** to select it.
2. **Column tools** ribbon → **Sort by column** → choose **Month Number**.

## 2.3 Link the date table to the sales table

> **Do this first: delete the relationships Power BI invented.**
>
> On load, Power BI auto-detects relationships by matching column names. It will have linked `vw_valid_sales` to `vw_all_invoices` on `invoice_no`, and probably `vw_valid_sales` to `vw_customer_profile` on `customer_id`. You do not want either.
>
> Leave them in place and the moment you try to add the DateTable link you get:
>
> ```
> There are ambiguous paths between 'vw_valid_sales' and 'DateTable':
> 'vw_valid_sales'->'vw_all_invoices'->'DateTable' and
> 'vw_valid_sales'->'DateTable'
> ```
>
> That is a loop — two different routes from one table to DateTable — and Power BI refuses it, because a filter arriving by one route would contradict the other.
>
> There is usually more than one. `vw_all_invoices` and `vw_cancellations` both have `invoice_no`; three of the four views have `customer_id` and `country`. Deleting one line often just reveals a longer chain, because any route counts — `vw_all_invoices → vw_cancellations → vw_valid_sales → DateTable` is a second path too.
>
> **Do not hunt for lines in the diagram. Clear the list and start over:**
>
> 1. **Home** ribbon → **Manage relationships** (on the **Modeling** ribbon in some versions). This lists every relationship instead of making you find them.
> 2. Select each one → **Delete**. Delete **all** of them. The list should end up empty.
> 3. **File → Options and settings → Options → Current File → Data Load →** untick **Autodetect new relationships after data is loaded**. Do this before the next step, or they come straight back.
>
> Then create the three below from **Manage relationships → New**, rather than by dragging — the dialog lets you set direction explicitly instead of letting Power BI guess.

1. Click the **Model** view icon (left edge, bottom).
2. You will see boxes for each table. Drag `DateTable` and `vw_valid_sales` apart so you can see both.
3. Click and drag from **`Date`** in the DateTable box onto **`order_date`** in the vw_valid_sales box. A line appears connecting them.
4. Double-click that line to check it. You want:
   * **Cardinality:** One to many (`1` on the DateTable side, `*` on the vw_valid_sales side)
   * **Cross-filter direction:** **Single**

   Power BI usually picks this correctly. If cross-filter direction says **Both**, change it to **Single** — "Both" causes the sales total to change unexpectedly when you click things.

5. Click **OK**.

Now add two more relationships the same way:

| From | To | Why |
|---|---|---|
| `DateTable[Date]` | `vw_all_invoices[invoice_date]` | so the cancellation rate filters by month |
| `DateTable[Date]` | `vw_cancellations[cancellation_date]` | so cancelled value filters by month |

Both must also be **one-to-many** with **Single** cross-filter direction.

**Check with Manage relationships when you are done: exactly three rows, every one starting at `DateTable`.** If there is a fourth, delete it. No `vw_` table should connect directly to another `vw_` table. No visual in this report combines fields from two different views, so those links buy nothing and cause loops.

> **Do not** create a relationship between `DateTable` and `vw_customer_profile`. `vw_customer_profile` is already one row per customer, not per transaction. Linking it to dates breaks the segment counts. This is the single most common cause of Page 2 numbers not adding up.

## 2.4 Mark it as a date table

1. Back in **Report** view, click `DateTable` in the Data pane to select the table itself (click the table name, not a column).
2. **Table tools** ribbon → **Mark as date table** → **Mark as date table**.
3. Choose `Date` as the date column. **OK**.

## 2.5 Create a home for your measures

1. **Home** ribbon → **New table**.
2. Paste and press Enter:

```
_Measures = { "Measure holder" }
```

The leading underscore matters. Power BI reserves the exact name `Measures` for its own internal use and will reject it. The underscore also sorts this table to the top of the Data pane, where you want it.

3. Expand `_Measures` in the Data pane, right-click the column called **Value**, and choose **Hide**. It is a placeholder with no purpose beyond making the table exist.

## 2.6 Add the fourteen measures

Open [powerbi/dax_measures.txt](powerbi/dax_measures.txt) in a text editor. It has all fourteen with the exact DAX and an explanation of each.

For **each** measure:

1. Click `_Measures` in the Data pane **first**. This decides which table the measure is filed under — miss it and your measures scatter across the four data tables.
2. **Home** ribbon → **New measure**.
3. Delete the placeholder text in the formula bar. Paste the full line from the file, name included:
   ```
   Net Sales = SUM(vw_valid_sales[sales_value])
   ```
4. Press **Enter**.

The fourteen, in order:

| # | Measure | # | Measure |
|---|---|---|---|
| 1 | Net Sales | 8 | Cancellation Rate |
| 2 | Total Orders | 9 | High-Value Active Customers |
| 3 | Unique Customers | 10 | High-Value At-Risk Customers |
| 4 | Average Order Value | 11 | **Active Repeat Customers** |
| 5 | Total Items Sold | 12 | At-Risk Repeat Customers |
| 6 | Cancelled Value | 13 | One-Time Customers |
| 7 | **Total Invoices** | 14 | Cancelled Invoices |

Twelve of these go on a card or a chart. Two are supporting measures that never appear on a visual directly: **Total Invoices** is the denominator inside Cancellation Rate, and **Total Items Sold** is there if you later add a product detail table. Both are correct to create.

## 2.7 Format the measures

Click a measure in the Data pane, then use the **Measure tools** ribbon.

| Measures | Format | Decimals |
|---|---|---|
| Net Sales, Average Order Value, Cancelled Value | Currency → £ English (United Kingdom) | 2 |
| Cancellation Rate | Percentage | 2 |
| Everything else | Whole number, with thousands separator | 0 |

Turn on the thousands separator for the whole numbers — it is the comma in `18,532`. Without it your KPI cards read `18532`, which looks unfinished.

> **A note on what is and is not fixed.** The cancellation rate defect described in the README's [Known issues](README.md#known-issues-found-after-the-dashboard-was-built) section **has been fixed** — see `vw_all_invoices` in `sql/03_clean_views.sql`. The Net Sales defect has **not**, deliberately: `vw_valid_sales` still counts fully cancelled orders as revenue, overstating the total by between £445,875 and £611,342. The reasoning for fixing one and not the other is at the top of `dax_measures.txt` — the rate is a self-contained metric, while Net Sales is the denominator of nearly every figure in the write-up and restating it would mean rewriting the whole analysis rather than disclosing a measured, bracketed error.

---

# Part 3 — Six techniques you will use on every page

**Read this section before building anything.** Every one of these fixes a specific flaw that was in the previous version of this dashboard. Skipping them is how you end up with a report that says `Sum of total_spend` on it.

## 3.1 Rename a field so it reads like English

When you drag `total_spend` into a chart, Power BI labels it **`Sum of total_spend`** — the raw database column name with the maths bolted on the front. That is fine in a database and unacceptable on something you show an employer.

**To fix:** in the Visualizations pane, **double-click the field** where it sits in the well. The text becomes editable. Type the name you want and press Enter.

| Power BI's default | Type this instead |
|---|---|
| `Sum of total_spend` | Total Spend |
| `Sum of total_orders` | Orders |
| `Sum of days_since_last_order` | Days Since Last Order |
| `Count of customer_id` | Customers |
| `Sum of quantity` | Units Sold |
| `Count of invoice_no` | Orders |
| `First product_name` | Product |

This renames it **only inside that visual**. The underlying column keeps its real name, so nothing breaks. Do this for every field in every well, every time.

## 3.2 Write your own chart title

> **First — "Format" means two different things in Power BI, and you will need the second one constantly.**
>
> | | Where it is | What it does |
> |---|---|---|
> | Format **ribbon** | Top row of tabs, beside Help | Arranging visuals — Align, Group, Bring forward |
> | Format **pane** | Inside the **Visualizations** pane on the right | Styling one visual — titles, colours, number display |
>
> **Every "Format pane" instruction in this guide means the second one.** To open it: select a visual, then in the Visualizations pane click the **paintbrush** icon just under "Build visual", immediately right of the chart-grid icon. The pane heading changes from **Build visual** to **Format visual** and you get two tabs, **Visual** and **General**.

Power BI auto-titles charts by pasting field names together: **`Net Sales by product_name`**. Replace it.

1. Select the visual.
2. Open the **Format pane** (paintbrush, as above).
3. **General** tab → expand **Title**.
4. Type into the **Text** box.
5. Set size to about **14pt** and make it bold.

Titles should say what the reader is looking at: *Top 10 Products by Revenue*, not *Net Sales by product_name*.

## 3.3 Make a chart big enough for its own data

If a chart says "Top 10" it must show ten bars. When a visual is too short, Power BI silently adds a scrollbar and shows five — the title claims one thing and the picture shows another. An interviewer will notice.

**Rule of thumb:** a horizontal bar chart needs roughly **35 pixels of height per bar**, plus room for the title and axis. Ten bars ≈ **400px tall** minimum.

**To resize:** click the visual, then drag the handles on its edges. To check it fits: look for a scrollbar on the right edge of the visual. **If there is a scrollbar, it is too small.**

If you genuinely cannot fit ten, show five and retitle it *Top 5*. An honest Top 5 beats a broken Top 10.

## 3.4 Turn off totals that mean nothing

Table visuals add a bold Total row at the bottom by default, and it sums **every** numeric column — including ones where a sum is meaningless. Adding up "days since last order" across 195 customers produces `30,555`, a number describing nothing.

**To fix:**

1. Select the table visual.
2. **Format** pane (paintbrush) → **Visual** tab → expand **Totals**.
3. Either switch **Totals** off entirely, or leave it on and use the **per-column** control to include only the columns where a total is genuinely meaningful (Total Spend yes; Days Since Last Order no; Orders yes).

**Ask yourself for each column: does adding this up produce a real quantity?** Money and counts, yes. Days, averages, percentages and dates, no.

## 3.5 Add a Top N filter

1. Select the visual.
2. Expand the **Filters** pane (right side).
3. Find the field you want to rank by under **Filters on this visual**. Click it.
4. **Filter type** → **Top N**.
5. **Show items:** `Top` `10`.
6. Drag the measure to rank by into the **By value** box.
7. Click **Apply filter**.

## 3.6 Make numbers readable on the chart itself

For bar charts, turning on data labels means the reader does not have to eyeball values against an axis.

**Format** pane → **Visual** tab → **Data labels** → **On**.

For currency, also set **Display units** to **None** if the values are small enough to read, or **Thousands**/**Millions** with 1 decimal for large ones. `8.9M` is fine on a card; `8911407.9` is not.

---

# Part 4 — Page 1: Sales Overview

Rename the page tab at the bottom: double-click **Page 1** → type `Sales Overview`.

## 4.1 Title

**Insert** ribbon → **Text box**. Drag it across the top of the canvas.

Type: **UK Online Retail | Sales Performance Overview**
Second line, smaller: `Transaction data: December 2010 – December 2011`

Note the spaces around the dash. Set the title to about 20pt bold, the subtitle to 11pt grey.

## 4.2 Four KPI cards

For each: **Insert** → **Visual** → **Card**, then drag the measure into the single well.

| Card | Measure | Should show |
|---|---|---|
| 1 | `Net Sales` | £8,911,407.90 |
| 2 | `Total Orders` | 18,532 |
| 3 | `Unique Customers` | 4,338 |
| 4 | `Average Order Value` | £480.87 |

**For each card:** open the **Format pane** — that is the **paintbrush icon inside the Visualizations pane**, not the Format tab on the ribbon ([see 3.2](#32-write-your-own-chart-title)) — then **Visual** tab → **Callout value** → set **Display units** to **None**, so it shows `£8,911,407.90` and not `£8.91M`. Then **General** tab → **Title** → on, and name it.

**Also turn the card's built-in label off**, or the name appears twice — once as your Title above the number and again as small grey text below it: **Visual** tab → **Category label** → **Off**.

Name all four in the same style. Title Case matches the measure names: *Net Sales*, *Total Orders*, *Unique Customers*, *Average Order Value* — not *Total orders* or *Average order value*. Mixed capitalisation across a KPI row is one of the first things a reader notices.

Select all four (click one, `Ctrl+click` the others), then **Format** ribbon → **Align** → **Align top**, and **Distribute horizontally**. Eyeballing alignment always shows.

## 4.3 Monthly Net Sales Trend — Line chart

* **X-axis:** `DateTable[Year Month]`
* **Y-axis:** `Net Sales`
* Title → `Monthly Net Sales`
* Rename the Y-axis field to `Net Sales` ([3.1](#31-rename-a-field-so-it-reads-like-english))

## 4.4 Top 10 Products by Revenue — Bar chart

Use **Clustered bar chart** (horizontal bars — product names are long and unreadable on a vertical axis).

* **Y-axis:** `vw_valid_sales[product_name]` → rename to `Product`
* **X-axis:** `Net Sales`
* Top N filter: Top 10 by Net Sales ([3.5](#35-add-a-top-n-filter))
* Title → `Top 10 Products by Revenue`
* **Make it at least 400px tall** ([3.3](#33-make-a-chart-big-enough-for-its-own-data))
* Format → Visual → **Y-axis** → set **Maximum area width** to about 40% so product names are not truncated to `PAPER CRA…`

## 4.5 Top 10 International Markets — Bar chart

* **Y-axis:** `vw_valid_sales[country]` → rename to `Country`
* **X-axis:** `Net Sales`
* Filters pane → add `country` → **Filter type: Advanced** → *is not* `United Kingdom` → Apply
* Then add a Top N filter: Top 10 by Net Sales
* Title → `Top 10 International Markets (excluding UK)`

The UK is £7.3m against the Netherlands' £285k. Leaving it in makes one bar the full width and the other nine invisible — which is why this chart excludes it.

## 4.6 Slicers — one only

A **slicer** is an on-page filter.

**Insert** → **Visual** → **Slicer**, then drag `DateTable[Date]` in. Power BI gives you a date range slider automatically.

> **Do not add a product slicer.** The previous version of this dashboard had one, and because there are 3,865 products it rendered as an enormous alphabetical checkbox list starting at `10 COLOUR SPACEBOY PEN` that consumed a third of the page and told the reader nothing. If you want a country filter, add one as a slicer set to **Dropdown** (Format → Visual → Slicer settings → Options → Style → Dropdown), never as a list.

## 4.7 Verify Page 1

| What | Expected | Source file |
|---|---|---|
| Net Sales | £8,911,407.90 | `outputs/query_results/02_overall_kpis.csv` |
| Total Orders | 18,532 | same |
| Unique Customers | 4,338 | same |
| Average Order Value | £480.87 | same |
| Top product | PAPER CRAFT , LITTLE BIRDIE — £168,469.60 | `05_top_10_products_by_net_sales.csv` |
| Top international market | Netherlands — £285,446.34 | `07_top_10_countries_excl_uk.csv` |

> **That top product is not a real sale.** It is an 80,995-unit order keyed at 09:15 on 2011-12-09 and reversed twelve minutes later. It is still counted because `vw_valid_sales` excludes cancellation lines without subtracting the orders they reverse. This is documented in [DATA_QUALITY_FINDINGS.md](DATA_QUALITY_FINDINGS.md) and the README's known-issues section. Leave it — the disclosure is the point.

**If Net Sales is wrong:** check the DateTable relationship cross-filter direction is **Single** ([2.3](#23-link-the-date-table-to-the-sales-table)), and check no slicer is left part-selected from testing.

---

# Part 5 — Page 2: Customer Retention

New page (`+` at the bottom), rename to `Customer Retention`.

Text box title: **Customer Retention and Value**. Add the same subtitle style as Page 1 — the previous version had a subtitle on Page 1 only, which looked inconsistent.

## 5.1 Five KPI cards — all five

| Card | Measure | Should show |
|---|---|---|
| 1 | `High-Value Active Customers` | 1,399 |
| 2 | `One-Time Customers` | 1,493 |
| 3 | `Active Repeat Customers` | **844** |
| 4 | `At-Risk Repeat Customers` | 407 |
| 5 | `High-Value At-Risk Customers` | 195 |

**All five, not four.** There are five segments. The earlier build had four cards, so the page showed 3,494 customers while Page 1 said 4,338 — 844 unaccounted for. Anyone checking your arithmetic finds that in about twenty seconds.

```
1,399 + 1,493 + 844 + 407 + 195 = 4,338 ✓
```

Colour them by urgency (Format → General → Effects → Background): green for High-Value Active, neutral grey for One-Time and Active Repeat, amber for At-Risk Repeat, red for High-Value At-Risk. On a retention page that is a genuine reading aid, not decoration.

## 5.2 Customers by Segment — Bar chart

* **Y-axis:** `vw_customer_profile[customer_segment]` → rename to `Segment`
* **X-axis:** `vw_customer_profile[customer_id]`, then click its dropdown in the well → **Count (Distinct)** → rename to `Customers`
* Title → `Customers by Segment`
* Data labels on ([3.6](#36-make-numbers-readable-on-the-chart-itself))

## 5.3 Top 10 Customers by Spend — Bar chart

* **Y-axis:** `vw_customer_profile[customer_id]` → rename to `Customer ID`
* **X-axis:** `vw_customer_profile[total_spend]` → rename to `Total Spend`
* Top N filter: Top 10 by total_spend
* Title → `Top 10 Customers by Spend`
* **At least 400px tall.** The previous build titled this "Top 10" and displayed five behind a scrollbar. Check for a scrollbar before you move on.

Customer IDs are just numbers — this dataset has no customer names. Worth a note in the chart subtitle: *Customers are identified by ID only; this dataset contains no names.*

## 5.4 High-Value At-Risk Customers — Table

This is the actionable output of the whole page: a call list.

* **Insert** → **Visual** → **Table**
* Columns in this order, renaming each ([3.1](#31-rename-a-field-so-it-reads-like-english)):

| Field | Rename to |
|---|---|
| `customer_id` | Customer ID |
| `total_spend` | Total Spend |
| `total_orders` | Orders |
| `last_order_date` | Last Order |
| `days_since_last_order` | Days Since Last Order |

* **Filter:** Filters pane → `customer_segment` → **is** `High-value at risk`
* Sort by Total Spend descending (click that column header)
* Format Total Spend as currency £

**Now turn off the meaningless totals** ([3.4](#34-turn-off-totals-that-mean-nothing)). Left on, this table prints `30,555` at the bottom — the sum of every customer's days-since-last-order, which is not a real quantity. Either turn Totals off entirely, or restrict them to Total Spend and Orders only.

**Size it to show at least 12 rows without a scrollbar**, and make sure the bottom row is not cut off mid-height. The earlier screenshot ended halfway through a row.

## 5.5 Verify Page 2

| What | Expected | Source file |
|---|---|---|
| High-Value Active | 1,399 | `outputs/query_results/13_customer_segment_summary.csv` |
| One-Time | 1,493 | same |
| Active Repeat | 844 | same |
| At-Risk Repeat | 407 | same |
| High-Value At-Risk | 195 | same |
| **Five cards summed** | **4,338** — must equal Unique Customers on Page 1 | |
| Top customer | 14646 — £280,206.02 | `15_top_20_customers_by_spend.csv` |
| At-risk table row count | 195 | `14_retention_priority_high_value_at_risk.csv` |

**If the five don't sum to 4,338:** you have almost certainly created a relationship between `DateTable` and `vw_customer_profile`. Go to Model view and delete it ([2.3](#23-link-the-date-table-to-the-sales-table)).

---

# Part 6 — Page 3: Cancellations

New page, rename to `Cancellations`. Title: **Cancellations and Product Demand**.

## 6.1 Three KPI cards

| Card | Measure | Should show |
|---|---|---|
| 1 | `Cancelled Invoices` | 3,836 |
| 2 | `Cancelled Value` | £896,812.49 |
| 3 | `Cancellation Rate` | **14.81%** |

Set Cancelled Value's display units to **None** — the earlier build showed `896.81K` with no currency symbol.

### A note on the Cancellation Rate card

This card used to be broken in two ways, and both are now fixed at the data layer rather than worked around in Power BI.

It divided a numerator counted from the raw table by a denominator counted from `vw_valid_sales` — two different populations — which inflated it to 17.15% against a true 14.81%. And because `vw_valid_sales` was related to `DateTable` while `vw_cancellations` was not, any date filter shrank the denominator and left the numerator whole: February 2011 returned **79%** against a real **15.72%**.

`vw_all_invoices` fixes both. It is one row per invoice for the whole dataset, cancelled or not, each carrying a date, and both halves of the fraction now count from it. You do not need to do anything special here — just make sure you created the `DateTable[Date] → vw_all_invoices[invoice_date]` relationship in [Part 2.3](#23-link-the-date-table-to-the-sales-table).

**Test it while you are on this page.** Add a temporary slicer on `DateTable[Month Name]`, select **February**, and check the card:

| | |
|---|---:|
| Correct February rate | **15.72%** |
| What the old measure returned | 79.37% |

Delete the slicer afterwards. If you see 79%, your relationship is missing or the measure is reading from the wrong table.

## 6.2 Cancelled Value by Month — Line chart

* **X-axis:** `DateTable[Year Month]` → rename to `Month`
* **Y-axis:** `Cancelled Value`
* Title → `Cancelled Value by Month`

> Use `DateTable[Year Month]`, the same field as the Page 1 trend chart. This works because of the `DateTable[Date] → vw_cancellations[cancellation_date]` relationship created in [2.3](#23-link-the-date-table-to-the-sales-table) — without it, DateTable fields would return blanks here. `vw_cancellations[cancellation_month]` also works, but using the shared date table keeps both trend charts on the same axis field and lets one date slicer drive both pages.

## 6.3 What the cancellation total actually contains — Bar chart

This is the most interesting visual on the page and the earlier build did not have it.

* **Y-axis:** `vw_cancellations[product_name]` → rename to `Item`
* **X-axis:** `Cancelled Value`
* Top N filter: Top 10 by Cancelled Value
* Title → `Top 10 Cancelled Items — mostly fees, not returns`
* At least 400px tall; widen the Y-axis area so names are not truncated

The top entry is **AMAZON FEE** at £235,281.59, followed by **Manual** at £146,784.46. Neither is a customer returning anything. Only **34.6% (£310,254.58)** of the £896,812.49 is merchandise coming back — the breakdown is in `outputs/query_results/17_cancellation_composition.csv` and README Finding 2. Consider a text box beside this chart making that point directly; it is the single strongest observation in the project.

## 6.4 Top 10 Products by Units Sold — Bar chart

* **Y-axis:** `vw_valid_sales[product_name]` → rename to `Product`
* **X-axis:** `vw_valid_sales[quantity]` → Sum → rename to `Units Sold`
* Top N filter: Top 10 by Units Sold
* Title → `Top 10 Products by Units Sold`

Different ranking from Page 1 on purpose — a cheap product can sell huge volume without earning much revenue. Note that PAPER CRAFT , LITTLE BIRDIE tops this chart only because of the reversed 80,995-unit order, so the first bar is an artefact rather than demand.

> **Do not repeat the full product table from Page 1 here.** The earlier build had the same table on both pages, which wastes half of Page 3 and gives the reader nothing new.

## 6.5 Verify Page 3

| What | Expected | Source file |
|---|---|---|
| Cancelled Invoices | 3,836 | `outputs/query_results/08_cancellation_kpis.csv` |
| Cancelled Value | £896,812.49 | same |
| Cancellation Rate | **14.81%** | `59_cancellation_rate_corrected.csv` |
| Top cancelled item | AMAZON FEE — £235,281.59 | `10_most_cancelled_products.csv` |
| Top product by units | PAPER CRAFT , LITTLE BIRDIE — 80,995 | `11_top_10_products_by_quantity.csv` |

---

# Part 7 — Final check, save, screenshot

## 7.1 Walk all three pages against this list

Go page by page. Every item is a defect that was visible in the previous screenshots.

- [ ] **No raw column names anywhere.** Search every axis label, legend, table header and tooltip for `_` or the words `Sum of` / `Count of`. If you can see `total_spend`, `product_name`, `customer_id`, `Sum of quantity` or `Count of invoice_no`, fix it ([3.1](#31-rename-a-field-so-it-reads-like-english)).
- [ ] **Every chart has a title you wrote**, not `Net Sales by product_name` ([3.2](#32-write-your-own-chart-title)).
- [ ] **No scrollbars on any visual.** Any chart claiming "Top 10" shows ten ([3.3](#33-make-a-chart-big-enough-for-its-own-data)).
- [ ] **No table row cut off** at the bottom edge of its visual.
- [ ] **No meaningless totals.** Nothing sums days, dates, averages or percentages ([3.4](#34-turn-off-totals-that-mean-nothing)).
- [ ] **Page 2's five cards sum to 4,338.**
- [ ] **Thousands separators on.** `18,532` not `18532`.
- [ ] **Currency symbols present.** `£896,812.49` not `896.81K`.
- [ ] **Titles and subtitles consistent** across all three pages.
- [ ] **No duplicated labels on cards** — Title on, Category label off, not both.
- [ ] **Capitalisation consistent** within every KPI row (`Total Orders`, not `Total orders`).
- [ ] **All slicers cleared.** A slicer left part-selected from testing silently changes every number on the page.
- [ ] **One accent colour**, not Power BI's default rainbow.

## 7.2 Save

`Ctrl+S`, save as:

```
powerbi/online_retail_dashboard.pbix
```

**This file is now tracked in git** — it is the deliverable the project is named after, it is only about 3.6 MB, and a reader who cannot open it cannot check anything in the README. (It used to be gitignored, which meant the dashboard did not exist for anyone but you.)

```bash
git add powerbi/online_retail_dashboard.pbix
```

## 7.3 Screenshots

Save all three to `outputs/figures/`, overwriting the existing files:

* `page1_sales_overview.jpg`
* `page2_customer_retention.jpg`
* `page3_cancellations_products.jpg`

The README embeds these exact filenames, so keep the names identical.

**Capture them properly:**

* Press `F11` for full-screen focus mode, or use **View** → **Page view** → **Fit to page**, so nothing is cut off.
* Capture at the largest window size you can. The previous screenshots were about 1,070px wide and the text was hard to read at README size.
* Click on empty canvas before capturing so no visual is highlighted with a selection border.
* Make sure no slicer is filtered.

## 7.4 One last thing to delete

Once the new screenshots are in place, open [README.md](README.md), find the **Dashboard Screenshots** section, and delete this bullet:

> *Customer IDs read `14646.0` in the screenshots and `14646` everywhere else…*

That note exists only because the old screenshots predate the customer-ID fix in `src/01_excel_to_csv.py`. New screenshots will show `14646` correctly, and the note becomes untrue the moment you replace them.

The second bullet, about totals differing, **stays** — those differences are real and deliberate, and they are explained in the README's known-issues section.
