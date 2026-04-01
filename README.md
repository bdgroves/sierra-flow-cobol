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

> *"We're going to go out there and put this machine right in the path of the storm."*
> — Dr. Jo Harding, Twister (1996)

**[→ Launch the Live Dashboard](https://bdgroves.github.io/sierra-flow-cobol)**

---

## April 1, 2026

At 6:35 p.m. EDT tonight, **Artemis II** lifted off from Launch Complex 39B at Kennedy Space Center — the first humans to leave low Earth orbit since Apollo 17 in 1972. Reid Wiseman, Victor Glover, Christina Koch, and Jeremy Hansen are riding a 322-foot rocket on a 10-day slingshot around the Moon. The first woman and first person of color to travel beyond Earth orbit. The first non-American to go to the Moon's vicinity. History, plural.

Here on the ground, a COBOL program fetched live streamflow data from eight Sierra Nevada rivers, computed percent-of-normal against historical medians, sorted stations by mean discharge, rolled up watershed basin totals, and printed a 132-column formatted report.

Both are doing exactly what they were designed to do.

1959 meets 2026. Punch cards meet REST APIs. Mainframes meet GitHub Actions. **FTW.**

---

## What Makes This Cool

**The absurdist premise actually works.** COBOL — a language designed in 1959 for batch processing on machines the size of refrigerators — is fetching live government telemetry from a REST API, running in a cloud CI/CD pipeline, and feeding a modern web dashboard. That's not a novelty hack. It compiles clean, runs fast, and produces a correct report every single morning.

**It's real data, not fake data.** The numbers in this report come from actual USGS sensors sitting in rivers right now. The Merced at Pohono Bridge reading 206% of normal. The Tuolumne at Modesto rising. Big Creek near Hetch Hetchy whispering at 3 CFS, the only unregulated gage in the network — the canary in the watershed, as honest as it gets. When a storm rolls through the Sierra, you'll see it here first.

**The COBOL is legitimately sophisticated.** This isn't Hello World. Dual input files processed simultaneously. Native `SORT` verb ranking stations by mean discharge. Four-section 132-column formatted report. Baseline cache pattern solving a load-order dependency. Day-over-day trend accumulation. Per-record and per-station alert logic. Watershed basin roll-up with `EVALUATE`. This is the kind of program that runs in production at a government data center — and now it runs in yours.

**Zero dependencies, end to end.** The Python fetcher uses nothing but the standard library. The COBOL program has no external libraries. The dashboard is plain HTML, CSS, and vanilla JavaScript. No npm. No pip installs. No frameworks. No cloud bills. The entire stack runs on free infrastructure and has done so since day one.

**The live dashboard reads the same file COBOL wrote.** When the GitHub Action runs each morning, COBOL processes `streamflow.csv` and commits it back to the repo. The dashboard fetches that exact file and renders everything client-side — sparklines, percent-of-normal badges, basin roll-up, trend indicators. No separate build step. No API. One CSV file, two consumers.

**It was built and first ran on Artemis II launch day.** That's just a great detail.

---

## The Pipeline

Every morning at **7:00 AM Pacific**, GitHub Actions wakes up and runs:

```
USGS Water Services API  (free, no key, 135 years of public data)
        │
        ▼
  fetch_usgs.py                   Python 3.12 · zero pip installs · stdlib only
  8 gages · 30 days · one CSV
        │
        ▼
  SIERRA-FLOW.cob                 GnuCOBOL 3.2
  reads streamflow.csv
  reads baselines.csv
        │
        ├── Parse CSV field-by-field (no libraries)
        ├── Accumulate per-station sum, min, max, alerts
        ├── Apply historical baselines (cache pattern)
        ├── Compute mean, % of normal, 30-day trend
        ├── SORT stations by mean discharge (COBOL SORT verb)
        ├── Roll up watershed basin totals
        └── Write 132-column formatted report (4 sections)
        │
        ▼
  streamflow.csv + streamflow-report.txt   committed back to repo
        │
        ▼
  bdgroves.github.io/sierra-flow-cobol    reads CSV live · no rebuild needed
```

---

## The Eight Gages

Three watersheds. Eight sensors. One storm system moving through all of them in sequence — first hitting the headwaters, then the canyon reaches, then the valley floor — a pulse you can watch travel downstream over days.

| Site ID | Station | Watershed | What It Tells You |
|---------|---------|-----------|-------------------|
| 11276500 | Tuolumne River at Hetch Hetchy | Tuolumne | First read on headwaters below O'Shaughnessy Dam |
| 11274790 | Tuolumne River Grand Canyon | Tuolumne | Wild canyon reach before any valley influence |
| 11289650 | Tuolumne River at LaGrange Dam | Tuolumne | Last major dam — what actually enters the valley |
| 11290000 | Tuolumne River at Modesto | Tuolumne | Valley floor bottom line for Central Valley water |
| 11266500 | Merced River at Pohono Bridge | Merced | The classic Yosemite Valley gage; spectacular in flood years |
| 11264500 | Merced River at Happy Isles | Merced | Above Pohono — raw Yosemite backcountry signal |
| 11303000 | Stanislaus River at Ripon | Stanislaus | Valley floor, below New Melones Reservoir |
| 11284400 | Big Creek near Hetch Hetchy | Tuolumne | **No dams. No regulation. Pure snowmelt signal.** |

**Why Big Creek matters:** Every other gage in this network sits downstream of a major reservoir, which buffers and smooths the natural flood pulse. Big Creek has nothing between it and the sky. It responds directly and honestly to whatever the Sierra Nevada is doing. When it spikes, a storm just hit. When it drops below normal, the snowpack is struggling. It's the canary in the watershed — and COBOL flags it.

---

## Sample Report — April 1, 2026

```
=============================================================================

         SIERRA NEVADA WATERSHED ANALYSIS SYSTEM
          USGS STREAMFLOW DATA PROCESSING REPORT V2.0
               PROCESSING DATE: 2026-04-01

=============================================================================

SECTION I: STATION STATISTICS  (SORTED BY MEAN CFS)

  SITE ID    STATION NAME               REC  MEAN(CFS)  MIN      MAX   %NORM  TREND      ALERTS
  ─────────────────────────────────────────────────────────────────────────────────────────────
  11290000   Tuolumne R at Modesto       31   2059.97  318.00 3110.00  147.1  ▲ RISING       0
  11289650   Tuolumne R at LaGrange Dam  31   1872.84  226.00 3070.00  156.1  ▲ RISING       0
  11266500   Merced R at Pohono Bridge   31   1647.32  729.00 2780.00  205.9  ─ STABLE       0
  11274790   Tuolumne R Grand Canyon     31   1361.68  465.00 2350.00  151.3  ─ STABLE       0
  11264500   Merced R at Happy Isles     31    932.68  343.00 1650.00  207.3  ─ STABLE       0
  11276500   Tuolumne R at Hetch Hetchy  31    443.55  127.00 3400.00  126.7  ─ STABLE       0
  11303000   Stanislaus R at Ripon       31    243.55  177.00  746.00   40.6  ─ STABLE       0
  11284400   Big Creek nr Hetch Hetchy   31      3.09    1.36    9.53   38.6  ─ STABLE      31

SECTION II: ALERT & PERCENT-OF-NORMAL ANALYSIS

  11266500   Merced R at Pohono Bridge  1647.32   800.00  205.9%   ABOVE NORMAL
  11264500   Merced R at Happy Isles     932.68   450.00  207.3%   ABOVE NORMAL
  11303000   Stanislaus R at Ripon       243.55   600.00   40.6%   BELOW NORMAL
  11284400   Big Creek nr Hetch Hetchy     3.09     8.00   38.6%   *** LOW FLOW ***

SECTION III: WATERSHED BASIN ROLL-UP

  TUOLUMNE       5 stations    5741.13 CFS total mean
  MERCED         2 stations    2580.00 CFS total mean
  STANISLAUS     1 station      243.55 CFS total mean

SECTION IV: RUN SUMMARY

  STATIONS PROCESSED ..........  8
  TOTAL RECORDS READ .......... 248
  RECORDS SKIPPED (INVALID) ...  0
  TOTAL THRESHOLD ALERTS ......  31
  WATERSHED BASINS ANALYZED ...  3
```

---

## COBOL Features

| Feature | How It Works |
|---------|-------------|
| **Dual input files** | `streamflow.csv` + `baselines.csv` read with separate FD entries and FILE-CONTROL assignments |
| **Percent of normal** | `COMPUTE ST-PCT-NORMAL = (ST-MEAN / ST-MEDIAN) * 100` — flags above/below normal conditions |
| **Trend analysis** | Accumulates day-over-day discharge delta across 30 readings → `▲ RISING` / `▼ FALLING` / `─ STABLE` |
| **COBOL SORT verb** | `SORT SORT-FILE DESCENDING KEY SR-MEAN INPUT PROCEDURE / OUTPUT PROCEDURE` — stations ranked by mean CFS |
| **Watershed basin roll-up** | `EVALUATE WS-SITE-ID` assigns each gage to Tuolumne / Merced / Stanislaus; basin table accumulates totals |
| **Baseline cache pattern** | Baselines load before stations register — cached in `WS-BL-CACHE`, applied in `3500-APPLY-BASELINES` after streamflow processing |
| **Four-section report** | 132-column fixed-width output matching classic mainframe report standards |
| **Alert engine** | Per-record threshold check during accumulation + per-station % of normal classification in report |

---

## Requirements

| Item | Details |
|------|---------|
| COBOL compiler | [GnuCOBOL](https://gnucobol.sourceforge.io/) 3.x |
| Python | 3.9+ · zero external dependencies · stdlib only |
| OS | Linux, macOS, Windows (WSL or MinGW) |
| Data source | [USGS Water Services API](https://waterservices.usgs.gov/) — free, public, no key required |

```bash
# Ubuntu / Debian / WSL
sudo apt install gnucobol

# macOS
brew install gnucobol

# Windows — download MinGW binary from:
# https://www.arnoldtrembley.com/GnuCOBOL.htm
# Run set_env.cmd before compiling
```

---

## Build & Run

```bash
# 1. Fetch 30 days of live USGS discharge data
python3 fetch_usgs.py

# 2. Compile
cobc -x -o sierra-flow SIERRA-FLOW.cob

# 3. Run
./sierra-flow            # Linux / macOS
sierra-flow.exe          # Windows

# 4. View report
cat streamflow-report.txt

# Or: make  (runs all three steps)
```

---

## GitHub Actions CI/CD

Runs daily at **7:00 AM Pacific** (14:00 UTC), on every push, and on demand:

```yaml
on:
  schedule:
    - cron: '0 14 * * *'
  push:
    branches: [ main ]
  workflow_dispatch:
```

The workflow installs GnuCOBOL on Ubuntu, fetches fresh USGS data, compiles, runs, and commits `streamflow.csv` + `streamflow-report.txt` back to the repo. The dashboard updates automatically on the next page load — no deploy step, no rebuild.

---

## File Structure

```
sierra-flow-cobol/
├── SIERRA-FLOW.cob                    ← Main COBOL source (~850 lines)
├── fetch_usgs.py                      ← USGS API fetcher (stdlib only)
├── baselines.csv                      ← Historical medians + alert thresholds
├── streamflow.csv                     ← Live data (updated daily by CI)
├── streamflow-report.txt              ← 132-col COBOL report (updated daily)
├── index.html                         ← Live dashboard (reads CSV client-side)
├── Makefile                           ← fetch / build / run / clean
├── pixi.toml                          ← Python environment (pixi)
├── .github/
│   └── workflows/
│       └── sierra-flow-cobol.yml      ← Daily CI pipeline
└── README.md
```

---

## Why COBOL

In 1959, a committee led by Grace Hopper designed a language for processing large volumes of structured records. They made it verbose, self-documenting, and obsessively precise about data layout. They named it COBOL.

Sixty-seven years later, COBOL processes an estimated **$3 trillion in daily financial transactions**. The IRS runs COBOL. Social Security runs COBOL. Your bank almost certainly runs COBOL. It has outlived every prediction of its death — not because people are sentimental, but because it is extremely good at exactly one thing: reading records, doing math, and printing formatted reports.

That's also what a watershed data center does.

Running COBOL in a GitHub Actions pipeline in 2026 feels like putting a 1959 IBM 1401 on the internet. Slightly absurd. Completely functional. Faster than you expected. And on the day Artemis II went to the Moon, this program terminated normally with return code zero.

---

## Related Projects

- **[Sierra Streamflow Monitor](https://bdgroves.github.io/sierra-streamflow)** — Live dashboard tracking the same 8 USGS gages with 20-year spaghetti charts and a Leaflet map. The spiritual predecessor to this project.
- **[EDGAR](https://bdgroves.github.io/EDGAR)** — Mariners/Rainiers baseball analytics dashboard, updated nightly via GitHub Actions.
- **[RIDGELINE](https://bdgroves.github.io/ridgeline)** — Phoenix WUI search & rescue call volume analysis. 86,168 Phoenix Fire Department incidents, 2019–2025.
- **[brooksgroves.com](https://brooksgroves.com)** — Project hub.

---

```
  COMPILED ON ARTEMIS II LAUNCH DAY  ·  2026-04-01
  CREW: WISEMAN · GLOVER · KOCH · HANSEN — OUTBOUND TO THE MOON
  SIERRA-FLOW V2.0: NORMAL TERMINATION.  RETURN CODE: 0.
  *** END OF JOB ***
```
