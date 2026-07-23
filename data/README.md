# Data

## Source

Download `Online Retail.xlsx` from the official UCI Machine Learning Repository:

https://archive.ics.uci.edu/dataset/352/online+retail

Citation:

Chen, D. (2015). Online Retail [Dataset].
UCI Machine Learning Repository.
https://doi.org/10.24432/C5BW33

## Setup

1. Download `Online Retail.xlsx`.
2. Save it in this folder.
3. Run the Python script:

```bash
python python/01_excel_to_csv.py
```

4. The script creates `online_retail.csv` in this folder.
5. Import that CSV into PostgreSQL.

## Important notes

- The dataset covers transactions from December 2010 to December 2011.
- `InvoiceNo` values beginning with `C` represent cancellations.
- This project calculates sales as `Quantity * UnitPrice`.
- The dataset does not contain cost or profit data, so this project does not analyse profit.