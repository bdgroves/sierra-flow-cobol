#!/usr/bin/env python3
"""
fetch_usgs.py
Fetches current USGS streamflow discharge data for 8 Sierra Nevada gages
and writes streamflow.csv for processing by SIERRA-FLOW.cob

Site IDs verified from Sierra Streamflow Monitor (bdgroves.github.io/sierra-streamflow)
USGS Water Services API - no API key required
"""

import urllib.request
import json
import csv
import sys
from datetime import datetime, timezone

# 8 verified active USGS gages - Tuolumne, Merced, Stanislaus watersheds
SITES = [
    ("11276500", "Tuolumne River at Hetch Hetchy"),
    ("11274790", "Tuolumne River Grand Canyon"),
    ("11289650", "Tuolumne River at LaGrange Dam"),
    ("11290000", "Tuolumne River at Modesto"),
    ("11266500", "Merced River at Pohono Bridge"),
    ("11264500", "Merced River at Happy Isles"),
    ("11303000", "Stanislaus River at Ripon"),
    ("11284400", "Big Creek near Hetch Hetchy"),
]

PARAM_DISCHARGE = "00060"
PARAM_GAGE_HT   = "00065"
OUTPUT_FILE = "streamflow.csv"
DAYS_BACK = 30


def fetch_usgs_data(site_id, site_name):
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

    for dt_str, discharge_val in sorted(discharge_map.items()):
        try:
            discharge = float(discharge_val)
            if discharge < 0:
                continue
        except (ValueError, TypeError):
            continue

        meas_date = dt_str[:10]
        gage_ht_val = gage_ht_map.get(dt_str, "")
        try:
            gage_ht = round(float(gage_ht_val), 2) if gage_ht_val else ""
        except (ValueError, TypeError):
            gage_ht = ""

        records.append({
            "site_id":          site_id,
            "site_name":        site_name,
            "measurement_date": meas_date,
            "discharge_cfs":    round(discharge, 2),
            "gage_height_ft":   gage_ht,
        })

    # One reading per day (last of day wins)
    daily = {}
    for r in records:
        daily[r["measurement_date"]] = r
    records = sorted(daily.values(), key=lambda x: x["measurement_date"])
    print(f"{len(records)} records")
    return records


def write_csv(all_records):
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
        print(f"WARNING: No data for sites: {', '.join(failed)}")

    print("Fetch complete. Ready for SIERRA-FLOW.")


if __name__ == "__main__":
    main()
