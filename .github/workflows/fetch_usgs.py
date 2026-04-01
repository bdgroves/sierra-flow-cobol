#!/usr/bin/env python3
"""
fetch_usgs.py
Fetches current USGS streamflow discharge data for 8 Sierra Nevada gages
and writes streamflow.csv for processing by SIERRA-FLOW.cob

USGS Water Services API - no API key required
https://waterservices.usgs.gov/rest/iv-service.html
"""

import urllib.request
import json
import csv
import sys
from datetime import datetime, timezone

# 8 Sierra Nevada USGS gage site IDs and friendly names
SITES = [
    ("11427000", "American River at Fair Oaks"),
    ("11185500", "Merced River at Pohono Bridge"),
    ("11432500", "North Fork Feather River"),
    ("11230500", "San Joaquin River at Friant"),
    ("11303000", "Kings River below Pine Flat Dam"),
    ("11381500", "Stony Creek near Fruto"),
    ("11349000", "McCloud River above Shasta Lake"),
    ("11390000", "Sacramento River at Butte City"),
]

# USGS parameter code for discharge (streamflow) in CFS
PARAM_DISCHARGE = "00060"
# USGS parameter code for gage height in feet
PARAM_GAGE_HT   = "00065"

OUTPUT_FILE = "streamflow.csv"
# Number of days of historical data to fetch (keep last N days)
DAYS_BACK = 30


def fetch_usgs_data(site_id, site_name):
    """Fetch recent discharge and gage height for a single site."""
    url = (
        f"https://waterservices.usgs.gov/nwis/iv/"
        f"?format=json"
        f"&sites={site_id}"
        f"&parameterCd={PARAM_DISCHARGE},{PARAM_GAGE_HT}"
        f"&period=P{DAYS_BACK}D"
        f"&siteStatus=active"
    )

    print(f"  Fetching {site_id} - {site_name}...", end=" ")

    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "sierra-flow-cobol/2.0 (github.com/bdgroves/sierra-flow-cobol)"}
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
    except Exception as e:
        print(f"ERROR: {e}")
        return []

    records = []
    time_series = data.get("value", {}).get("timeSeries", [])

    # Build lookup: param_code -> list of (datetime, value)
    param_data = {}
    for ts in time_series:
        variable = ts.get("variable", {})
        param_code = variable.get("variableCode", [{}])[0].get("value", "")
        values = ts.get("values", [{}])[0].get("value", [])
        param_data[param_code] = {
            v["dateTime"]: v["value"]
            for v in values
            if v.get("value") not in (None, "", "-999999")
        }

    discharge_map = param_data.get(PARAM_DISCHARGE, {})
    gage_ht_map   = param_data.get(PARAM_GAGE_HT, {})

    # Align on discharge timestamps
    for dt_str, discharge_val in sorted(discharge_map.items()):
        try:
            discharge = float(discharge_val)
            if discharge < 0:
                continue
        except (ValueError, TypeError):
            continue

        # Parse date portion only (YYYY-MM-DD)
        meas_date = dt_str[:10]

        # Get gage height if available for same timestamp
        gage_ht_val = gage_ht_map.get(dt_str, "")
        try:
            gage_ht = round(float(gage_ht_val), 2) if gage_ht_val else ""
        except (ValueError, TypeError):
            gage_ht = ""

        records.append({
            "site_id":       site_id,
            "site_name":     site_name,
            "measurement_date": meas_date,
            "discharge_cfs": round(discharge, 2),
            "gage_height_ft": gage_ht,
        })

    # Deduplicate: keep one reading per day (last of day wins)
    daily = {}
    for r in records:
        daily[r["measurement_date"]] = r
    records = sorted(daily.values(), key=lambda x: x["measurement_date"])

    print(f"{len(records)} records")
    return records


def write_csv(all_records):
    """Write all records to streamflow.csv."""
    fieldnames = ["site_id", "site_name", "measurement_date", "discharge_cfs", "gage_height_ft"]
    with open(OUTPUT_FILE, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_records)
    print(f"\nWrote {len(all_records)} records to {OUTPUT_FILE}")


def main():
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    print(f"SIERRA-FLOW USGS FETCH  //  {now}")
    print(f"Fetching last {DAYS_BACK} days for {len(SITES)} sites...\n")

    all_records = []
    failed = []

    for site_id, site_name in SITES:
        records = fetch_usgs_data(site_id, site_name)
        if records:
            all_records.extend(records)
        else:
            failed.append(site_id)

    if not all_records:
        print("ERROR: No data fetched. Exiting.")
        sys.exit(1)

    write_csv(all_records)

    if failed:
        print(f"WARNING: No data returned for sites: {', '.join(failed)}")
        print("COBOL will process available sites only.")

    print("Fetch complete. Ready for SIERRA-FLOW.")


if __name__ == "__main__":
    main()
