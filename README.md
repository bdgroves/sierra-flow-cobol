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
║   USGS STREAMFLOW DATA PROCESSOR  v3.0  ·  SIERRA NEVADA WATERSHED      ║
║   GNUCOBOL  ·  USGS WATER DATA API  ·  GITHUB ACTIONS  ·  132 COLUMNS   ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

> *"We're going to go out there and put this machine right in the path of the storm."*
> — Dr. Jo Harding, Twister (1996)

**[→ The live page: brooksgroves.com/sierra-flow-cobol](https://brooksgroves.com/sierra-flow-cobol/)**

Eight USGS river gages on the Tuolumne, Merced and Stanislaus, run every morning through a COBOL batch job. Two GnuCOBOL programs do the work: **NORMALS** builds what each river normally does on each day of the year from 30 years of USGS records, using the `SORT` verb on about 584,000 records, and **SIERRA-FLOW** compares the latest daily flow with the normal for its date and prints a 132-column report. The page shows that report on green-bar paper, the job log from the run, 60-day hydrographs against the normal band, and both programs as IBM 029 punch cards.

Version 1 first ran on April 1, 2026, the evening Artemis II lifted off from Launch Complex 39B (6:35 p.m. EDT) with Reid Wiseman, Victor Glover, Christina Koch and Jeremy Hansen aboard.

---

## The batch job

Every morning at 14:17 UTC (7:17 a.m. PDT; GitHub often starts scheduled jobs later), GitHub Actions runs `run_job.sh` on Ubuntu 24.04:

```
STEP FETCH     python3 fetch_usgs.py          USGS daily means, last 60 days  → streamflow.csv
STEP COMPILE   cobc -x SIERRA-FLOW.cob        GnuCOBOL 3.1.2
STEP NORMALS   ./normals                      only when normals.csv is missing or asked for
STEP SIERRAFL  ./sierra-flow                  → streamflow-report.txt, results.csv
```

Each step's output, return code and time go into `job-log.txt`. The job stops on a return code of 8 or more, like a mainframe step with `COND=(8,LE)`. SIERRA-FLOW returns **0** when every gage reported and **4** when one is stale (no day in the last 3) or missing. If USGS doesn't answer for a gage, the fetcher keeps that gage's rows from the last run and SIERRA-FLOW flags them.

The page reads the files the job commits: `results.csv`, `streamflow-report.txt`, `job-log.txt`, `normals.csv`, `streamflow.csv`, and the two `.cob` sources for the punch cards. In the browser it also asks the USGS API for each gage's latest 15-minute reading.

## What "normal" means

`NORMALS.cob` reads 83,499 daily means (water years 1996–2025) and releases each one to the sort seven times, once for every day within three days of its date. The sort orders them by gage, day of year and flow; the output procedure takes each group of about 210 values and interpolates the 10th, 25th, 50th, 75th and 90th percentiles (Weibull plotting position, `P × (N + 1)`). Days are numbered 1–366 on a leap-year calendar, and the window wraps from December 31 to January 1. The result is `normals.csv`: 8 gages × 366 days. The percentiles were checked against an independent Python calculation: all 14,640 agree to within 0.005 cfs.

The classes are the ones USGS WaterWatch uses:

| Class | Daily flow for the date |
|---|---|
| Much below normal | below the 10th percentile |
| Below normal | 10th–24th |
| Normal | 25th–75th |
| Above normal | 76th–90th |
| Much above normal | above the 90th |

The Tuolumne at Grand Canyon's record starts in October 2006, so its normals cover 19 years. Big Creek near Groveland is dry most of every fall: on October 1 even its 90th percentile is 0.00 cfs, so a dry creek in October is normal.

## The eight gages

| Site | Gage | Basin | Upstream |
|---|---|---|---|
| [11274790](https://waterdata.usgs.gov/monitoring-location/USGS-11274790/) | Tuolumne R, Grand Canyon of the Tuolumne above Hetch Hetchy | Tuolumne | No major dam (record from 2006) |
| [11276500](https://waterdata.usgs.gov/monitoring-location/USGS-11276500/) | Tuolumne R near Hetch Hetchy | Tuolumne | O'Shaughnessy Dam |
| [11284400](https://waterdata.usgs.gov/monitoring-location/USGS-11284400/) | Big Creek above Whites Gulch near Groveland | Tuolumne | No major dam, 16 sq mi |
| [11289650](https://waterdata.usgs.gov/monitoring-location/USGS-11289650/) | Tuolumne R below La Grange Dam | Tuolumne | Don Pedro and La Grange dams |
| [11290000](https://waterdata.usgs.gov/monitoring-location/USGS-11290000/) | Tuolumne R at Modesto | Tuolumne | Regulated |
| [11264500](https://waterdata.usgs.gov/monitoring-location/USGS-11264500/) | Merced R at Happy Isles Bridge | Merced | No major dam |
| [11266500](https://waterdata.usgs.gov/monitoring-location/USGS-11266500/) | Merced R at Pohono Bridge | Merced | No major dam |
| [11303000](https://waterdata.usgs.gov/monitoring-location/USGS-11303000/) | Stanislaus R at Ripon | Stanislaus | Regulated (New Melones and others) |

Four gages show what the mountains are doing; four sit below reservoirs, where the flow is mostly a release decision.

## Sample report

```
SECTION I: LATEST DAILY MEAN VS NORMAL FOR THE DATE
  NORMAL = PERCENTILES OF DAILY FLOW FOR THE DATE, WATER YEARS 1996-2025, 7-DAY WINDOW. CLASSES AS USGS WATERWATCH.

  SITE ID  STATION                    DATE             CFS      P10      P25   MEDIAN      P75      P90    % MED  CLASS
------------------------------------------------------------------------------------------------------------------------------------
  11274790 Tuolumne R Grand Canyon    2026-10-01      8.15     6.25     7.73    13.70    25.65    81.70    59.5%  NORMAL
  11276500 Tuolumne R nr Hetch Hetchy 2026-10-01     65.10    50.31    55.10    66.30    74.00    85.35    98.2%  NORMAL
  11284400 Big Creek nr Groveland     2026-10-01      0.00     0.00     0.00     0.00     0.00     0.00      --   NORMAL
  11289650 Tuolumne R bl La Grange    2026-10-01    345.00    94.99   111.25   216.50   342.00   518.90   159.4%  ABOVE NORMAL
  11290000 Tuolumne R at Modesto      2026-10-01    190.00   121.00   176.00   300.50   483.00   608.60    63.2%  NORMAL
  11264500 Merced R at Happy Isles    2026-10-01      4.66     4.20     5.10     9.40    24.00    54.27    49.6%  BELOW NORMAL
  11266500 Merced R at Pohono Bridge  2026-10-01     15.50    12.20    16.15    24.80    40.90    85.44    62.5%  BELOW NORMAL
  11303000 Stanislaus R at Ripon      2026-10-01    430.00   180.50   233.25   296.00   429.25  1395.20   145.3%  ABOVE NORMAL
```

The full report has four sections: the latest day against normal, the last 30 days against normal with a 7-day trend, each basin's outflow and class counts, and a run summary. Today's is in [`streamflow-report.txt`](streamflow-report.txt).

## Build and run

```bash
# Ubuntu / WSL                      # macOS
sudo apt install gnucobol3 bc       brew install gnucobol

make            # fetch, compile, run (builds the normals the first time)
make normals    # rebuild normals.csv from 30 years of USGS history
make report     # show the last report
```

Or by hand: `python3 fetch_usgs.py`, then `cobc -x -o sierra-flow SIERRA-FLOW.cob && ./sierra-flow`. To rebuild the normals: `python3 fetch_usgs.py --history`, `cobc -x -o normals NORMALS.cob && ./normals`.

Windows: GnuCOBOL builds are at [arnoldtrembley.com](https://www.arnoldtrembley.com/GnuCOBOL.htm); run the `python3`/`cobc` steps above in its command prompt, or use WSL.

Python uses only the standard library. The COBOL is fixed format: every line fits in 72 columns, so each one would fit on a punch card.

## Files

```
SIERRA-FLOW.cob          main program (v3)
NORMALS.cob              builds normals.csv with the SORT verb
fetch_usgs.py            USGS Water Data API → streamflow.csv / history.csv
sites.csv                the eight gages: basin, order, regulation, location
run_job.sh               the batch job; writes job-log.txt
normals.csv              day-of-year percentiles (committed; rebuilt on request)
normals-log.txt          the run that built them
streamflow.csv           last 60 daily means       ┐
streamflow-report.txt    the 132-column report     │ written each morning
results.csv              the report's numbers      │ and committed
job-log.txt              the job log               ┘
index.html               the page
```

## What changed in v3 (October 2026)

Going back over version 2 turned up several things it got wrong:

- **The normals were invented.** `baselines.csv` held one round "median" per gage for the whole year (800 cfs for Pohono Bridge, in October and in June alike), so every river looked like a drought each fall: on October 2, v2 reported Pohono at 2.5% of normal. On that date Pohono's real median is about 25 cfs. Each day of the year now has its own normal from 30 years of records.
- **The medians belonged to the wrong stations.** The `SORT` output procedure copied each station's statistics back into the table but not its median or alert thresholds, so after sorting, Section II printed every station against another station's median.
- **Rivers could never fall.** The trend was averaged into an unsigned field, which drops the minus sign. A river falling from 3,000 to 100 cfs printed `▲ RISING`.
- **Basin totals counted the same water several times.** The roll-up added the mean flow of every gage in a basin, but four of the Tuolumne gages are on the same river, one below the other.
- **A day's flow was its last reading.** The fetcher kept the last 15-minute value of each day, not the day's mean. USGS publishes daily means; those are what's used now.
- **The page didn't show COBOL's results.** It recomputed everything in JavaScript from the same invented baselines, and showed "NORMAL TERMINATION" whether or not the job ran. It now reads what the COBOL wrote.
- Also: the report claimed 132 columns but its rules were 97; the page said GnuCOBOL 3.2 (Ubuntu ships 3.1.2); the README said Big Creek was the only unregulated gage (Grand Canyon, Happy Isles and Pohono Bridge have no dams above them either); and "Big Creek near Hetch Hetchy" is near Groveland.
- USGS is moving its data to the new [Water Data API](https://api.waterdata.usgs.gov/), and the legacy Water Services endpoints v2 used were returning errors while I tested; v3 uses the new API.

## Related

- **[Sierra Streamflow Monitor](https://brooksgroves.com/sierra-streamflow)**: the same rivers with 20-year charts and a map.
- **[brooksgroves.com](https://brooksgroves.com)**

---

```
  SIERRA-FLOW V3.0   NORMALS V1.0
  JOB SIERRAFL ENDED  MAXCC=0000
  *** END OF JOB ***
```
