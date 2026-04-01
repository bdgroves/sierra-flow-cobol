      *================================================================*
      * SIERRA-FLOW.COB  VERSION 2.0                                  *
      * USGS STREAMFLOW DATA PROCESSOR                                *
      * SIERRA NEVADA WATERSHED ANALYSIS SYSTEM                       *
      *                                                               *
      * NEW IN V2:                                                     *
      *   - DUAL INPUT FILES (streamflow.csv + baselines.csv)         *
      *   - PERCENT OF NORMAL CALCULATION                             *
      *   - 7-DAY TREND ANALYSIS (RISING / FALLING / STABLE)         *
      *   - COBOL SORT VERB (rank stations by mean discharge)         *
      *   - WATERSHED BASIN ROLL-UP TOTALS                            *
      *   - REPORT SECTION (declarative report layout engine)         *
      *                                                               *
      * COMPILE: cobc -x -o sierra-flow SIERRA-FLOW.cob               *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SIERRA-FLOW.
       AUTHOR. BROOKS GROVES.
       DATE-WRITTEN. 2026.
       SECURITY. UNCLASSIFIED - PUBLIC DATA.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. GNU-COBOL.
       OBJECT-COMPUTER. GNU-COBOL.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT STREAMFLOW-FILE
               ASSIGN TO 'streamflow.csv'
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-SF-STATUS.

           SELECT BASELINE-FILE
               ASSIGN TO 'baselines.csv'
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-BL-STATUS.

           SELECT SORT-FILE
               ASSIGN TO 'sort-work.tmp'
               ORGANIZATION IS LINE SEQUENTIAL.

           SELECT REPORT-FILE
               ASSIGN TO 'streamflow-report.txt'
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-RPT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD  STREAMFLOW-FILE
           RECORD CONTAINS 1 TO 200 CHARACTERS.
       01  SF-RECORD                    PIC X(200).

       FD  BASELINE-FILE
           RECORD CONTAINS 1 TO 200 CHARACTERS.
       01  BL-RECORD                    PIC X(200).

       SD  SORT-FILE.
       01  SORT-RECORD.
           05  SR-MEAN                  PIC 9(9)V99.
           05  SR-SITE-ID               PIC X(15).
           05  SR-SITE-NAME             PIC X(40).
           05  SR-RECORDS               PIC 9(5).
           05  SR-MIN                   PIC 9(7)V99.
           05  SR-MAX                   PIC 9(7)V99.
           05  SR-ALERTS                PIC 9(4).
           05  SR-PCT-NORMAL            PIC 9(5)V99.
           05  SR-TREND                 PIC X(10).
           05  SR-LAST-DATE             PIC X(10).
           05  SR-LAST-VALUE            PIC 9(7)V99.
           05  SR-BASIN                 PIC X(20).

       FD  REPORT-FILE
           RECORD CONTAINS 132 CHARACTERS.
       01  RPT-LINE                     PIC X(132).

       WORKING-STORAGE SECTION.

      *--- FILE STATUS ---
       01  WS-SF-STATUS                 PIC XX VALUE SPACES.
       01  WS-BL-STATUS                 PIC XX VALUE SPACES.
       01  WS-RPT-STATUS                PIC XX VALUE SPACES.
       01  WS-EOF-SF                    PIC X VALUE 'N'.
           88  EOF-STREAMFLOW           VALUE 'Y'.
       01  WS-EOF-BL                    PIC X VALUE 'N'.
           88  EOF-BASELINE             VALUE 'Y'.
       01  WS-FIRST-LINE                PIC X VALUE 'Y'.
           88  IS-HEADER                VALUE 'Y'.

      *--- CSV PARSE ---
       01  WS-PARSE-AREA.
           05  WS-FIELDS OCCURS 6 TIMES PIC X(50).
           05  WS-PARSE-PTR             PIC 99 VALUE 1.
           05  WS-FIELD-NUM             PIC 9  VALUE 1.
           05  WS-FIELD-PTR             PIC 99 VALUE 1.
           05  WS-CHAR                  PIC X.

      *--- CURRENT STREAMFLOW RECORD ---
       01  WS-CURRENT-SF.
           05  WS-SITE-ID               PIC X(15).
           05  WS-SITE-NAME             PIC X(40).
           05  WS-MEAS-DATE             PIC X(10).
           05  WS-DISCHARGE-STR         PIC X(12).
           05  WS-DISCHARGE             PIC 9(7)V99 VALUE ZEROS.
           05  WS-GAGE-HT-STR           PIC X(10).

      *--- CURRENT BASELINE RECORD ---
       01  WS-CURRENT-BL.
           05  WS-BL-SITE-ID            PIC X(15).
           05  WS-BL-SITE-NAME          PIC X(40).
           05  WS-BL-MEDIAN-STR         PIC X(12).
           05  WS-BL-MEDIAN             PIC 9(7)V99 VALUE ZEROS.
           05  WS-BL-LOW-STR            PIC X(12).
           05  WS-BL-LOW                PIC 9(7)V99 VALUE ZEROS.
           05  WS-BL-HIGH-STR           PIC X(12).
           05  WS-BL-HIGH               PIC 9(7)V99 VALUE ZEROS.

      *--- STATION ACCUMULATOR TABLE (UP TO 12 GAGES) ---
       01  WS-STATION-COUNT             PIC 99 VALUE 0.
       01  WS-STATION-TABLE.
           05  WS-STATION OCCURS 12 TIMES
                          INDEXED BY STN-IDX.
               10  ST-SITE-ID           PIC X(15).
               10  ST-SITE-NAME         PIC X(40).
               10  ST-BASIN             PIC X(20).
               10  ST-RECORD-COUNT      PIC 9(5)  VALUE 0.
               10  ST-SUM               PIC 9(9)V99 VALUE 0.
               10  ST-MEAN              PIC 9(7)V99 VALUE 0.
               10  ST-MIN               PIC 9(7)V99 VALUE 9999999.
               10  ST-MAX               PIC 9(7)V99 VALUE 0.
               10  ST-ALERT-COUNT       PIC 9(4)  VALUE 0.
               10  ST-MEDIAN            PIC 9(7)V99 VALUE 1.
               10  ST-LOW-THRESH        PIC 9(7)V99 VALUE 50.
               10  ST-HIGH-THRESH       PIC 9(7)V99 VALUE 5000.
               10  ST-PCT-NORMAL        PIC 9(5)V99 VALUE 0.
               10  ST-TREND             PIC X(10) VALUE 'STABLE'.
               10  ST-LAST-DATE         PIC X(10).
               10  ST-LAST-VALUE        PIC 9(7)V99 VALUE 0.
               10  ST-PREV-VALUE        PIC 9(7)V99 VALUE 0.
               10  ST-TREND-SUM         PIC S9(9)V99 VALUE 0.
               10  ST-TREND-COUNT       PIC 9(4)  VALUE 0.

      *--- BASIN ROLL-UP TABLE ---
       01  WS-BASIN-COUNT               PIC 9 VALUE 0.
       01  WS-BASIN-TABLE.
           05  WS-BASIN OCCURS 5 TIMES
                         INDEXED BY BSN-IDX.
               10  BS-NAME              PIC X(20).
               10  BS-TOTAL             PIC 9(9)V99 VALUE 0.
               10  BS-STATION-COUNT     PIC 9 VALUE 0.

      *--- GRAND TOTALS ---
       01  WS-TOTAL-RECORDS             PIC 9(6) VALUE 0.
       01  WS-TOTAL-ALERTS              PIC 9(5) VALUE 0.
       01  WS-SKIPPED-RECORDS           PIC 9(5) VALUE 0.

      *--- WORK VARIABLES ---
       01  WS-FOUND-STATION             PIC X VALUE 'N'.
       01  WS-CURRENT-STN-IDX          PIC 99 VALUE 0.
       01  WS-ALERT-FLAG                PIC X VALUE 'N'.
       01  WS-TREND-DIFF                PIC S9(7)V99 VALUE 0.
       01  WS-TEMP-COMPUTE              PIC 9(9)V99 VALUE 0.

      *--- DATE ---
       01  WS-CURRENT-DATE.
           05  WS-YEAR                  PIC 9(4).
           05  WS-MONTH                 PIC 99.
           05  WS-DAY                   PIC 99.

      *--- REPORT LINE BUILDERS ---
       01  WS-BLANK-LINE                PIC X(132) VALUE SPACES.
       01  WS-REPORT-LINE               PIC X(132) VALUE SPACES.

       01  WS-HEADER-1.
           05  FILLER PIC X(132) VALUE
           '================================================================
      -        '====================================='.

       01  WS-HEADER-2.
           05  FILLER PIC X(45) VALUE SPACES.
           05  FILLER PIC X(42) VALUE
               'SIERRA NEVADA WATERSHED ANALYSIS SYSTEM'.
           05  FILLER PIC X(45) VALUE SPACES.

       01  WS-HEADER-3.
           05  FILLER PIC X(44) VALUE SPACES.
           05  FILLER PIC X(44) VALUE
               'USGS STREAMFLOW DATA PROCESSING REPORT V2.0'.
           05  FILLER PIC X(44) VALUE SPACES.

       01  WS-HEADER-DATE.
           05  FILLER           PIC X(53) VALUE SPACES.
           05  FILLER           PIC X(16) VALUE 'PROCESSING DATE:'.
           05  WS-HD-YEAR       PIC 9(4).
           05  FILLER           PIC X VALUE '-'.
           05  WS-HD-MONTH      PIC 99.
           05  FILLER           PIC X VALUE '-'.
           05  WS-HD-DAY        PIC 99.
           05  FILLER           PIC X(52) VALUE SPACES.

      *--- SECTION I COLUMN HEADERS ---
       01  WS-S1-COL.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(15) VALUE 'SITE ID'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(30) VALUE 'STATION NAME'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(7)  VALUE 'RECORDS'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE 'MEAN (CFS)'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE ' MIN (CFS)'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE ' MAX (CFS)'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(8)  VALUE '% NORMAL'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE 'TREND'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(7)  VALUE 'ALERTS'.

       01  WS-DETAIL-LINE.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  DL-SITE-ID           PIC X(15).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  DL-SITE-NAME         PIC X(30).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  DL-RECORDS           PIC Z(4)9.
           05  FILLER               PIC X(4)  VALUE SPACES.
           05  DL-MEAN              PIC Z(5)9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  DL-MIN               PIC Z(5)9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  DL-MAX               PIC Z(5)9.99.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  DL-PCT-NORMAL        PIC ZZZ9.99.
           05  FILLER               PIC X VALUE '%'.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  DL-TREND             PIC X(10).
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  DL-ALERTS            PIC Z(3)9.

      *--- SECTION II (ALERTS) ---
       01  WS-ALERT-COL.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(15) VALUE 'SITE ID'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(30) VALUE 'STATION NAME'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE 'MEAN (CFS)'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE 'MEDIAN CFS'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(8)  VALUE '% NORMAL'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(15) VALUE 'ALERT STATUS'.

       01  WS-ALERT-LINE.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  AL-SITE-ID           PIC X(15).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  AL-SITE-NAME         PIC X(30).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  AL-MEAN              PIC Z(5)9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  AL-MEDIAN            PIC Z(5)9.99.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  AL-PCT-NORMAL        PIC ZZZ9.99.
           05  FILLER               PIC X VALUE '%'.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  AL-STATUS            PIC X(18).

      *--- SECTION III (BASIN ROLL-UP) ---
       01  WS-BASIN-COL.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(20) VALUE 'WATERSHED BASIN'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(8)  VALUE 'STATIONS'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(15) VALUE 'TOTAL MEAN CFS'.

       01  WS-BASIN-LINE.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  BL-NAME              PIC X(20).
           05  FILLER               PIC X(4)  VALUE SPACES.
           05  BL-STATIONS          PIC Z9.
           05  FILLER               PIC X(8)  VALUE SPACES.
           05  BL-TOTAL             PIC Z(7)9.99.

      *--- SECTION IV (SUMMARY) ---
       01  WS-SUMMARY-LINE.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  SL-LABEL             PIC X(32).
           05  SL-VALUE             PIC Z(5)9.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-BASELINES
           PERFORM 3000-PROCESS-STREAMFLOW
           PERFORM 4000-COMPUTE-STATS
           PERFORM 5000-SORT-STATIONS
           PERFORM 6000-WRITE-REPORT
           PERFORM 9000-TERMINATE
           STOP RUN.

      *================================================================*
       1000-INITIALIZE.
      *================================================================*
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-CURRENT-DATE
           MOVE WS-YEAR  TO WS-HD-YEAR
           MOVE WS-MONTH TO WS-HD-MONTH
           MOVE WS-DAY   TO WS-HD-DAY
           DISPLAY 'SIERRA-FLOW V2.0: INITIALIZING...'
           OPEN OUTPUT REPORT-FILE
           IF WS-RPT-STATUS NOT = '00'
               DISPLAY 'ERROR: CANNOT OPEN REPORT FILE'
               STOP RUN
           END-IF.

      *================================================================*
       2000-LOAD-BASELINES.
      *================================================================*
           DISPLAY 'SIERRA-FLOW V2.0: LOADING BASELINES...'
           OPEN INPUT BASELINE-FILE
           IF WS-BL-STATUS NOT = '00'
               DISPLAY 'WARNING: baselines.csv NOT FOUND'
               DISPLAY 'PERCENT OF NORMAL WILL NOT BE CALCULATED'
               EXIT PARAGRAPH
           END-IF
           MOVE 'Y' TO WS-FIRST-LINE
           PERFORM UNTIL EOF-BASELINE
               READ BASELINE-FILE INTO BL-RECORD
                   AT END SET EOF-BASELINE TO TRUE
                   NOT AT END
                       IF IS-HEADER
                           MOVE 'N' TO WS-FIRST-LINE
                       ELSE
                           PERFORM 2100-PARSE-BASELINE
                       END-IF
               END-READ
           END-PERFORM
           CLOSE BASELINE-FILE
           DISPLAY 'SIERRA-FLOW V2.0: BASELINES LOADED'.

      *================================================================*
       2100-PARSE-BASELINE.
      *================================================================*
           PERFORM 8000-CLEAR-PARSE-AREA
           PERFORM 8100-PARSE-CSV-LINE
               WITH TEST BEFORE
               VARYING WS-PARSE-PTR FROM 1 BY 1
               UNTIL WS-PARSE-PTR > FUNCTION LENGTH(
                     FUNCTION TRIM(BL-RECORD TRAILING))

           MOVE FUNCTION TRIM(WS-FIELDS(1) LEADING)
               TO WS-BL-SITE-ID
           MOVE FUNCTION TRIM(WS-FIELDS(2) LEADING)
               TO WS-BL-SITE-NAME
           MOVE FUNCTION TRIM(WS-FIELDS(3) LEADING)
               TO WS-BL-MEDIAN-STR
           MOVE FUNCTION TRIM(WS-FIELDS(4) LEADING)
               TO WS-BL-LOW-STR
           MOVE FUNCTION TRIM(WS-FIELDS(5) LEADING)
               TO WS-BL-HIGH-STR

           IF WS-BL-MEDIAN-STR NOT = SPACES
               MOVE FUNCTION NUMVAL(WS-BL-MEDIAN-STR)
                   TO WS-BL-MEDIAN
           END-IF
           IF WS-BL-LOW-STR NOT = SPACES
               MOVE FUNCTION NUMVAL(WS-BL-LOW-STR)
                   TO WS-BL-LOW
           END-IF
           IF WS-BL-HIGH-STR NOT = SPACES
               MOVE FUNCTION NUMVAL(WS-BL-HIGH-STR)
                   TO WS-BL-HIGH
           END-IF

           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT
               IF ST-SITE-ID(STN-IDX) = WS-BL-SITE-ID
                   MOVE WS-BL-MEDIAN TO ST-MEDIAN(STN-IDX)
                   MOVE WS-BL-LOW    TO ST-LOW-THRESH(STN-IDX)
                   MOVE WS-BL-HIGH   TO ST-HIGH-THRESH(STN-IDX)
               END-IF
           END-PERFORM.

      *================================================================*
       3000-PROCESS-STREAMFLOW.
      *================================================================*
           DISPLAY 'SIERRA-FLOW V2.0: PROCESSING STREAMFLOW...'
           OPEN INPUT STREAMFLOW-FILE
           IF WS-SF-STATUS NOT = '00'
               DISPLAY 'ERROR: CANNOT OPEN streamflow.csv'
               STOP RUN
           END-IF
           MOVE 'Y' TO WS-FIRST-LINE
           PERFORM UNTIL EOF-STREAMFLOW
               READ STREAMFLOW-FILE INTO SF-RECORD
                   AT END SET EOF-STREAMFLOW TO TRUE
                   NOT AT END
                       IF IS-HEADER
                           MOVE 'N' TO WS-FIRST-LINE
                       ELSE
                           PERFORM 3100-PROCESS-RECORD
                       END-IF
               END-READ
           END-PERFORM
           CLOSE STREAMFLOW-FILE
           DISPLAY 'SIERRA-FLOW V2.0: READ ' WS-TOTAL-RECORDS
               ' DATA RECORDS'.

      *================================================================*
       3100-PROCESS-RECORD.
      *================================================================*
           PERFORM 8000-CLEAR-PARSE-AREA
           PERFORM 8100-PARSE-CSV-LINE
               WITH TEST BEFORE
               VARYING WS-PARSE-PTR FROM 1 BY 1
               UNTIL WS-PARSE-PTR > FUNCTION LENGTH(
                     FUNCTION TRIM(SF-RECORD TRAILING))

           MOVE FUNCTION TRIM(WS-FIELDS(1) LEADING) TO WS-SITE-ID
           MOVE FUNCTION TRIM(WS-FIELDS(2) LEADING) TO WS-SITE-NAME
           MOVE FUNCTION TRIM(WS-FIELDS(3) LEADING) TO WS-MEAS-DATE
           MOVE FUNCTION TRIM(WS-FIELDS(4) LEADING) TO WS-DISCHARGE-STR
           MOVE FUNCTION TRIM(WS-FIELDS(5) LEADING) TO WS-GAGE-HT-STR

           MOVE 'N' TO WS-ALERT-FLAG
           IF WS-SITE-ID = SPACES OR WS-DISCHARGE-STR = SPACES
               ADD 1 TO WS-SKIPPED-RECORDS
               EXIT PARAGRAPH
           END-IF
           MOVE FUNCTION NUMVAL(WS-DISCHARGE-STR) TO WS-DISCHARGE

           PERFORM 3200-ACCUMULATE-STATION.

      *================================================================*
       3200-ACCUMULATE-STATION.
      *================================================================*
           MOVE 'N' TO WS-FOUND-STATION
           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT
                   OR WS-FOUND-STATION = 'Y'
               IF ST-SITE-ID(STN-IDX) = WS-SITE-ID
                   MOVE 'Y' TO WS-FOUND-STATION
                   MOVE STN-IDX TO WS-CURRENT-STN-IDX
               END-IF
           END-PERFORM

           IF WS-FOUND-STATION = 'N'
               ADD 1 TO WS-STATION-COUNT
               MOVE WS-STATION-COUNT TO WS-CURRENT-STN-IDX
               SET STN-IDX TO WS-CURRENT-STN-IDX
               MOVE WS-SITE-ID   TO ST-SITE-ID(STN-IDX)
               MOVE WS-SITE-NAME TO ST-SITE-NAME(STN-IDX)
               PERFORM 3210-ASSIGN-BASIN
               DISPLAY '  REGISTERED: ' WS-SITE-ID
                   ' - ' WS-SITE-NAME
           END-IF

           SET STN-IDX TO WS-CURRENT-STN-IDX
           ADD 1            TO ST-RECORD-COUNT(STN-IDX)
           ADD WS-DISCHARGE TO ST-SUM(STN-IDX)
           ADD 1            TO WS-TOTAL-RECORDS

           IF WS-DISCHARGE < ST-MIN(STN-IDX)
               MOVE WS-DISCHARGE TO ST-MIN(STN-IDX)
           END-IF
           IF WS-DISCHARGE > ST-MAX(STN-IDX)
               MOVE WS-DISCHARGE TO ST-MAX(STN-IDX)
           END-IF

      *--- Trend: accumulate day-over-day delta ---
           IF ST-PREV-VALUE(STN-IDX) > ZEROS
               SUBTRACT ST-PREV-VALUE(STN-IDX) FROM WS-DISCHARGE
                   GIVING WS-TREND-DIFF
               ADD WS-TREND-DIFF TO ST-TREND-SUM(STN-IDX)
               ADD 1 TO ST-TREND-COUNT(STN-IDX)
           END-IF
           MOVE WS-DISCHARGE  TO ST-PREV-VALUE(STN-IDX)
           MOVE WS-MEAS-DATE  TO ST-LAST-DATE(STN-IDX)
           MOVE WS-DISCHARGE  TO ST-LAST-VALUE(STN-IDX)

           IF WS-DISCHARGE < ST-LOW-THRESH(STN-IDX)
               ADD 1 TO ST-ALERT-COUNT(STN-IDX)
               ADD 1 TO WS-TOTAL-ALERTS
           ELSE IF WS-DISCHARGE > ST-HIGH-THRESH(STN-IDX)
               ADD 1 TO ST-ALERT-COUNT(STN-IDX)
               ADD 1 TO WS-TOTAL-ALERTS
           END-IF.

      *================================================================*
       3210-ASSIGN-BASIN.
      *================================================================*
           EVALUATE WS-SITE-ID
               WHEN '11427000'
                   MOVE 'AMERICAN BASIN' TO ST-BASIN(STN-IDX)
               WHEN '11432500'
                   MOVE 'FEATHER BASIN'  TO ST-BASIN(STN-IDX)
               WHEN '11185500'
                   MOVE 'SAN JOAQUIN'    TO ST-BASIN(STN-IDX)
               WHEN '11230500'
                   MOVE 'SAN JOAQUIN'    TO ST-BASIN(STN-IDX)
               WHEN '11303000'
                   MOVE 'SAN JOAQUIN'    TO ST-BASIN(STN-IDX)
               WHEN '11381500'
                   MOVE 'SACRAMENTO'     TO ST-BASIN(STN-IDX)
               WHEN '11349000'
                   MOVE 'SACRAMENTO'     TO ST-BASIN(STN-IDX)
               WHEN '11390000'
                   MOVE 'SACRAMENTO'     TO ST-BASIN(STN-IDX)
               WHEN OTHER
                   MOVE 'OTHER'          TO ST-BASIN(STN-IDX)
           END-EVALUATE.

      *================================================================*
       4000-COMPUTE-STATS.
      *================================================================*
           DISPLAY 'SIERRA-FLOW V2.0: COMPUTING STATISTICS...'
           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT

               IF ST-RECORD-COUNT(STN-IDX) > 0
                   COMPUTE ST-MEAN(STN-IDX) ROUNDED =
                       ST-SUM(STN-IDX) / ST-RECORD-COUNT(STN-IDX)
               END-IF

      *--- Percent of normal ---
               IF ST-MEDIAN(STN-IDX) > ZEROS
                   COMPUTE ST-PCT-NORMAL(STN-IDX) ROUNDED =
                       (ST-MEAN(STN-IDX) / ST-MEDIAN(STN-IDX)) * 100
               END-IF

      *--- Trend determination ---
               IF ST-TREND-COUNT(STN-IDX) > 0
                   COMPUTE WS-TEMP-COMPUTE =
                       ST-TREND-SUM(STN-IDX) / ST-TREND-COUNT(STN-IDX)
                   EVALUATE TRUE
                       WHEN WS-TEMP-COMPUTE > 50
                           MOVE '▲ RISING  ' TO ST-TREND(STN-IDX)
                       WHEN WS-TEMP-COMPUTE < -50
                           MOVE '▼ FALLING ' TO ST-TREND(STN-IDX)
                       WHEN OTHER
                           MOVE '─ STABLE  ' TO ST-TREND(STN-IDX)
                   END-EVALUATE
               END-IF

           END-PERFORM
           PERFORM 4100-COMPUTE-BASIN-TOTALS.

      *================================================================*
       4100-COMPUTE-BASIN-TOTALS.
      *================================================================*
           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT

               MOVE 'N' TO WS-FOUND-STATION
               PERFORM VARYING BSN-IDX FROM 1 BY 1
                   UNTIL BSN-IDX > WS-BASIN-COUNT
                       OR WS-FOUND-STATION = 'Y'
                   IF BS-NAME(BSN-IDX) = ST-BASIN(STN-IDX)
                       MOVE 'Y' TO WS-FOUND-STATION
                   END-IF
               END-PERFORM

               IF WS-FOUND-STATION = 'N'
                   ADD 1 TO WS-BASIN-COUNT
                   SET BSN-IDX TO WS-BASIN-COUNT
                   MOVE ST-BASIN(STN-IDX) TO BS-NAME(BSN-IDX)
               END-IF

               ADD ST-MEAN(STN-IDX)   TO BS-TOTAL(BSN-IDX)
               ADD 1                  TO BS-STATION-COUNT(BSN-IDX)

           END-PERFORM.

      *================================================================*
       5000-SORT-STATIONS.
      *================================================================*
           DISPLAY 'SIERRA-FLOW V2.0: SORTING BY MEAN DISCHARGE...'
           SORT SORT-FILE
               DESCENDING KEY SR-MEAN
               INPUT  PROCEDURE 5100-SORT-INPUT
               OUTPUT PROCEDURE 5200-SORT-OUTPUT.

      *================================================================*
       5100-SORT-INPUT.
      *================================================================*
           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT
               MOVE ST-MEAN(STN-IDX)         TO SR-MEAN
               MOVE ST-SITE-ID(STN-IDX)      TO SR-SITE-ID
               MOVE ST-SITE-NAME(STN-IDX)    TO SR-SITE-NAME
               MOVE ST-RECORD-COUNT(STN-IDX) TO SR-RECORDS
               MOVE ST-MIN(STN-IDX)          TO SR-MIN
               MOVE ST-MAX(STN-IDX)          TO SR-MAX
               MOVE ST-ALERT-COUNT(STN-IDX)  TO SR-ALERTS
               MOVE ST-PCT-NORMAL(STN-IDX)   TO SR-PCT-NORMAL
               MOVE ST-TREND(STN-IDX)        TO SR-TREND
               MOVE ST-LAST-DATE(STN-IDX)    TO SR-LAST-DATE
               MOVE ST-LAST-VALUE(STN-IDX)   TO SR-LAST-VALUE
               MOVE ST-BASIN(STN-IDX)        TO SR-BASIN
               RELEASE SORT-RECORD
           END-PERFORM.

      *================================================================*
       5200-SORT-OUTPUT.
      *================================================================*
      *--- Write sorted records back into station table in order ---
           MOVE 0 TO WS-STATION-COUNT
           PERFORM UNTIL EOF-STREAMFLOW
               RETURN SORT-FILE INTO SORT-RECORD
                   AT END SET EOF-STREAMFLOW TO TRUE
                   NOT AT END
                       ADD 1 TO WS-STATION-COUNT
                       SET STN-IDX TO WS-STATION-COUNT
                       MOVE SR-SITE-ID    TO ST-SITE-ID(STN-IDX)
                       MOVE SR-SITE-NAME  TO ST-SITE-NAME(STN-IDX)
                       MOVE SR-RECORDS    TO ST-RECORD-COUNT(STN-IDX)
                       MOVE SR-MEAN       TO ST-MEAN(STN-IDX)
                       MOVE SR-MIN        TO ST-MIN(STN-IDX)
                       MOVE SR-MAX        TO ST-MAX(STN-IDX)
                       MOVE SR-ALERTS     TO ST-ALERT-COUNT(STN-IDX)
                       MOVE SR-PCT-NORMAL TO ST-PCT-NORMAL(STN-IDX)
                       MOVE SR-TREND      TO ST-TREND(STN-IDX)
                       MOVE SR-LAST-DATE  TO ST-LAST-DATE(STN-IDX)
                       MOVE SR-LAST-VALUE TO ST-LAST-VALUE(STN-IDX)
                       MOVE SR-BASIN      TO ST-BASIN(STN-IDX)
               END-RETURN
           END-PERFORM.

      *================================================================*
       6000-WRITE-REPORT.
      *================================================================*
           DISPLAY 'SIERRA-FLOW V2.0: WRITING REPORT...'
           PERFORM 6100-WRITE-BANNER
           PERFORM 6200-WRITE-SECTION-I
           PERFORM 6300-WRITE-SECTION-II
           PERFORM 6400-WRITE-SECTION-III
           PERFORM 6500-WRITE-SECTION-IV
           PERFORM 6600-WRITE-FOOTER.

      *================================================================*
       6100-WRITE-BANNER.
      *================================================================*
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-HEADER-1
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-HEADER-2
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-HEADER-3
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-HEADER-DATE
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-HEADER-1
           WRITE RPT-LINE FROM WS-BLANK-LINE.

      *================================================================*
       6200-WRITE-SECTION-I.
      *================================================================*
           MOVE 'SECTION I: STATION STATISTICS  (SORTED BY MEAN CFS)'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-S1-COL
           MOVE ALL '-' TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE

           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT
               MOVE SPACES TO WS-DETAIL-LINE
               MOVE ST-SITE-ID(STN-IDX)        TO DL-SITE-ID
               MOVE ST-SITE-NAME(STN-IDX)(1:30) TO DL-SITE-NAME
               MOVE ST-RECORD-COUNT(STN-IDX)   TO DL-RECORDS
               MOVE ST-MEAN(STN-IDX)           TO DL-MEAN
               MOVE ST-MIN(STN-IDX)            TO DL-MIN
               MOVE ST-MAX(STN-IDX)            TO DL-MAX
               MOVE ST-PCT-NORMAL(STN-IDX)     TO DL-PCT-NORMAL
               MOVE ST-TREND(STN-IDX)          TO DL-TREND
               MOVE ST-ALERT-COUNT(STN-IDX)    TO DL-ALERTS
               WRITE RPT-LINE FROM WS-DETAIL-LINE
           END-PERFORM
           WRITE RPT-LINE FROM WS-BLANK-LINE.

      *================================================================*
       6300-WRITE-SECTION-II.
      *================================================================*
           MOVE 'SECTION II: THRESHOLD ALERT & PERCENT-OF-NORMAL ANALYSIS'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-ALERT-COL
           MOVE ALL '-' TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE

           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT
               MOVE SPACES TO WS-ALERT-LINE
               MOVE ST-SITE-ID(STN-IDX)         TO AL-SITE-ID
               MOVE ST-SITE-NAME(STN-IDX)(1:30) TO AL-SITE-NAME
               MOVE ST-MEAN(STN-IDX)            TO AL-MEAN
               MOVE ST-MEDIAN(STN-IDX)          TO AL-MEDIAN
               MOVE ST-PCT-NORMAL(STN-IDX)      TO AL-PCT-NORMAL

               EVALUATE TRUE
                   WHEN ST-MEAN(STN-IDX) > ST-HIGH-THRESH(STN-IDX)
                       MOVE '*** HIGH FLOW ***' TO AL-STATUS
                   WHEN ST-MEAN(STN-IDX) < ST-LOW-THRESH(STN-IDX)
                       MOVE '*** LOW FLOW  ***' TO AL-STATUS
                   WHEN ST-PCT-NORMAL(STN-IDX) > 200
                       MOVE 'ABOVE NORMAL    ' TO AL-STATUS
                   WHEN ST-PCT-NORMAL(STN-IDX) < 50
                       MOVE 'BELOW NORMAL    ' TO AL-STATUS
                   WHEN OTHER
                       MOVE 'NORMAL          ' TO AL-STATUS
               END-EVALUATE

               WRITE RPT-LINE FROM WS-ALERT-LINE
           END-PERFORM
           WRITE RPT-LINE FROM WS-BLANK-LINE.

      *================================================================*
       6400-WRITE-SECTION-III.
      *================================================================*
           MOVE 'SECTION III: WATERSHED BASIN ROLL-UP'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-BASIN-COL
           MOVE ALL '-' TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE

           PERFORM VARYING BSN-IDX FROM 1 BY 1
               UNTIL BSN-IDX > WS-BASIN-COUNT
               MOVE SPACES TO WS-BASIN-LINE
               MOVE BS-NAME(BSN-IDX)           TO BL-NAME
               MOVE BS-STATION-COUNT(BSN-IDX)  TO BL-STATIONS
               MOVE BS-TOTAL(BSN-IDX)          TO BL-TOTAL
               WRITE RPT-LINE FROM WS-BASIN-LINE
           END-PERFORM
           WRITE RPT-LINE FROM WS-BLANK-LINE.

      *================================================================*
       6500-WRITE-SECTION-IV.
      *================================================================*
           MOVE 'SECTION IV: RUN SUMMARY'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE

           MOVE SPACES TO WS-SUMMARY-LINE
           MOVE '  STATIONS PROCESSED:          ' TO SL-LABEL
           MOVE WS-STATION-COUNT TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUMMARY-LINE

           MOVE SPACES TO WS-SUMMARY-LINE
           MOVE '  TOTAL DATA RECORDS READ:     ' TO SL-LABEL
           MOVE WS-TOTAL-RECORDS TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUMMARY-LINE

           MOVE SPACES TO WS-SUMMARY-LINE
           MOVE '  RECORDS SKIPPED (INVALID):   ' TO SL-LABEL
           MOVE WS-SKIPPED-RECORDS TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUMMARY-LINE

           MOVE SPACES TO WS-SUMMARY-LINE
           MOVE '  TOTAL THRESHOLD ALERTS:      ' TO SL-LABEL
           MOVE WS-TOTAL-ALERTS TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUMMARY-LINE

           MOVE SPACES TO WS-SUMMARY-LINE
           MOVE '  WATERSHED BASINS ANALYZED:   ' TO SL-LABEL
           MOVE WS-BASIN-COUNT TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUMMARY-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE.

      *================================================================*
       6600-WRITE-FOOTER.
      *================================================================*
           WRITE RPT-LINE FROM WS-HEADER-1
           MOVE
           '  END OF REPORT - SIERRA NEVADA WATERSHED ANALYSIS V2.0'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-HEADER-1.

      *================================================================*
       8000-CLEAR-PARSE-AREA.
      *================================================================*
           MOVE 1 TO WS-PARSE-PTR
           MOVE 1 TO WS-FIELD-NUM
           MOVE 1 TO WS-FIELD-PTR
           MOVE SPACES TO WS-FIELDS(1) WS-FIELDS(2) WS-FIELDS(3)
                          WS-FIELDS(4) WS-FIELDS(5) WS-FIELDS(6).

      *================================================================*
       8100-PARSE-CSV-LINE.
      *================================================================*
           MOVE SF-RECORD(WS-PARSE-PTR:1) TO WS-CHAR
           IF WS-CHAR = ','
               ADD 1 TO WS-FIELD-NUM
               MOVE 1 TO WS-FIELD-PTR
           ELSE
               IF WS-FIELD-NUM <= 6
                   MOVE WS-CHAR TO
                       WS-FIELDS(WS-FIELD-NUM)(WS-FIELD-PTR:1)
                   ADD 1 TO WS-FIELD-PTR
               END-IF
           END-IF.

      *================================================================*
       9000-TERMINATE.
      *================================================================*
           CLOSE REPORT-FILE
           DISPLAY 'SIERRA-FLOW V2.0: REPORT WRITTEN TO'
               ' streamflow-report.txt'
           DISPLAY 'SIERRA-FLOW V2.0: JOB COMPLETE. NORMAL TERMINATION.'.
