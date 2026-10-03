#!/usr/bin/env bash
# The SIERRA-FLOW batch job: fetch, compile, (normals), run. Writes job-log.txt.
#   ./run_job.sh              daily run
#   ./run_job.sh --normals    also rebuild normals.csv from 30 years of history
# Every step's output and return code goes in the log; the job stops on RC >= 8,
# like a mainframe job step with COND=(8,LE).
set -u
export TZ=UTC
LOG=job-log.txt
REBUILD=0; [ "${1:-}" = "--normals" ] && REBUILD=1; [ -f normals.csv ] || REBUILD=1
START=$(date +%s.%N)
MAXRC=0
cobv=$(cobc --version 2>/dev/null | head -1)
{
  echo "JOB SIERRAFL   $(date '+%Y-%m-%d %H:%M:%S') UTC"
  echo "HOST           ${RUNNER_OS:-$(uname -s)} $(uname -m) · ${cobv:-cobc not found} · $(python3 --version 2>&1)"
  [ -n "${GITHUB_RUN_NUMBER:-}" ] && echo "RUN            GitHub Actions run ${GITHUB_RUN_NUMBER} (${GITHUB_EVENT_NAME:-})"
  echo
} > "$LOG"

step () {   # step NAME command...
  local name=$1; shift
  local t0=$(date +%s.%N)
  local out; out=$("$@" 2>&1); local rc=$?
  local t=$(echo "$(date +%s.%N) - $t0" | bc)
  printf "STEP %-10s RC=%04d  %6.2fs  %s\n" "$name" "$rc" "$t" "$*" >> "$LOG"
  echo "$out" | grep -v -e FORTIFY -e 'location of the previous' -e '^$' | sed 's/^/    /' >> "$LOG"
  echo >> "$LOG"
  echo "$out"
  [ $rc -gt $MAXRC ] && MAXRC=$rc
  return $rc
}

step FETCH python3 fetch_usgs.py || [ $? -lt 8 ] || exit 1
step COMPILE cobc -x -o sierra-flow SIERRA-FLOW.cob || exit 1
if [ $REBUILD = 1 ]; then
  step HISTORY python3 fetch_usgs.py --history || exit 1
  step COMPILE cobc -x -o normals NORMALS.cob || exit 1
  step NORMALS ./normals; rc=$?; [ $rc -ge 8 ] && exit 1
  { echo "NORMALS BUILT  $(date '+%Y-%m-%d %H:%M:%S') UTC  from water years 1996-2025"; echo;
    sed -n '/STEP HISTORY/,$p' "$LOG" | grep -v -e '^STEP COMPILE' -e '^    cobc'; } > normals-log.txt
  rm -f history.csv
else
  echo "STEP NORMALS    skipped: normals.csv is current (see normals-log.txt)" >> "$LOG"
  echo >> "$LOG"
fi
step SIERRAFL ./sierra-flow; rc=$?; [ $rc -ge 8 ] && exit 1
T=$(echo "$(date +%s.%N) - $START" | bc)
printf "JOB SIERRAFL   ENDED  MAXCC=%04d  %.1fs\n" "$MAXRC" "$T" >> "$LOG"
rm -f sierra-sort.tmp normals-sort.tmp
exit 0
