"""Run the new fetcher in Actions and publish its outputs for local testing."""
import json, shutil, subprocess
log = {}
for args in (["--history"], []):
    p = subprocess.run(["python3", "fetch_usgs.py", *args], capture_output=True, text=True)
    log[" ".join(args) or "recent"] = {"rc": p.returncode, "out": p.stdout[-4000:], "err": p.stderr[-2000:]}
for f in ("history.csv", "streamflow.csv"):
    try:
        shutil.copy(f, f"tools/probe_out_{f}")
    except FileNotFoundError:
        pass
json.dump(log, open("tools/probe_out.json", "w"), indent=1)
