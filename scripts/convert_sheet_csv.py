#!/usr/bin/env python3
"""
Convert a Google Sheet activity log CSV into myDay's import format.

Sheet format  : DATE(DD/MM), DAY, 12am, 1am, ..., 11pm  (columns A–Z)
App format    : date(yyyy-MM-dd), hour(0-23), activity(rawValue string)

Number → category mapping
  0  → sleep        5  → friends
  1  → work         6  → leisure
  2  → food         7  → family
  3  → productive   8  → misc
  4  → exercise     9  → travel
                   10  → misc
"""

import argparse
import csv
import sys
from datetime import date

MAPPING = {
    0: "sleep",
    1: "work",
    2: "food",
    3: "productive",
    4: "exercise",
    5: "friends",
    6: "leisure",
    7: "family",
    8: "misc",
    9: "travel",
    10: "misc",
}

# Column indices for the 24 hours (12am=col2 … 11pm=col25)
HOUR_COL_START = 2
HOUR_COUNT = 24


def parse_date(raw: str, year: int) -> date | None:
    raw = raw.strip()
    if not raw:
        return None
    try:
        day_str, month_str = raw.split("/")
        return date(year, int(month_str), int(day_str))
    except (ValueError, AttributeError):
        return None


def date_from_ddmm(ddmm: str, year: int) -> date | None:
    return parse_date(ddmm, year)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert sheet CSV to myDay import CSV")
    parser.add_argument("--input", required=True, help="Path to the Google Sheet CSV export")
    parser.add_argument("--output", required=True, help="Path for the generated myDay CSV")
    parser.add_argument("--year", type=int, default=2026, help="Year for the dates (default: 2026)")
    parser.add_argument("--from", dest="date_from", default=None, metavar="DD/MM",
                        help="Start of date range (inclusive), e.g. 14/1")
    parser.add_argument("--to", dest="date_to", default=None, metavar="DD/MM",
                        help="End of date range (inclusive), e.g. 4/2")
    args = parser.parse_args()

    range_from = date_from_ddmm(args.date_from, args.year) if args.date_from else None
    range_to   = date_from_ddmm(args.date_to,   args.year) if args.date_to   else None

    if args.date_from and range_from is None:
        sys.exit(f"Could not parse --from date: {args.date_from!r}")
    if args.date_to and range_to is None:
        sys.exit(f"Could not parse --to date: {args.date_to!r}")

    rows_written = 0
    rows_skipped = 0

    with open(args.input, newline="", encoding="utf-8-sig") as infile, \
         open(args.output, "w", newline="", encoding="utf-8") as outfile:

        reader = csv.reader(infile)
        writer = csv.writer(outfile)
        writer.writerow(["date", "hour", "activity"])

        for line_num, row in enumerate(reader, start=1):
            if line_num == 1:
                continue  # skip header

            if not row or not row[0].strip():
                continue

            day = parse_date(row[0], args.year)
            if day is None:
                continue

            if range_from and day < range_from:
                continue
            if range_to and day > range_to:
                continue

            date_str = day.strftime("%Y-%m-%d")

            for hour in range(HOUR_COUNT):
                col_idx = HOUR_COL_START + hour
                if col_idx >= len(row):
                    break
                cell = row[col_idx].strip()
                if not cell:
                    rows_skipped += 1
                    continue
                try:
                    code = int(cell)
                except ValueError:
                    rows_skipped += 1
                    continue

                activity = MAPPING.get(code)
                if activity is None:
                    rows_skipped += 1
                    continue

                writer.writerow([date_str, hour, activity])
                rows_written += 1

    print(f"Done. {rows_written} entries written, {rows_skipped} cells skipped → {args.output}")


if __name__ == "__main__":
    main()
