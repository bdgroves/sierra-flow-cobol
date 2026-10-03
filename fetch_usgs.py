#!/usr/bin/env python3
"""
fetch_usgs.py - feeds the COBOL batch.

Reads the eight gages from sites.csv and asks the USGS Water Data API
(api.waterdata.usgs.gov, OGC API, free, no key) for daily mean discharge.

  python3 fetch_usgs.py              -> streamflow.csv   last 60 complete days
  python3 fetch_usgs.py --history    -> history.csv      water years 1996-2025,
                                                         input for NORMALS.cob

Daily means are what USGS publishes as the day's flow (statistic 00003), so
nothing here picks a reading out of the day. Today's partial day is left out.
If a gage doesn't answer, its rows from the previous streamflow.csv are kept,
and SIERRA-FLOW flags them as stale. Standard library only.
"""

import csv
import json
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

API = "https://api.waterdata.usgs.gov/ogcapi/v0/collections/daily/items"
UA = {"User-Agent": "sierra-flow-cobol/3.0 (github.com/bdgroves/sierra-flow-cobol)"}
DAYS_BACK = 60
HIST_START, HIST_END = "1995-10-01", "2025-09-30"     # water years 1996-2025


def sites():
    with open("sites.csv", newline="", encoding="utf-8") as f:
        return [(r["site_id"], r["short_name"]) for r in csv.DictReader(f)]


def daily(site_id, start, end):
    """Daily mean discharge for one gage as {date: cfs}. Retries; None if USGS won't answer."""
    q = (f"{API}?f=json&monitoring_location_id=USGS-{site_id}&parameter_code=00060"
         f"&statistic_id=00003&datetime={start}/{end}&limit=50000"
         f"&properties=time,value,approval_status&skipGeometry=true")
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(q, headers=UA), timeout=90) as r:
                feats = json.loads(r.read().decode("utf-8")).get("features", [])
            out = {}
            for ft in feats:
                p = ft.get("properties", {})
                try:
                    v = float(p.get("value"))
                except (TypeError, ValueError):
                    continue
                if v >= 0:
                    out[p["time"][:10]] = (v, (p.get("approval_status") or "")[:1])
            return out
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            print(f"    attempt {attempt + 1}: {e}")
            time.sleep(5 * (attempt + 1))
    return None


def previous_rows():
    try:
        with open("streamflow.csv", newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        return rows if rows and "date" in rows[0] else []
    except FileNotFoundError:
        return []


def recent():
    today = datetime.now(ZoneInfo("America/Los_Angeles")).date()
    start = (today - timedelta(days=DAYS_BACK)).isoformat()
    end = (today - timedelta(days=1)).isoformat()
    old = previous_rows()
    rows, failed = [], []
    for sid, name in sites():
        print(f"  {sid}  {name:<28}", end=" ", flush=True)
        d = daily(sid, start, end)
        if d is None:
            kept = [r for r in old if r["site_id"] == sid]
            rows += kept
            failed.append(sid)
            print(f"NO ANSWER - kept {len(kept)} rows from the last run")
            continue
        days = sorted(k for k in d if k < today.isoformat())
        rows += [{"site_id": sid, "date": k, "cfs": f"{d[k][0]:.2f}", "approval": d[k][1]} for k in days]
        print(f"{len(days)} days, last {days[-1] if days else '-'}")
    if not rows:
        sys.exit("No data from USGS and nothing to keep. Stopping.")
    with open("streamflow.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["site_id", "date", "cfs", "approval"], lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {len(rows)} daily means to streamflow.csv" + (f"; no answer from {', '.join(failed)}" if failed else ""))


def history():
    n = 0
    with open("history.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["site_id", "date", "cfs"])
        for sid, name in sites():
            d = daily(sid, HIST_START, HIST_END)
            if d is None:
                sys.exit(f"No history for {sid}; normals not rebuilt.")
            for k in sorted(d):
                w.writerow([sid, k, f"{d[k][0]:.2f}"])
            n += len(d)
            print(f"  {sid}  {name:<28} {len(d):>6} days  {min(d)} to {max(d)}")
    print(f"Wrote {n} daily means to history.csv")


if __name__ == "__main__":
    print(f"SIERRA-FLOW USGS FETCH  {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC")
    history() if "--history" in sys.argv else recent()
