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

df.to_csv(output_file, index=False, encoding="utf-8")

print(f"Created: {output_file}")
print(f"Rows: {len(df):,}")
print("\nColumns:")
print(df.columns.tolist())
print("\nFirst five rows:")
print(df.head())