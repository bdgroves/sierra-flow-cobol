      *================================================================*
      * SIERRA-FLOW.COB                                                *
      * USGS STREAMFLOW DATA PROCESSOR                                 *
      * SIERRA NEVADA WATERSHED ANALYSIS SYSTEM                        *
      *                                                                *
      * READS USGS GAGE CSV DATA, COMPUTES STATISTICS,                *
      * FLAGS THRESHOLD ALERTS, AND PRODUCES FORMATTED REPORT         *
      *                                                                *
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
               ASSIGN TO WS-INPUT-FILE
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

           SELECT REPORT-FILE
               ASSIGN TO WS-OUTPUT-FILE
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-RPT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD  STREAMFLOW-FILE
           RECORD CONTAINS 1 TO 200 CHARACTERS.
       01  SF-RECORD                    PIC X(200).

       FD  REPORT-FILE
           RECORD CONTAINS 132 CHARACTERS.
       01  RPT-LINE                     PIC X(132).

       WORKING-STORAGE SECTION.

      *--- FILE CONTROL ---
       01  WS-FILE-STATUS               PIC XX VALUE SPACES.
       01  WS-RPT-STATUS                PIC XX VALUE SPACES.
       01  WS-INPUT-FILE                PIC X(100)
                                        VALUE 'streamflow.csv'.
       01  WS-OUTPUT-FILE               PIC X(100)
                                        VALUE 'streamflow-report.txt'.
       01  WS-EOF-FLAG                  PIC X VALUE 'N'.
           88  END-OF-FILE              VALUE 'Y'.
       01  WS-FIRST-LINE                PIC X VALUE 'Y'.
           88  IS-HEADER-LINE           VALUE 'Y'.

      *--- CSV PARSE FIELDS ---
       01  WS-PARSE-AREA.
           05  WS-FIELD-1               PIC X(30).
           05  WS-FIELD-2               PIC X(30).
           05  WS-FIELD-3               PIC X(30).
           05  WS-FIELD-4               PIC X(30).
           05  WS-FIELD-5               PIC X(30).
           05  WS-PARSE-PTR             PIC 99 VALUE 1.
           05  WS-FIELD-NUM             PIC 9  VALUE 1.
           05  WS-CHAR                  PIC X.
           05  WS-FIELD-PTR             PIC 99 VALUE 1.

      *--- CURRENT RECORD ---
       01  WS-CURRENT-REC.
           05  WS-SITE-ID               PIC X(15).
           05  WS-SITE-NAME             PIC X(40).
           05  WS-MEAS-DATE             PIC X(10).
           05  WS-DISCHARGE-STR         PIC X(12).
           05  WS-DISCHARGE             PIC 9(7)V99 VALUE ZEROS.
           05  WS-GAGE-HT-STR           PIC X(10).
           05  WS-GAGE-HT               PIC 9(4)V99  VALUE ZEROS.

      *--- STATION ACCUMULATORS (UP TO 8 GAGES) ---
       01  WS-STATION-COUNT             PIC 9 VALUE 0.
       01  WS-STATION-TABLE.
           05  WS-STATION OCCURS 8 TIMES
                          INDEXED BY STN-IDX.
               10  ST-SITE-ID           PIC X(15).
               10  ST-SITE-NAME         PIC X(40).
               10  ST-RECORD-COUNT      PIC 9(5) VALUE 0.
               10  ST-SUM               PIC 9(9)V99 VALUE 0.
               10  ST-MIN               PIC 9(7)V99 VALUE 9999999.99.
               10  ST-MAX               PIC 9(7)V99 VALUE 0.
               10  ST-MEAN              PIC 9(7)V99 VALUE 0.
               10  ST-ALERT-COUNT       PIC 9(4) VALUE 0.
               10  ST-ALERT-LOW-THRESH  PIC 9(7)V99 VALUE 50.00.
               10  ST-ALERT-HIGH-THRESH PIC 9(7)V99 VALUE 5000.00.
               10  ST-LAST-DATE         PIC X(10).
               10  ST-LAST-VALUE        PIC 9(7)V99 VALUE 0.

      *--- GRAND TOTALS ---
       01  WS-TOTAL-RECORDS             PIC 9(6) VALUE 0.
       01  WS-TOTAL-ALERTS              PIC 9(5) VALUE 0.
       01  WS-SKIPPED-RECORDS           PIC 9(5) VALUE 0.

      *--- WORK VARIABLES ---
       01  WS-FOUND-STATION             PIC X VALUE 'N'.
       01  WS-CURRENT-STN-IDX           PIC 9 VALUE 0.
       01  WS-LOOP-IDX                  PIC 9 VALUE 1.
       01  WS-ALERT-FLAG                PIC X VALUE 'N'.
       01  WS-NUMERIC-CHECK             PIC X(12).
       01  WS-NUMERIC-TEST              PIC 9(7)V99.
       01  WS-TEMP-VALUE                PIC 9(7)V99.

      *--- DATE/TIME ---
       01  WS-CURRENT-DATE.
           05  WS-YEAR                  PIC 9(4).
           05  WS-MONTH                 PIC 99.
           05  WS-DAY                   PIC 99.

      *--- REPORT LINE BUILDERS ---
       01  WS-REPORT-LINE               PIC X(132) VALUE SPACES.
       01  WS-BLANK-LINE                PIC X(132) VALUE SPACES.

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
           05  FILLER PIC X(47) VALUE SPACES.
           05  FILLER PIC X(38) VALUE
               'USGS STREAMFLOW DATA PROCESSING REPORT'.
           05  FILLER PIC X(47) VALUE SPACES.

       01  WS-HEADER-DATE.
           05  FILLER PIC X(53) VALUE SPACES.
           05  FILLER PIC X(16) VALUE 'PROCESSING DATE:'.
           05  WS-HD-YEAR   PIC 9(4).
           05  FILLER PIC X VALUE '-'.
           05  WS-HD-MONTH  PIC 99.
           05  FILLER PIC X VALUE '-'.
           05  WS-HD-DAY    PIC 99.
           05  FILLER PIC X(52) VALUE SPACES.

       01  WS-COL-HEADER-1.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(15) VALUE 'SITE ID'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(35) VALUE 'STATION NAME'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(7)  VALUE 'RECORDS'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE 'MEAN (CFS)'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE ' MIN (CFS)'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE ' MAX (CFS)'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(7)  VALUE 'ALERTS'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE 'LAST DATE'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE 'LAST (CFS)'.

       01  WS-DETAIL-LINE.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  DL-SITE-ID           PIC X(15).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  DL-SITE-NAME         PIC X(35).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  DL-RECORDS           PIC Z(5)9.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  DL-MEAN              PIC Z(5)9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  DL-MIN               PIC Z(5)9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  DL-MAX               PIC Z(5)9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  DL-ALERTS            PIC Z(3)9.
           05  FILLER               PIC X(5)  VALUE SPACES.
           05  DL-LAST-DATE         PIC X(10).
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  DL-LAST-VALUE        PIC Z(5)9.99.

       01  WS-ALERT-HEADER.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(15) VALUE 'SITE ID'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(35) VALUE 'STATION NAME'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE 'MEAN (CFS)'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE 'LOW THRESH'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(11) VALUE 'HIGH THRESH'.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(12) VALUE 'ALERT STATUS'.

       01  WS-ALERT-LINE.
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  AL-SITE-ID           PIC X(15).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  AL-SITE-NAME         PIC X(35).
           05  FILLER               PIC X(2)  VALUE SPACES.
           05  AL-MEAN              PIC Z(5)9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  AL-LOW-THRESH        PIC Z(5)9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  AL-HIGH-THRESH       PIC Z(5)9.99.
           05  FILLER               PIC X(3)  VALUE SPACES.
           05  AL-STATUS            PIC X(15).

       01  WS-SUMMARY-LINE.
           05  FILLER PIC X(2)  VALUE SPACES.
           05  SL-LABEL             PIC X(30).
           05  SL-VALUE             PIC Z(5)9.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-FILE
           PERFORM 3000-COMPUTE-STATS
           PERFORM 4000-WRITE-REPORT
           PERFORM 9000-TERMINATE
           STOP RUN.

      *================================================================*
       1000-INITIALIZE.
      *================================================================*
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-CURRENT-DATE
           MOVE WS-YEAR  TO WS-HD-YEAR
           MOVE WS-MONTH TO WS-HD-MONTH
           MOVE WS-DAY   TO WS-HD-DAY
           DISPLAY 'SIERRA-FLOW: INITIALIZING...'
           OPEN INPUT  STREAMFLOW-FILE
           OPEN OUTPUT REPORT-FILE
           IF WS-FILE-STATUS NOT = '00'
               DISPLAY 'ERROR: CANNOT OPEN ' WS-INPUT-FILE
               DISPLAY 'FILE STATUS: ' WS-FILE-STATUS
               STOP RUN
           END-IF
           DISPLAY 'SIERRA-FLOW: INPUT FILE OPENED OK'.

      *================================================================*
       2000-PROCESS-FILE.
      *================================================================*
           PERFORM UNTIL END-OF-FILE
               READ STREAMFLOW-FILE INTO SF-RECORD
                   AT END
                       SET END-OF-FILE TO TRUE
                   NOT AT END
                       PERFORM 2100-PROCESS-RECORD
               END-READ
           END-PERFORM
           DISPLAY 'SIERRA-FLOW: READ ' WS-TOTAL-RECORDS
               ' DATA RECORDS'.

      *================================================================*
       2100-PROCESS-RECORD.
      *================================================================*
           IF IS-HEADER-LINE
               MOVE 'N' TO WS-FIRST-LINE
               EXIT PARAGRAPH
           END-IF
           PERFORM 2200-PARSE-CSV
           PERFORM 2300-VALIDATE-RECORD
           IF WS-ALERT-FLAG = 'V'
               EXIT PARAGRAPH
           END-IF
           PERFORM 2400-ACCUMULATE-STATION.

      *================================================================*
       2200-PARSE-CSV.
      *================================================================*
           MOVE SPACES TO WS-FIELD-1 WS-FIELD-2 WS-FIELD-3
                          WS-FIELD-4 WS-FIELD-5
           MOVE 1 TO WS-PARSE-PTR
           MOVE 1 TO WS-FIELD-NUM
           MOVE 1 TO WS-FIELD-PTR

           PERFORM VARYING WS-PARSE-PTR FROM 1 BY 1
               UNTIL WS-PARSE-PTR > FUNCTION LENGTH(
                     FUNCTION TRIM(SF-RECORD TRAILING))
               MOVE SF-RECORD(WS-PARSE-PTR:1) TO WS-CHAR
               IF WS-CHAR = ','
                   ADD 1 TO WS-FIELD-NUM
                   MOVE 1 TO WS-FIELD-PTR
               ELSE
                   EVALUATE WS-FIELD-NUM
                       WHEN 1
                           MOVE WS-CHAR TO
                               WS-FIELD-1(WS-FIELD-PTR:1)
                       WHEN 2
                           MOVE WS-CHAR TO
                               WS-FIELD-2(WS-FIELD-PTR:1)
                       WHEN 3
                           MOVE WS-CHAR TO
                               WS-FIELD-3(WS-FIELD-PTR:1)
                       WHEN 4
                           MOVE WS-CHAR TO
                               WS-FIELD-4(WS-FIELD-PTR:1)
                       WHEN 5
                           MOVE WS-CHAR TO
                               WS-FIELD-5(WS-FIELD-PTR:1)
                   END-EVALUATE
                   ADD 1 TO WS-FIELD-PTR
               END-IF
           END-PERFORM

           MOVE FUNCTION TRIM(WS-FIELD-1 LEADING)
               TO WS-SITE-ID
           MOVE FUNCTION TRIM(WS-FIELD-2 LEADING)
               TO WS-SITE-NAME
           MOVE FUNCTION TRIM(WS-FIELD-3 LEADING)
               TO WS-MEAS-DATE
           MOVE FUNCTION TRIM(WS-FIELD-4 LEADING)
               TO WS-DISCHARGE-STR
           MOVE FUNCTION TRIM(WS-FIELD-5 LEADING)
               TO WS-GAGE-HT-STR.

      *================================================================*
       2300-VALIDATE-RECORD.
      *================================================================*
           MOVE 'N' TO WS-ALERT-FLAG
           MOVE WS-DISCHARGE-STR TO WS-NUMERIC-CHECK
           MOVE FUNCTION TRIM(WS-NUMERIC-CHECK LEADING)
               TO WS-NUMERIC-CHECK
           IF WS-NUMERIC-CHECK = SPACES
               ADD 1 TO WS-SKIPPED-RECORDS
               MOVE 'V' TO WS-ALERT-FLAG
               EXIT PARAGRAPH
           END-IF
           IF WS-SITE-ID = SPACES
               ADD 1 TO WS-SKIPPED-RECORDS
               MOVE 'V' TO WS-ALERT-FLAG
               EXIT PARAGRAPH
           END-IF
           MOVE FUNCTION NUMVAL(WS-DISCHARGE-STR)
               TO WS-DISCHARGE.

      *================================================================*
       2400-ACCUMULATE-STATION.
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
               DISPLAY 'SIERRA-FLOW: REGISTERED STATION '
                   WS-SITE-ID ' - ' WS-SITE-NAME
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

           MOVE WS-MEAS-DATE  TO ST-LAST-DATE(STN-IDX)
           MOVE WS-DISCHARGE  TO ST-LAST-VALUE(STN-IDX)

           IF WS-DISCHARGE < ST-ALERT-LOW-THRESH(STN-IDX)
               ADD 1 TO ST-ALERT-COUNT(STN-IDX)
               ADD 1 TO WS-TOTAL-ALERTS
           ELSE IF WS-DISCHARGE > ST-ALERT-HIGH-THRESH(STN-IDX)
               ADD 1 TO ST-ALERT-COUNT(STN-IDX)
               ADD 1 TO WS-TOTAL-ALERTS
           END-IF.

      *================================================================*
       3000-COMPUTE-STATS.
      *================================================================*
           DISPLAY 'SIERRA-FLOW: COMPUTING STATISTICS...'
           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT
               IF ST-RECORD-COUNT(STN-IDX) > 0
                   COMPUTE ST-MEAN(STN-IDX) ROUNDED =
                       ST-SUM(STN-IDX) / ST-RECORD-COUNT(STN-IDX)
               END-IF
           END-PERFORM.

      *================================================================*
       4000-WRITE-REPORT.
      *================================================================*
           DISPLAY 'SIERRA-FLOW: WRITING REPORT...'
           PERFORM 4100-WRITE-BANNER
           PERFORM 4200-WRITE-STATION-TABLE
           PERFORM 4300-WRITE-ALERT-SECTION
           PERFORM 4400-WRITE-SUMMARY
           PERFORM 4500-WRITE-FOOTER.

      *================================================================*
       4100-WRITE-BANNER.
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
       4200-WRITE-STATION-TABLE.
      *================================================================*
           MOVE 'SECTION I: STATION STATISTICS SUMMARY'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-COL-HEADER-1
           MOVE ALL '-' TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE

           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT
               MOVE SPACES TO WS-DETAIL-LINE
               MOVE ST-SITE-ID(STN-IDX)    TO DL-SITE-ID
               MOVE ST-SITE-NAME(STN-IDX)(1:35) TO DL-SITE-NAME
               MOVE ST-RECORD-COUNT(STN-IDX) TO DL-RECORDS
               MOVE ST-MEAN(STN-IDX)        TO DL-MEAN
               MOVE ST-MIN(STN-IDX)         TO DL-MIN
               MOVE ST-MAX(STN-IDX)         TO DL-MAX
               MOVE ST-ALERT-COUNT(STN-IDX) TO DL-ALERTS
               MOVE ST-LAST-DATE(STN-IDX)   TO DL-LAST-DATE
               MOVE ST-LAST-VALUE(STN-IDX)  TO DL-LAST-VALUE
               WRITE RPT-LINE FROM WS-DETAIL-LINE
           END-PERFORM
           WRITE RPT-LINE FROM WS-BLANK-LINE.

      *================================================================*
       4300-WRITE-ALERT-SECTION.
      *================================================================*
           MOVE 'SECTION II: THRESHOLD ALERT ANALYSIS'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE
           MOVE '  ALERT CONDITIONS: LOW < 50 CFS | HIGH > 5000 CFS'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE
           WRITE RPT-LINE FROM WS-ALERT-HEADER
           MOVE ALL '-' TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE

           PERFORM VARYING STN-IDX FROM 1 BY 1
               UNTIL STN-IDX > WS-STATION-COUNT
               MOVE SPACES TO WS-ALERT-LINE
               MOVE ST-SITE-ID(STN-IDX)         TO AL-SITE-ID
               MOVE ST-SITE-NAME(STN-IDX)(1:35) TO AL-SITE-NAME
               MOVE ST-MEAN(STN-IDX)            TO AL-MEAN
               MOVE ST-ALERT-LOW-THRESH(STN-IDX)  TO AL-LOW-THRESH
               MOVE ST-ALERT-HIGH-THRESH(STN-IDX) TO AL-HIGH-THRESH

               EVALUATE TRUE
                   WHEN ST-MEAN(STN-IDX) <
                        ST-ALERT-LOW-THRESH(STN-IDX)
                       MOVE '*** LOW FLOW ***' TO AL-STATUS
                   WHEN ST-MEAN(STN-IDX) >
                        ST-ALERT-HIGH-THRESH(STN-IDX)
                       MOVE '*** HIGH FLOW **' TO AL-STATUS
                   WHEN OTHER
                       MOVE 'NORMAL          ' TO AL-STATUS
               END-EVALUATE

               WRITE RPT-LINE FROM WS-ALERT-LINE
           END-PERFORM
           WRITE RPT-LINE FROM WS-BLANK-LINE.

      *================================================================*
       4400-WRITE-SUMMARY.
      *================================================================*
           MOVE 'SECTION III: RUN SUMMARY'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE

           MOVE SPACES TO WS-SUMMARY-LINE
           MOVE '  STATIONS PROCESSED:         ' TO SL-LABEL
           MOVE WS-STATION-COUNT TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUMMARY-LINE

           MOVE SPACES TO WS-SUMMARY-LINE
           MOVE '  TOTAL DATA RECORDS READ:    ' TO SL-LABEL
           MOVE WS-TOTAL-RECORDS TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUMMARY-LINE

           MOVE SPACES TO WS-SUMMARY-LINE
           MOVE '  RECORDS SKIPPED (INVALID):  ' TO SL-LABEL
           MOVE WS-SKIPPED-RECORDS TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUMMARY-LINE

           MOVE SPACES TO WS-SUMMARY-LINE
           MOVE '  TOTAL THRESHOLD ALERTS:     ' TO SL-LABEL
           MOVE WS-TOTAL-ALERTS TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUMMARY-LINE
           WRITE RPT-LINE FROM WS-BLANK-LINE.

      *================================================================*
       4500-WRITE-FOOTER.
      *================================================================*
           WRITE RPT-LINE FROM WS-HEADER-1
           MOVE '  END OF REPORT - SIERRA NEVADA WATERSHED ANALYSIS'
               TO WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-REPORT-LINE
           WRITE RPT-LINE FROM WS-HEADER-1.

      *================================================================*
       9000-TERMINATE.
      *================================================================*
           CLOSE STREAMFLOW-FILE
           CLOSE REPORT-FILE
           DISPLAY 'SIERRA-FLOW: REPORT WRITTEN TO '
               WS-OUTPUT-FILE
           DISPLAY 'SIERRA-FLOW: JOB COMPLETE. NORMAL TERMINATION.'.
