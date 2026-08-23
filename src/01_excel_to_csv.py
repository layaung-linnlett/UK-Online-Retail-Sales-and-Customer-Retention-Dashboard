from pathlib import Path
import pandas as pd

project_root = Path(__file__).resolve().parents[1]
input_file = project_root / "data" / "Online Retail.xlsx"
output_file = project_root / "data" / "online_retail.csv"

df = pd.read_excel(input_file)

df.columns = [
    "invoice_no",
    "stock_code",
    "description",
    "quantity",
    "invoice_date",
    "unit_price",
    "customer_id",
    "country",
]

# CustomerID is a whole number, but about a quarter of the cells are blank.
# A plain integer column has no way to store "missing", so pandas silently
# converts the whole column to decimals to make room for the blanks - and every
# ID comes out as 17850.0 instead of 17850.
#
# "Int64" (capital I) is pandas' nullable integer type: it holds whole numbers
# AND blanks, so the IDs stay whole and the blanks stay blank.
#
# The quantity column is the control case for this: it is the same kind of
# number, has no blanks, and comes out as 6 / 56 / 80995 with no conversion.
df["customer_id"] = df["customer_id"].astype("Int64")

df.to_csv(output_file, index=False, encoding="utf-8")

print(f"Created: {output_file}")
print(f"Rows: {len(df):,}")
print("\nColumns:")
print(df.columns.tolist())
print("\nFirst five rows:")
print(df.head())
print("\ncustomer_id dtype:", df["customer_id"].dtype, "- should be Int64, not float64")
print("customer_id blanks:", int(df["customer_id"].isna().sum()))