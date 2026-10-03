"""Probe USGS services for sierra-flow-cobol: legacy dv/stat/site/iv and the new Water Data OGC API."""
import json, time, subprocess, urllib.request, urllib.error
H = {"User-Agent": "sierra-flow-cobol/3.0 (github.com/bdgroves/sierra-flow-cobol)", "Origin": "https://brooksgroves.com"}
SITES = "11276500,11274790,11289650,11290000,11266500,11264500,11303000,11284400"
out = {}
def t(name, url, n=3000):
    t0 = time.time()
    try:
        req = urllib.request.Request(url, headers=H)
        with urllib.request.urlopen(req, timeout=120) as r:
            b = r.read()
            out[name] = {"status": r.status, "secs": round(time.time() - t0, 1), "len": len(b), "cors": r.headers.get("Access-Control-Allow-Origin"),
                         "type": r.headers.get("Content-Type"), "ratelimit": {k: v for k, v in r.headers.items() if "ratelimit" in k.lower()}, "body": b[:n].decode("utf-8", "replace"), "tail": b[-600:].decode("utf-8", "replace")}
    except urllib.error.HTTPError as e:
        out[name] = {"status": e.code, "secs": round(time.time() - t0, 1), "body": e.read()[:1500].decode("utf-8", "replace")}
    except Exception as e:
        out[name] = {"err": str(e)[:300], "secs": round(time.time() - t0, 1)}
L = "https://waterservices.usgs.gov/nwis"
t("site", f"{L}/site/?format=rdb&sites={SITES}&siteOutput=expanded", 9000)
t("dv_30y_one", f"{L}/dv/?format=rdb&sites=11266500&parameterCd=00060&statCd=00003&startDT=1995-10-01&endDT=2026-09-30", 1500)
t("dv_30y_all", f"{L}/dv/?format=rdb&sites={SITES}&parameterCd=00060&statCd=00003&startDT=1995-10-01&endDT=2026-09-30", 800)
t("dv_recent_json", f"{L}/dv/?format=json&sites={SITES}&parameterCd=00060&statCd=00003&period=P45D", 1500)
t("stat_daily", f"{L}/stat/?format=rdb&sites=11266500&statReportType=daily&statTypeCd=p10,p25,p50,p75,p90&parameterCd=00060", 2500)
t("iv_latest", f"{L}/iv/?format=json&sites={SITES}&parameterCd=00060,00065", 1200)
A = "https://api.waterdata.usgs.gov/ogcapi/v0"
t("ogc_daily", f"{A}/collections/daily/items?f=json&monitoring_location_id=USGS-11266500&parameter_code=00060&statistic_id=00003&datetime=2026-09-01/2026-10-02&limit=50", 2500)
t("ogc_daily_30y", f"{A}/collections/daily/items?f=json&monitoring_location_id=USGS-11266500&parameter_code=00060&statistic_id=00003&datetime=1995-10-01/2026-09-30&limit=50000&properties=time,value,approval_status,qualifier&skipGeometry=true", 800)
t("ogc_latest", f"{A}/collections/latest-continuous/items?f=json&monitoring_location_id=USGS-11284400&limit=10", 2500)
t("ogc_monloc", f"{A}/collections/monitoring-locations/items/USGS-11284400?f=json", 3000)
t("ogc_collections", f"{A}/collections?f=json", 6000)
try:
    out["apt"] = subprocess.run("apt-cache policy gnucobol gnucobol3 gnucobol4 | head -30; lsb_release -a", shell=True, capture_output=True, text=True).stdout
except Exception as e:
    out["apt"] = str(e)
json.dump(out, open("tools/probe_out.json", "w"), indent=1)
