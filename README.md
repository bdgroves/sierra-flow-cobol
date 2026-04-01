```
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║   ░██████╗██╗███████╗██████╗ ██████╗  █████╗       ███████╗██╗          ║
║   ██╔════╝██║██╔════╝██╔══██╗██╔══██╗██╔══██╗      ██╔════╝██║          ║
║   ╚█████╗ ██║█████╗  ██████╔╝██████╔╝███████║ ███╗ █████╗  ██║          ║
║    ╚═══██╗██║██╔══╝  ██╔══██╗██╔══██╗██╔══██║ ╚══╝ ██╔══╝  ██║          ║
║   ██████╔╝██║███████╗██║  ██║██║  ██║██║  ██║      ██║     ███████╗     ║
║   ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝     ╚══════╝    ║
║                                                                          ║
║   USGS STREAMFLOW DATA PROCESSOR  v2.0  ·  SIERRA NEVADA WATERSHED      ║
║   COBOL  ·  LIVE USGS API  ·  GITHUB ACTIONS  ·  132-COLUMN REPORT      ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

> *"We're going to go out there and put this machine right in the path of the storm."*
> — Dr. Jo Harding, Twister (1996)

---

## April 1, 2026

At 6:35 p.m. EDT tonight, **Artemis II** lifted off from Launch Complex 39B at Kennedy Space Center — the first humans to leave low Earth orbit since Apollo 17 in 1972. Reid Wiseman, Victor Glover, Christina Koch, and Jeremy Hansen are riding a 322-foot rocket on a 10-day slingshot around the Moon.

Here on the ground, a COBOL program fetched live streamflow data from eight Sierra Nevada rivers, computed percent-of-normal against historical medians, sorted stations by mean discharge, rolled up watershed basin totals, and printed a 132-column formatted report.

Both are doing exactly what they were designed to do.

---

## What It Does

Every morning at 7AM Pacific, GitHub Actions:

1. Runs `fetch_usgs.py` — hits the USGS Water Services API, pulls 30 days of discharge for 8 gages, writes `streamflow.csv`
2. Compiles and runs `SIERRA-FLOW.cob` — processes the CSV, computes stats, writes `streamflow-report.txt`
3. Commits both files back to the repo

The [live dashboard](https://bdgroves.github.io/sierra-flow-cobol) reads `streamflow.csv` directly and renders everything in the browser — no rebuild needed.

```
USGS Water Services API
        │
        ▼
  fetch_usgs.py          ← Python, zero dependencies, stdlib only
  writes streamflow.csv
        │
        ▼
  SIERRA-FLOW.cob        ← GnuCOBOL 3.2
  reads streamflow.csv + baselines.csv
        │
        ├── SORT by mean discharge (COBOL SORT verb)
        ├── % of normal vs historical median
        ├── 30-day trend (RISING / FALLING / STABLE)
        ├── Watershed basin roll-up
        └── 132-column formatted report
        │
        ▼
  streamflow-report.txt + streamflow.csv  ← committed daily
        │
        ▼
  index.html  ← reads CSV live, renders dashboard in browser
```

---

## The Eight Gages — Tuolumne, Merced & Stanislaus Watersheds

| Site ID | Station | Watershed | What It Tells You |
|---------|---------|-----------|-------------------|
| 11276500 | Tuolumne River at Hetch Hetchy | Tuolumne | Headwater signal below O'Shaughnessy Dam |
| 11274790 | Tuolumne River Grand Canyon | Tuolumne | Wild canyon reach, pre-valley influence |
| 11289650 | Tuolumne River at LaGrange Dam | Tuolumne | Last major dam — what enters the valley |
| 11290000 | Tuolumne River at Modesto | Tuolumne | Valley floor bottom line |
| 11266500 | Merced River at Pohono Bridge | Merced | Classic Yosemite Valley gage |
| 11264500 | Merced River at Happy Isles | Merced | Raw Yosemite backcountry signal |
| 11303000 | Stanislaus River at Ripon | Stanislaus | Valley floor, below New Melones |
| 11284400 | Big Creek near Hetch Hetchy | Tuolumne | Unregulated — the canary in the watershed |

---

## COBOL Features

| Feature | Implementation |
|---------|---------------|
| Dual input files | `streamflow.csv` + `baselines.csv` processed simultaneously |
| Percent of normal | Mean / historical median × 100, per station |
| Trend analysis | Day-over-day delta accumulation → RISING / FALLING / STABLE |
| SORT verb | Native COBOL `SORT` ranks stations by mean discharge descending |
| Basin roll-up | `EVALUATE` assigns watershed, accumulates totals |
| Baseline cache | Load-then-apply pattern solves file ordering dependency |
| Multi-section report | Four sections, 132-column formatted output |
| Alert engine | Per-record threshold check + per-station % of normal flags |

---

## Requirements

| Item | Details |
|------|---------|
| COBOL compiler | [GnuCOBOL](https://gnucobol.sourceforge.io/) 3.x |
| Python | 3.9+ (stdlib only — zero pip installs) |
| OS | Linux, macOS, Windows (WSL or MinGW) |
| Data source | [USGS Water Services API](https://waterservices.usgs.gov/) — free, no key |

```bash
# Ubuntu / Debian / WSL
sudo apt install gnucobol

# macOS
brew install gnucobol

# Windows: download MinGW binary from arnoldtrembley.com/GnuCOBOL.htm
# Run set_env.cmd before compiling
```

---

## Build & Run

```bash
# 1. Fetch live USGS data
python3 fetch_usgs.py

# 2. Compile
cobc -x -o sierra-flow SIERRA-FLOW.cob

# 3. Run
./sierra-flow            # Linux / macOS
sierra-flow.exe          # Windows

# 4. View report
cat streamflow-report.txt

# Or just: make
```

---

## GitHub Actions CI/CD

Runs daily at **7:00 AM Pacific** (14:00 UTC) and on every push:

```yaml
on:
  schedule:
    - cron: '0 14 * * *'
  push:
    branches: [ main ]
  workflow_dispatch:
```

Steps: install GnuCOBOL → fetch USGS data → compile → run → commit `streamflow.csv` + `streamflow-report.txt`.

---

## File Structure

```
sierra-flow-cobol/
├── SIERRA-FLOW.cob                    ← Main COBOL source (~850 lines)
├── fetch_usgs.py                      ← USGS API fetcher (stdlib only)
├── baselines.csv                      ← Historical medians + thresholds
├── streamflow.csv                     ← Live data (updated daily by CI)
├── streamflow-report.txt              ← COBOL report (updated daily by CI)
├── index.html                         ← Live dashboard (reads CSV client-side)
├── Makefile                           ← fetch / build / run / clean
├── pixi.toml                          ← Python environment
├── .github/
│   └── workflows/
│       └── sierra-flow-cobol.yml      ← CI pipeline
└── README.md
```

---

## Why COBOL

In 1959, a team led by Grace Hopper designed a language for processing large volumes of structured records — verbose, self-documenting, and obsessively precise about data layout.

Sixty-seven years later, COBOL processes an estimated **$3 trillion in daily financial transactions**. The IRS runs COBOL. Social Security runs COBOL. Your bank almost certainly runs COBOL. It outlives every prediction of its death because it is extremely good at reading records, doing math, and printing formatted reports.

That's also what a watershed data center does.

---

## Related Projects

- **[Sierra Streamflow Monitor](https://bdgroves.github.io/sierra-streamflow)** — Live dashboard, same 8 USGS gages, 20-year spaghetti charts, Leaflet map
- **[EDGAR](https://bdgroves.github.io/EDGAR)** — Mariners/Rainiers baseball analytics, nightly GitHub Actions updates
- **[RIDGELINE](https://bdgroves.github.io/ridgeline)** — Phoenix WUI search & rescue, 86,168 incidents 2019–2025
- **[brooksgroves.com](https://brooksgroves.com)** — Project hub

---

```
  COMPILED ON ARTEMIS II LAUNCH DAY
  ARTEMIS II CREW: WISEMAN · GLOVER · KOCH · HANSEN — OUTBOUND TO THE MOON
  SIERRA-FLOW V2.0: NORMAL TERMINATION.  RETURN CODE: 0.
  *** END OF JOB ***
```
