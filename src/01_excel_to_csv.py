r"""Convert the raw UCI Online Retail spreadsheet into a CSV Postgres can load.

Why this exists
---------------
The dataset ships as a single .xlsx file. PostgreSQL's \copy cannot read Excel,
so the file has to become a CSV before sql/01_create_table.sql can load it.

This script does the conversion and nothing else. It renames the columns to the
snake_case names used by every SQL script in this project, and it fixes one
pandas behaviour that would otherwise corrupt every customer ID (see the
comment on the astype call below). No rows are added, removed or filtered here
- cleaning happens later, in sql/03_clean_views.sql, where it stays visible.

Usage
-----
    python src/01_excel_to_csv.py

Expects data/Online Retail.xlsx to exist. See data/README.md for the download
link. Writes data/online_retail.csv, overwriting it if it is already there.
"""

from pathlib import Path

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[1]
INPUT_FILE = PROJECT_ROOT / "data" / "Online Retail.xlsx"
OUTPUT_FILE = PROJECT_ROOT / "data" / "online_retail.csv"

# The source spreadsheet's own headers, in order, renamed to the snake_case
# names that sql/01_create_table.sql expects.
COLUMN_NAMES = [
    "invoice_no",
    "stock_code",
    "description",
    "quantity",
    "invoice_date",
    "unit_price",
    "customer_id",
    "country",
]


def main():
    """Read the Excel file, rename the columns, and write the CSV."""
    df = pd.read_excel(INPUT_FILE)
    df.columns = COLUMN_NAMES

    # CustomerID is a whole number, but about a quarter of the cells are blank.
    # A plain integer column has no way to store "missing", so pandas silently
    # converts the whole column to decimals to make room for the blanks - and
    # every ID comes out as 17850.0 instead of 17850.
    #
    # "Int64" (capital I) is pandas' nullable integer type: it holds whole
    # numbers AND blanks, so the IDs stay whole and the blanks stay blank.
    #
    # The quantity column is the control case for this: it is the same kind of
    # number, has no blanks, and comes out as 6 / 56 / 80995 with no conversion.
    df["customer_id"] = df["customer_id"].astype("Int64")

    df.to_csv(OUTPUT_FILE, index=False, encoding="utf-8")

    # Printed so the conversion can be confirmed without opening the CSV. The
    # dtype line is the check on the astype call above.
    print(f"Created {OUTPUT_FILE}")
    print(f"  rows:               {len(df):,}")
    print(f"  customer_id dtype:  {df['customer_id'].dtype}")
    print(f"  customer_id blanks: {df['customer_id'].isna().sum():,}")


if __name__ == "__main__":
    main()
