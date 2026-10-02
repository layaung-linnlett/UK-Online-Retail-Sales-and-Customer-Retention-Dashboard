"""Export every analysis query in sql/ to a CSV in outputs/query_results/.

Why this exists
---------------
The CSVs in outputs/query_results/ are the evidence behind the numbers quoted
in README.md and docs/analysis_summary.md. Before this script they were
exported by hand, which meant a reader had no way to regenerate them and no way
to confirm a CSV still matched the query it claimed to come from.

How it works
------------
The queries are NOT copied into this file. This script reads the .sql files,
splits them into statements, and runs the one named in the manifest below. So
there is exactly one copy of every query - the one in sql/ that a person reads.
Edit the SQL, re-run this, and the CSV follows.

Statements are referenced by position (1-based, counting every statement in the
file including DROP and CREATE). If you insert a statement into a .sql file,
the manifest indexes after it shift, and the guard at the bottom of this file
will fail loudly rather than writing a mislabelled CSV.

Usage
-----
    python src/02_export_query_results.py

Requires psql on PATH and a database named online_retail_db (override with
the RETAIL_DB environment variable) built by sql/01_create_table.sql. Run the
sql/ scripts in order first - this script only reads; it does not create the
views the queries depend on.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

# Override with RETAIL_DB=<name> if your database is called something else.
DB = os.environ.get("RETAIL_DB", "online_retail_db")
PROJECT_ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = PROJECT_ROOT / "sql"
OUT_DIR = PROJECT_ROOT / "outputs" / "query_results"

# (source .sql file, statement number within that file, output CSV name)
#
# Statement numbers count every statement in the file, including DROP and
# CREATE. The first word of the statement is recorded here as a check.
MANIFEST = [
    # --- Raw profiling, before any cleaning -------------------------------
    ("02_data_quality_checks.sql", 1, "00_raw_row_count.csv"),
    ("02_data_quality_checks.sql", 2, "00_raw_date_range.csv"),
    ("02_data_quality_checks.sql", 3, "00_raw_missing_values.csv"),
    ("02_data_quality_checks.sql", 4, "00_raw_cancellation_counts.csv"),
    ("02_data_quality_checks.sql", 5, "00_raw_non_positive_values.csv"),
    ("02_data_quality_checks.sql", 6, "00_raw_countries.csv"),
    ("03_clean_views.sql", 5, "01_clean_view_sanity_check.csv"),

    # --- Sales analysis (Power BI page 1) ---------------------------------
    ("04_sales_analysis.sql", 1, "02_overall_kpis.csv"),
    ("04_sales_analysis.sql", 2, "03_monthly_sales_trend.csv"),
    ("04_sales_analysis.sql", 3, "04_month_on_month_growth.csv"),
    ("04_sales_analysis.sql", 4, "05_top_10_products_by_net_sales.csv"),
    ("04_sales_analysis.sql", 5, "06_sales_by_country.csv"),
    ("04_sales_analysis.sql", 6, "07_top_10_countries_excl_uk.csv"),

    # --- Cancellations (Power BI page 3) ----------------------------------
    ("04_sales_analysis.sql", 7, "08_cancellation_kpis.csv"),
    ("04_sales_analysis.sql", 8, "09_cancelled_value_by_month.csv"),
    ("04_sales_analysis.sql", 9, "10_most_cancelled_products.csv"),
    ("04_sales_analysis.sql", 10, "11_top_10_products_by_quantity.csv"),
    ("04_sales_analysis.sql", 11, "12_full_product_sales_table.csv"),
    ("04_sales_analysis.sql", 12, "17_cancellation_composition.csv"),
    ("04_sales_analysis.sql", 13, "18_cancellation_non_merchandise.csv"),
    ("04_sales_analysis.sql", 14, "59_cancellation_rate_corrected.csv"),
    ("04_sales_analysis.sql", 15, "60_cancellation_rate_by_month.csv"),

    # --- Customer analysis (Power BI page 2) ------------------------------
    ("05_customer_analysis.sql", 3, "13_customer_segment_summary.csv"),
    ("05_customer_analysis.sql", 4, "14_retention_priority_high_value_at_risk.csv"),
    ("05_customer_analysis.sql", 5, "15_top_20_customers_by_spend.csv"),
    ("05_customer_analysis.sql", 6, "16_full_customer_profile.csv"),

    # --- 2026 follow-up: cadence-based retention (sql/06) -----------------
    ("06_retention_cadence.sql", 3, "19_cadence_threshold_evidence.csv"),
    ("06_retention_cadence.sql", 4, "20_cadence_segment_summary.csv"),
    ("06_retention_cadence.sql", 5, "21_cadence_at_risk_call_list.csv"),
    ("06_retention_cadence.sql", 6, "22_cadence_before_after.csv"),
    ("06_retention_cadence.sql", 7, "23_cadence_who_moved_vs_all_at_risk.csv"),
    ("06_retention_cadence.sql", 8, "24_cadence_who_moved_vs_195.csv"),
    ("06_retention_cadence.sql", 9, "25_ninety_day_rule_false_positives.csv"),
    ("06_retention_cadence.sql", 10, "26_ninety_day_rule_misses.csv"),
    ("06_retention_cadence.sql", 11, "27_cadence_too_few_orders.csv"),
    ("06_retention_cadence.sql", 12, "28_cadence_censoring_check.csv"),

    # --- 2026 follow-up: revenue concentration (sql/07) -------------------
    ("07_revenue_concentration.sql", 1, "29_reversal_defect_quantified.csv"),
    ("07_revenue_concentration.sql", 2, "30_net_sales_published_vs_corrected.csv"),
    ("07_revenue_concentration.sql", 3, "31_pareto_test.csv"),
    ("07_revenue_concentration.sql", 4, "32_revenue_concentration_curve.csv"),
    ("07_revenue_concentration.sql", 5, "33_top_10_customers_corrected.csv"),
    ("07_revenue_concentration.sql", 6, "34_top_10_exposure.csv"),
    ("07_revenue_concentration.sql", 7, "35_top_10_by_country.csv"),

    # --- 2026 follow-up: first to second purchase (sql/08) ----------------
    ("08_first_to_second_purchase.sql", 3, "36_one_and_done_headline.csv"),
    ("08_first_to_second_purchase.sql", 4, "37_one_and_done_by_invoice.csv"),
    ("08_first_to_second_purchase.sql", 5, "38_one_and_done_by_observation_window.csv"),
    ("08_first_to_second_purchase.sql", 6, "39_days_to_second_purchase.csv"),
    ("08_first_to_second_purchase.sql", 7, "40_second_gap_vs_later_gaps.csv"),
    ("08_first_to_second_purchase.sql", 8, "41_return_probability_by_day.csv"),
    ("08_first_to_second_purchase.sql", 9, "42_one_and_done_revenue.csv"),

    # --- 2026 follow-up: cohort retention (sql/09) ------------------------
    ("09_cohort_retention.sql", 1, "43_cohort_sizes.csv"),
    ("09_cohort_retention.sql", 2, "44_cohort_first_eight_trading_days.csv"),
    ("09_cohort_retention.sql", 3, "45_cohort_90_day_repeat_rates.csv"),
    ("09_cohort_retention.sql", 4, "46_cohort_month_summary.csv"),
    ("09_cohort_retention.sql", 5, "47_orders_by_month.csv"),

    # --- 2026 follow-up: customer value (sql/10) --------------------------
    ("10_customer_value.sql", 1, "48_customer_value_distribution.csv"),
    ("10_customer_value.sql", 2, "49_customer_value_excluding_top_10.csv"),
    ("10_customer_value.sql", 3, "50_one_time_vs_repeat_value.csv"),
    ("10_customer_value.sql", 4, "51_value_ladder_by_purchase_count.csv"),

    # --- 2026 follow-up: stayers vs leavers (sql/11) ----------------------
    ("11_stayers_vs_leavers.sql", 3, "52_never_returned_vs_returned_raw.csv"),
    ("11_stayers_vs_leavers.sql", 4, "53_never_returned_vs_returned_90d.csv"),
    ("11_stayers_vs_leavers.sql", 5, "54_active_vs_lapsed.csv"),
    ("11_stayers_vs_leavers.sql", 6, "55_active_vs_lapsed_observation_control.csv"),
    ("11_stayers_vs_leavers.sql", 7, "56_first_order_value_spread.csv"),
    ("11_stayers_vs_leavers.sql", 8, "57_active_vs_lapsed_cadence.csv"),
    ("11_stayers_vs_leavers.sql", 9, "58_days_to_second_within_cadence_band.csv"),
]


def split_statements(sql_path):
    """Return the statements in a .sql file, comments stripped, in order.

    Splitting on semicolons is safe here because no query in this project
    contains a semicolon inside a string literal. The check below enforces
    that, so the assumption fails loudly if it ever stops being true.
    """
    text = sql_path.read_text(encoding="utf-8")
    text = re.sub(r"--[^\n]*", "", text)
    for literal in re.findall(r"'[^']*'", text):
        if ";" in literal:
            raise SystemExit(
                f"{sql_path.name}: a string literal contains a semicolon, so "
                "splitting on ';' is no longer safe. Fix this script before "
                "trusting its output."
            )
    return [s.strip() for s in text.split(";") if s.strip()]


def export(sql_file, index, out_name):
    """Run one statement from a .sql file and write its rows to a CSV.

    Checks that the statement really is a query before running it, so a
    shifted manifest index fails here rather than silently producing a CSV
    labelled as one query but holding the results of another.

    Returns the number of data rows written.
    """
    statements = split_statements(SQL_DIR / sql_file)
    if index > len(statements):
        raise SystemExit(
            f"{sql_file}: manifest asks for statement {index} but the file "
            f"only has {len(statements)}."
        )
    stmt = statements[index - 1]

    first = stmt.split()[0].upper()
    if first not in ("SELECT", "WITH"):
        raise SystemExit(
            f"{sql_file} statement {index} starts with {first}, not SELECT or "
            f"WITH. The manifest is pointing at the wrong statement for "
            f"{out_name} - most likely a statement was inserted above it."
        )

    target = OUT_DIR / out_name
    copy_cmd = f"\\copy ({stmt}) TO '{target}' WITH (FORMAT csv, HEADER true)"
    result = subprocess.run(
        ["psql", "-d", DB, "-X", "-v", "ON_ERROR_STOP=1", "-c", copy_cmd],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(
            f"Failed exporting {out_name} from {sql_file} statement {index}:\n"
            f"{result.stderr.strip()}"
        )
    rows = target.read_text(encoding="utf-8").count("\n") - 1
    return rows


def main():
    """Export every query in the manifest, printing one line per file."""
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    seen = set()
    for _, _, out_name in MANIFEST:
        if out_name in seen:
            raise SystemExit(f"Manifest lists {out_name} twice.")
        seen.add(out_name)

    for sql_file, index, out_name in MANIFEST:
        rows = export(sql_file, index, out_name)
        print(f"{out_name:<52} {rows:>6} rows  <- {sql_file} statement {index}")

    print(f"\n{len(MANIFEST)} files written to {OUT_DIR.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
