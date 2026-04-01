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
║        USGS STREAMFLOW DATA PROCESSOR  ·  SIERRA NEVADA WATERSHED       ║
║        COBOL  ·  GITHUB ACTIONS CI/CD  ·  132-COLUMN REPORT OUTPUT      ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

> *"We're going to go out there and put this machine right in the path of the storm."*
> — Dr. Jo Harding, Twister (1996)

---

## April 1, 2026

At 6:35 p.m. EDT tonight, **Artemis II** lifted off from Launch Complex 39B at Kennedy Space Center — the first humans to leave low Earth orbit since Apollo 17 in 1972. Reid Wiseman, Victor Glover, Christina Koch, and Jeremy Hansen are right now riding a 322-foot rocket on a 10-day slingshot around the Moon.

Here on the ground, a COBOL program processed streamflow data for eight Sierra Nevada rivers.

Both are doing exactly what they were designed to do.

---

## The Setup

It's January 2024. An atmospheric river is churning off the Pacific. Moisture-laden air slams into the Sierra Nevada. Snow levels surge to 7,000 feet. Rivers that were barely whispering two days ago are now roaring.

Somewhere in a government data center, a program wakes up. It reads the stream gage telemetry. It crunches the numbers. It prints the report. It terminates normally.

**That program is written in COBOL.**

---

## What SIERRA-FLOW Does

SIERRA-FLOW reads USGS discharge data for **8 Sierra Nevada stream gages**, computes per-station statistics, flags threshold alerts for abnormal flow conditions, and produces a formatted 132-column report — exactly as a water resources data center might have done in 1987. Except this one compiles in 2026, runs on GitHub Actions, and auto-commits its output on every push.

```
INPUT:  streamflow.csv
        │
        ▼
  ┌─────────────────┐
  │  PARSE CSV      │  Field-by-field character parsing — no libraries
  │  VALIDATE       │  Skip blanks, non-numeric discharge values
  │  ACCUMULATE     │  Per-station sum, min, max, alert count
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │  COMPUTE STATS  │  Mean = SUM / COUNT  (per station)
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │  WRITE REPORT   │  132-column formatted output, three sections
  │  SECTION I      │  Station statistics table
  │  SECTION II     │  Threshold alert analysis
  │  SECTION III    │  Run summary
  └────────┬────────┘
           │
           ▼
OUTPUT: streamflow-report.txt  ← auto-committed by GitHub Actions
```

---

## The Gages — January 2024 Atmospheric River Event

Eight real USGS site IDs. One storm system moving through the entire watershed.

| Site ID | Station | Mean CFS | Peak CFS | Status |
|---------|---------|----------|----------|--------|
| 11427000 | American River at Fair Oaks | 2,714 | 6,100 | NORMAL |
| 11185500 | Merced River at Pohono Bridge | 1,292 | 3,100 | NORMAL |
| 11432500 | North Fork Feather River | 3,643 | 8,500 | NORMAL |
| 11230500 | San Joaquin River at Friant | 137 | 310 | ⚠ LOW READINGS |
| 11303000 | Kings River below Pine Flat Dam | 1,146 | 2,100 | NORMAL |
| 11381500 | Stony Creek near Fruto | 299 | 720 | ⚠ LOW READINGS |
| 11349000 | McCloud River above Shasta Lake | 1,320 | 2,480 | NORMAL |
| 11390000 | Sacramento River at Butte City | **17,183** | **28,000** | 🔴 HIGH FLOW |

The Sacramento at Butte City tells the whole story — all those tributaries converging on the valley floor, 28,000 CFS at peak. That's not a river gauge reading. That's a consequence.

---

## Sample Output

```
=============================================================================

         SIERRA NEVADA WATERSHED ANALYSIS SYSTEM
          USGS STREAMFLOW DATA PROCESSING REPORT
               PROCESSING DATE: 2026-04-01

=============================================================================

SECTION I: STATION STATISTICS SUMMARY

  SITE ID    STATION NAME                    RECORDS  MEAN(CFS)   MIN      MAX    ALERTS
  ──────────────────────────────────────────────────────────────────────────────────────
  11427000   American River at Fair Oaks         12    2714.88  1185.00  6100.00    2
  11185500   Merced River at Pohono Bridge        12    1292.67   298.75  3100.50    0
  11432500   North Fork Feather River             12    3643.00   798.25  8500.50    4
  11230500   San Joaquin River at Friant          12     137.17    35.25   310.50    3
  11303000   Kings River below Pine Flat Dam      12    1146.75   498.25  2100.50    0
  11381500   Stony Creek near Fruto               12     299.71    21.75   720.50    3
  11349000   McCloud River above Shasta Lake      12    1320.50   648.25  2480.50    0
  11390000   Sacramento River at Butte City       12   17183.58 10600.25 28000.50   12

SECTION II: THRESHOLD ALERT ANALYSIS

  ALERT CONDITIONS: LOW < 50 CFS  |  HIGH > 5000 CFS

  11390000   Sacramento River at Butte City    17183.58 CFS    *** HIGH FLOW ***

SECTION III: RUN SUMMARY

  STATIONS PROCESSED ..........  8
  TOTAL RECORDS READ .......... 96
  RECORDS SKIPPED (INVALID) ...  0
  TOTAL THRESHOLD ALERTS ...... 24

=============================================================================
  END OF REPORT - SIERRA NEVADA WATERSHED ANALYSIS
=============================================================================
```

---

## Why COBOL

In 1959, a team led by Grace Hopper designed a language for processing large volumes of structured records — verbose, self-documenting, and obsessively precise about data layout. They named it COBOL.

Sixty-seven years later, COBOL processes an estimated **$3 trillion in daily financial transactions**. Social Security runs COBOL. The IRS runs COBOL. Your bank almost certainly runs COBOL. It has outlived every prediction of its death because it is extremely good at exactly one thing: reading records, doing math, and printing formatted reports.

That's also what a watershed data center does.

Running COBOL in a GitHub Actions pipeline feels like putting a 1967 Ford Mustang on a modern freeway — slightly absurd, completely functional, and faster than expected.

---

## Requirements

| Item | Details |
|------|---------|
| Compiler | [GnuCOBOL](https://gnucobol.sourceforge.io/) 3.x |
| OS | Linux, macOS, Windows (MinGW or WSL) |
| Input | CSV: `site_id, site_name, measurement_date, discharge_cfs, gage_height_ft` |
| Max stations | 8 (increase `OCCURS 8 TIMES` in source to expand) |

```bash
# Ubuntu / Debian / WSL
sudo apt install gnucobol

# macOS
brew install gnucobol

# Windows — download MinGW binary from:
# https://www.arnoldtrembley.com/GnuCOBOL.htm
```

---

## Build & Run

```bash
# Compile
cobc -x -o sierra-flow SIERRA-FLOW.cob

# Run
./sierra-flow            # Linux / macOS
sierra-flow.exe          # Windows

# View report
cat streamflow-report.txt
```

---

## GitHub Actions CI/CD

On every push to `main`, the workflow installs GnuCOBOL on Ubuntu, compiles the program, runs it, and commits the updated `streamflow-report.txt` back to the repo.

```yaml
- name: Install GnuCOBOL
  run: sudo apt-get install -y gnucobol
- name: Compile
  run: cobc -x -o sierra-flow SIERRA-FLOW.cob
- name: Run
  run: ./sierra-flow
- name: Commit report
  run: git commit -m "chore: update streamflow report [skip ci]" && git push
```

---

## File Structure

```
sierra-flow-cobol/
├── SIERRA-FLOW.cob                    ← Main COBOL source
├── streamflow.csv                     ← 8 gages × 12 observations
├── streamflow-report.txt              ← Generated report (auto-updated by CI)
├── index.html                         ← GitHub Pages project site
├── Makefile                           ← build / run / clean
├── .github/
│   └── workflows/
│       └── sierra-flow-cobol.yml      ← CI pipeline
└── README.md
```

---

## Related Projects

- **[Sierra Streamflow Monitor](https://bdgroves.github.io/sierra-streamflow)** — Live dashboard, 8 USGS Sierra Nevada gages, Leaflet map, spaghetti charts
- **[EDGAR](https://bdgroves.github.io/EDGAR)** — Mariners/Rainiers baseball analytics, nightly GitHub Actions updates
- **[RIDGELINE](https://bdgroves.github.io/ridgeline)** — Phoenix WUI search & rescue call volume, 86,168 incidents 2019–2025
- **[brooksgroves.com](https://brooksgroves.com)** — Project hub

---

```
  COMPILED: 2026-04-01
  ARTEMIS II CREW: WISEMAN · GLOVER · KOCH · HANSEN — OUTBOUND TO THE MOON
  SIERRA-FLOW: NORMAL TERMINATION.  RETURN CODE: 0.
  *** END OF JOB ***
```
