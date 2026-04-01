```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║        ███████╗██╗███████╗██████╗ ██████╗  █████╗        ███████╗██╗        ║
║        ██╔════╝██║██╔════╝██╔══██╗██╔══██╗██╔══██╗       ██╔════╝██║        ║
║        ███████╗██║█████╗  ██████╔╝██████╔╝███████║▄█╗    █████╗  ██║        ║
║        ╚════██║██║██╔══╝  ██╔══██╗██╔══██╗██╔══██║██║    ██╔══╝  ██║        ║
║        ███████║██║███████╗██║  ██║██║  ██║██║  ██║╚█║    ██║     ███████╗   ║
║        ╚══════╝╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚╝   ╚═╝     ╚══════╝   ║
║                                                                              ║
║            SIERRA NEVADA WATERSHED ANALYSIS SYSTEM  //  COBOL               ║
║                                                                              ║
║            USGS STREAMFLOW DATA PROCESSOR  ·  REPORT GENERATOR              ║
║            THRESHOLD ALERT ENGINE  ·  STATISTICAL SUMMARY MODULE            ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

> *What if the Western Regional Technical Service Center ran their streamflow 
> analysis in 1987 — and the code was still running today?*

---

## PROGRAM DESCRIPTION

**SIERRA-FLOW** is a COBOL program that ingests USGS stream gage discharge data
in CSV format, computes per-station statistics, flags threshold alerts for
abnormal flow conditions, and produces a formatted columnar report — exactly
as a water resources data center might have done four decades ago.

This project is a love letter to verbose, self-documenting, structured code
that runs on metal and doesn't apologize for it.

---

## WHAT IT DOES

```
INPUT:  streamflow.csv      ← USGS gage discharge records
           │
           ▼
    ┌─────────────────┐
    │  PARSE CSV      │  Field-by-field character parsing
    │  VALIDATE       │  Skip blanks, non-numeric discharge
    │  ACCUMULATE     │  Per-station sum, min, max, alert count
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  COMPUTE STATS  │  Mean = SUM / COUNT (per station)
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  WRITE REPORT   │  Three sections, 132-column format
    │                 │
    │  SECTION I   ── │  Station statistics table
    │  SECTION II  ── │  Threshold alert analysis
    │  SECTION III ── │  Run summary (records, alerts, skips)
    └────────┬────────┘
             │
             ▼
OUTPUT: streamflow-report.txt
```

**Alert thresholds** (configurable in WORKING-STORAGE):

| Condition  | Trigger           |
|------------|-------------------|
| LOW FLOW   | discharge < 50 CFS |
| HIGH FLOW  | discharge > 5,000 CFS |

---

## SAMPLE OUTPUT

```
================================================================================
=====================================

                           SIERRA NEVADA WATERSHED ANALYSIS SYSTEM

                            USGS STREAMFLOW DATA PROCESSING REPORT

                                     PROCESSING DATE: 2026-03-22

================================================================================
=====================================

SECTION I: STATION STATISTICS SUMMARY

  SITE ID         STATION NAME                       RECORDS  MEAN (CFS)   MIN (CFS)   MAX (CFS)  ALERTS  LAST DATE   LAST (CFS)
  -----------------------------------------------------------------------...
  11427000        American River at Fair Oaks              12   2881.46    1185.00    6100.00       2  2024-01-12    1420.75
  11185500        Merced River at Pohono Bridge            12   1292.75     298.75    3100.50       0  2024-01-12     410.75
  11432500        North Fork Feather River                 12   3876.46     798.25    8500.50       4  2024-01-12    1350.25
  ...

SECTION II: THRESHOLD ALERT ANALYSIS

  ALERT CONDITIONS: LOW < 50 CFS | HIGH > 5000 CFS

  SITE ID         STATION NAME                        MEAN (CFS)  LOW THRESH  HIGH THRESH  ALERT STATUS
  11427000        American River at Fair Oaks           2881.46      50.00     5000.00  NORMAL
  11230500        San Joaquin River at Friant            113.42      50.00     5000.00  *** LOW FLOW ***
  ...
```

---

## REQUIREMENTS

| Requirement   | Details                                      |
|---------------|----------------------------------------------|
| Compiler      | [GnuCOBOL](https://gnucobol.sourceforge.io/) 3.x or later |
| OS            | Linux, macOS, Windows (WSL recommended)      |
| Input         | CSV with columns: `site_id, site_name, measurement_date, discharge_cfs, gage_height_ft` |
| Max stations  | 8 (increase `OCCURS 8 TIMES` in source to expand) |

### Install GnuCOBOL

```bash
# Ubuntu / Debian / WSL
sudo apt install gnucobol

# macOS
brew install gnucobol

# Verify
cobc --version
```

---

## BUILD & RUN

```bash
# Clone
git clone https://github.com/bdgroves/sierra-flow-cobol
cd sierra-flow-cobol

# Check compiler is available
make check

# Compile + run in one step
make

# Or separately:
make build          # → produces ./sierra-flow binary
make run            # → reads streamflow.csv, writes streamflow-report.txt

# Clean up
make clean
```

**Compile manually:**
```bash
cobc -x -free -o sierra-flow SIERRA-FLOW.cob
./sierra-flow
cat streamflow-report.txt
```

---

## FILE STRUCTURE

```
sierra-flow-cobol/
├── SIERRA-FLOW.cob          ← Main COBOL source
├── streamflow.csv           ← Sample data (8 Sierra Nevada gages)
├── streamflow-report.txt    ← Generated report (after running)
├── Makefile                 ← Build automation
└── README.md
```

---

## DATA FORMAT

The program expects a CSV with a header row followed by records:

```
site_id,site_name,measurement_date,discharge_cfs,gage_height_ft
11427000,American River at Fair Oaks,2024-01-01,1240.50,8.21
```

Real USGS data can be exported from the
[USGS National Water Information System](https://waterdata.usgs.gov/nwis).
The included `streamflow.csv` uses real site IDs with synthetic but
hydrologically plausible discharge values.

---

## COBOL STRUCTURE

```
IDENTIFICATION DIVISION   Program metadata
ENVIRONMENT DIVISION      File assignments (INPUT / OUTPUT)
DATA DIVISION
  FILE SECTION            FD records for CSV and report files
  WORKING-STORAGE         All variables, accumulators, report lines
PROCEDURE DIVISION
  0000-MAIN               Orchestrates all paragraphs
  1000-INITIALIZE         Opens files, captures run date
  2000-PROCESS-FILE       Main read loop
    2100-PROCESS-RECORD   Route header vs. data records
    2200-PARSE-CSV        Character-by-character field splitter
    2300-VALIDATE-RECORD  Skip blanks and non-numeric values
    2400-ACCUMULATE       Per-station aggregation + alert counting
  3000-COMPUTE-STATS      Divide SUM/COUNT for mean per station
  4000-WRITE-REPORT       Drives all report sections
    4100-WRITE-BANNER     Title block with processing date
    4200-WRITE-STATION-TABLE   Section I: stats
    4300-WRITE-ALERT-SECTION   Section II: thresholds
    4400-WRITE-SUMMARY    Section III: run totals
    4500-WRITE-FOOTER     Closing banner
  9000-TERMINATE          Close files, print completion message
```

---

## EXTENDING THE PROGRAM

| Goal | Change |
|------|--------|
| More stations | Increase `OCCURS 8 TIMES` in `WS-STATION-TABLE` |
| Custom thresholds | Modify `ST-ALERT-LOW-THRESH` / `ST-ALERT-HIGH-THRESH` initial values |
| Different input file | Change `WS-INPUT-FILE` VALUE clause |
| Print to stdout | Replace `REPORT-FILE` FD with `DISPLAY` statements |

---

## WHY COBOL

COBOL processes an estimated **$3 trillion** in daily financial transactions.
The Social Security Administration runs COBOL. The IRS runs COBOL. Your bank
almost certainly runs COBOL. It is a language that has outlived every prediction
of its death, because it is extremely good at exactly one thing: reliably
processing large volumes of structured records and producing formatted reports.

That's also what a watershed data center does.

---

## RELATED PROJECTS

- [Sierra Streamflow Monitor](https://bdgroves.github.io/sierra-streamflow) — Live dashboard tracking 8 USGS gages with Leaflet map and sparklines
- [Rainier Snowpack](https://github.com/bdgroves/rainier-snowpack) — Automated snowpack visualization via GitHub Actions

---

```
  NORMAL TERMINATION. RETURN CODE: 0.
  *** END OF JOB ***
```
