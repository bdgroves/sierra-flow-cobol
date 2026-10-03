      *================================================================*
      * SIERRA-FLOW.COB  VERSION 3.0                                   *
      * USGS STREAMFLOW DATA PROCESSOR                                 *
      * SIERRA NEVADA WATERSHED ANALYSIS SYSTEM                        *
      *                                                                *
      * FIRST RAN 2026-04-01, ARTEMIS II LAUNCH DAY (V1).              *
      *                                                                *
      * INPUT : sites.csv       THE EIGHT GAGES, BASIN AND ORDER       *
      *         normals.csv     NORMAL FLOW FOR EACH DAY OF THE YEAR,  *
      *                         BUILT BY NORMALS.cob FROM 30 YEARS     *
      *         streamflow.csv  USGS DAILY MEANS, LAST 60 DAYS         *
      * OUTPUT: streamflow-report.txt  132-COLUMN PRINTED REPORT       *
      *         results.csv            THE SAME NUMBERS FOR THE WEB    *
      *                                                                *
      * FOR EACH GAGE: THE LATEST DAILY MEAN AGAINST THE NORMAL FOR    *
      * THAT DATE (USGS WATERWATCH CLASSES: BELOW THE 10TH PERCENTILE  *
      * IS MUCH BELOW NORMAL, 10-24 BELOW, 25-75 NORMAL, 76-90 ABOVE,  *
      * OVER 90 MUCH ABOVE); THE LAST 30 DAYS AGAINST THE NORMAL FOR   *
      * THOSE 30 DATES; AND THE LAST 7 DAYS AGAINST THE 7 BEFORE.      *
      *                                                                *
      * V3 FIXES (2026-10-02):                                         *
      *   - THE SORT CARRIED EACH STATION'S NUMBERS BUT NOT ITS        *
      *     BASELINE, SO AFTER SORTING THE MEDIANS AND THRESHOLDS      *
      *     BELONGED TO OTHER STATIONS. THE SORT NOW CARRIES ONLY      *
      *     THE TABLE INDEX.                                           *
      *   - THE TREND WORK FIELD WAS UNSIGNED, SO A FALLING RIVER      *
      *     COULD NEVER READ FALLING.                                  *
      *   - ONE MEDIAN PER GAGE ALL YEAR -> A NORMAL FOR EVERY DAY.    *
      *   - THE BASIN ROLL-UP ADDED UP GAGES ON THE SAME RIVER, SO     *
      *     THE SAME WATER WAS COUNTED UP TO FOUR TIMES. IT NOW        *
      *     REPORTS EACH BASIN'S LOWEST GAGE.                          *
      *                                                                *
      * RETURN CODE 0 = NORMAL, 4 = A GAGE IS STALE OR HAS NO DATA,    *
      *             12 = A FILE COULD NOT BE OPENED.                   *
      *                                                                *
      * COMPILE: cobc -x -o sierra-flow SIERRA-FLOW.cob                *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SIERRA-FLOW.
       AUTHOR. BROOKS GROVES.
       DATE-WRITTEN. 2026-04-01.
       SECURITY. UNCLASSIFIED - PUBLIC DATA.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. GNU-COBOL.
       OBJECT-COMPUTER. GNU-COBOL.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SITES-FILE ASSIGN TO 'sites.csv'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-SITES.
           SELECT NORMALS-FILE ASSIGN TO 'normals.csv'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-NORM.
           SELECT FLOW-FILE ASSIGN TO 'streamflow.csv'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-FLOW.
           SELECT REPORT-FILE ASSIGN TO 'streamflow-report.txt'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-RPT.
           SELECT RESULTS-FILE ASSIGN TO 'results.csv'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-RES.
           SELECT SORT-FILE ASSIGN TO 'sierra-sort.tmp'.

       DATA DIVISION.
       FILE SECTION.
       FD  SITES-FILE.
       01  SITES-REC                    PIC X(200).
       FD  NORMALS-FILE.
       01  NORMALS-REC                  PIC X(120).
       FD  FLOW-FILE.
       01  FLOW-REC                     PIC X(120).
       FD  REPORT-FILE.
       01  RPT-LINE                     PIC X(132).
       FD  RESULTS-FILE.
       01  RES-REC                      PIC X(400).

       SD  SORT-FILE.
       01  SORT-REC.
           05  SR-BASIN-SEQ             PIC 9.
           05  SR-SEQ                   PIC 99.
           05  SR-IDX                   PIC 99.

       WORKING-STORAGE SECTION.
      *--- FILE STATUS ---
       01  WS-FS-SITES                  PIC XX.
       01  WS-FS-NORM                   PIC XX.
       01  WS-FS-FLOW                   PIC XX.
       01  WS-FS-RPT                    PIC XX.
       01  WS-FS-RES                    PIC XX.
       01  WS-EOF                       PIC X.
           88  AT-EOF                   VALUE 'Y'.
       01  WS-FIRST                     PIC X.

      *--- CSV FIELDS (UNSTRING TARGETS) ---
       01  WS-FIELDS.
           05  WS-FLD                   PIC X(60) OCCURS 11.

      *--- DAYS BEFORE EACH MONTH, LEAP-YEAR CALENDAR (FEB 29 = 60) ---
       01  WS-CUM-DATA.
           05  FILLER                   PIC X(36) VALUE
               '000031060091121152182213244274305335'.
       01  WS-CUM-TABLE REDEFINES WS-CUM-DATA.
           05  WS-CUM                   PIC 999 OCCURS 12.

      *--- THE GAGES ---
       01  WS-NSITES                    PIC 99 VALUE 0.
       01  WS-SITE-TABLE.
           05  WS-SITE OCCURS 12 INDEXED BY SX.
               10  S-ID                 PIC X(8).
               10  S-NAME               PIC X(26).
               10  S-BASIN              PIC X(12).
               10  S-BASIN-SEQ          PIC 9.
               10  S-SEQ                PIC 99.
               10  S-REG                PIC X(10).
               10  S-NDAYS              PIC 99.
               10  S-DAY OCCURS 70.
                   15  D-DATE           PIC X(10).
                   15  D-INT            PIC 9(8).
                   15  D-SLOT           PIC 999.
                   15  D-FLOW           PIC 9(7)V99.
               10  S-NORM OCCURS 366.
                   15  N-YEARS          PIC 99.
                   15  N-P10            PIC 9(7)V99.
                   15  N-P25            PIC 9(7)V99.
                   15  N-P50            PIC 9(7)V99.
                   15  N-P75            PIC 9(7)V99.
                   15  N-P90            PIC 9(7)V99.
      *--- RESULTS FOR THE GAGE ---
               10  R-LAST-DATE          PIC X(10).
               10  R-LAST-SLOT          PIC 999.
               10  R-LAST-FLOW          PIC 9(7)V99.
               10  R-CLASS              PIC X(17).
               10  R-PCT-MED            PIC 9(5)V9.
               10  R-HAS-MED            PIC X.
               10  R-MEAN30             PIC 9(7)V99.
               10  R-MIN30              PIC 9(7)V99.
               10  R-MAX30              PIC 9(7)V99.
               10  R-N30                PIC 99.
               10  R-PCT30              PIC 9(5)V9.
               10  R-HAS-PCT30          PIC X.
               10  R-LOW-DAYS           PIC 99.
               10  R-HIGH-DAYS          PIC 99.
               10  R-TREND              PIC X(7).
               10  R-TREND-PCT          PIC S9(5)V9.
               10  R-HAS-TREND          PIC X.
               10  R-AGE                PIC 9(4).
               10  R-STALE              PIC X.

      *--- SORTED ORDER (TABLE INDEXES) ---
       01  WS-NORDER                    PIC 99 VALUE 0.
       01  WS-ORDER-TABLE.
           05  WS-ORDER                 PIC 99 OCCURS 12.
       01  WS-OI                        PIC 99.

      *--- BASINS ---
       01  WS-NBASINS                   PIC 9 VALUE 0.
       01  WS-BASIN-TABLE.
           05  WS-BASIN OCCURS 5 INDEXED BY BX.
               10  B-NAME               PIC X(12).
               10  B-SEQ                PIC 9.
               10  B-GAGES              PIC 9.
               10  B-OUTLET             PIC 99.
               10  B-OUTLET-SEQ         PIC 99.
               10  B-CLASS-N            PIC 9 OCCURS 5.

      *--- WORK FIELDS ---
       01  WS-I                         PIC 99.
       01  WS-J                         PIC 99.
       01  WS-K                         PIC 99.
       01  WS-FOUND                     PIC 99.
       01  WS-LAST                      PIC 99.
       01  WS-FROM                      PIC 99.
       01  WS-SLOT                      PIC 999.
       01  WS-MONTH                     PIC 99.
       01  WS-DAYN                      PIC 99.
       01  WS-YMD-X                     PIC X(8).
       01  WS-YMD REDEFINES WS-YMD-X    PIC 9(8).
       01  WS-FLOW                      PIC 9(7)V99.
       01  WS-CLASS                     PIC X(17).
       01  WS-CLASS-I                   PIC 9.
       01  WS-SUM                       PIC 9(9)V99.
       01  WS-SUM-MED                   PIC 9(9)V99.
       01  WS-MED-DAYS                  PIC 99.
       01  WS-MEAN-A                    PIC 9(7)V99.
       01  WS-MEAN-B                    PIC 9(7)V99.
       01  WS-CHANGE                    PIC S9(7)V99.

      *--- RUN DATE AND COUNTS ---
       01  WS-NOW                       PIC X(21).
       01  WS-RUN-YMD                   PIC 9(8).
       01  WS-RUN-INT                   PIC 9(8).
       01  WS-RUN-DATE                  PIC X(10).
       01  WS-RUN-TIME                  PIC X(8).
       01  WS-RUN-TZ                    PIC X(9).
       01  WS-RC                        PIC 99 VALUE 0.
       01  WS-SITES-READ                PIC 9(4) VALUE 0.
       01  WS-NORMS-READ                PIC 9(6) VALUE 0.
       01  WS-FLOWS-READ                PIC 9(6) VALUE 0.
       01  WS-SKIPPED                   PIC 9(6) VALUE 0.
       01  WS-STALE                     PIC 99 VALUE 0.

      *--- EDITED FIELDS ---
       01  WS-ED-CNT                    PIC Z(5)9.
       01  WS-ED-CFS                    PIC Z(6)9.99.
       01  WS-ED-PCT                    PIC Z(4)9.9.
       01  WS-ED-SPCT                   PIC -(5)9.9.
       01  WS-ED-SMALL                  PIC Z9.
       01  WS-PTR                       PIC 9(3).

      *--- REPORT LINES ---
       01  WS-RULE-EQ                   PIC X(132) VALUE ALL '='.
       01  WS-RULE-DASH                 PIC X(132) VALUE ALL '-'.
       01  WS-BLANK                     PIC X(132) VALUE SPACES.
       01  WS-LINE                      PIC X(132).

       01  WS-S1-HEAD.
           05  FILLER PIC X(11) VALUE '  SITE ID'.
           05  FILLER PIC X(27) VALUE 'STATION'.
           05  FILLER PIC X(11) VALUE 'DATE'.
           05  FILLER PIC X(9)  VALUE '      CFS'.
           05  FILLER PIC X(9)  VALUE '      P10'.
           05  FILLER PIC X(9)  VALUE '      P25'.
           05  FILLER PIC X(9)  VALUE '   MEDIAN'.
           05  FILLER PIC X(9)  VALUE '      P75'.
           05  FILLER PIC X(9)  VALUE '      P90'.
           05  FILLER PIC X(9)  VALUE '    % MED'.
           05  FILLER PIC X(20) VALUE '  CLASS'.

       01  WS-S1-LINE.
           05  FILLER                   PIC XX VALUE SPACES.
           05  L1-ID                    PIC X(8).
           05  FILLER                   PIC X VALUE SPACE.
           05  L1-NAME                  PIC X(26).
           05  FILLER                   PIC X VALUE SPACE.
           05  L1-DATE                  PIC X(10).
           05  L1-FLAG                  PIC X.
           05  FILLER                   PIC X VALUE SPACE.
           05  L1-CFS                   PIC Z(4)9.99.
           05  FILLER                   PIC X VALUE SPACE.
           05  L1-P10                   PIC Z(4)9.99.
           05  FILLER                   PIC X VALUE SPACE.
           05  L1-P25                   PIC Z(4)9.99.
           05  FILLER                   PIC X VALUE SPACE.
           05  L1-P50                   PIC Z(4)9.99.
           05  FILLER                   PIC X VALUE SPACE.
           05  L1-P75                   PIC Z(4)9.99.
           05  FILLER                   PIC X VALUE SPACE.
           05  L1-P90                   PIC Z(4)9.99.
           05  FILLER                   PIC X VALUE SPACE.
           05  L1-PCT                   PIC X(8).
           05  FILLER                   PIC XX VALUE SPACES.
           05  L1-CLASS                 PIC X(17).

       01  WS-S2-HEAD.
           05  FILLER PIC X(12) VALUE '  SITE ID'.
           05  FILLER PIC X(27) VALUE 'STATION'.
           05  FILLER PIC X(6)  VALUE 'DAYS'.
           05  FILLER PIC X(11) VALUE '  MEAN CFS'.
           05  FILLER PIC X(11) VALUE '   MIN CFS'.
           05  FILLER PIC X(11) VALUE '   MAX CFS'.
           05  FILLER PIC X(9)  VALUE ' % NORMAL'.
           05  FILLER PIC X(9)  VALUE ' DAYS<P10'.
           05  FILLER PIC X(9)  VALUE ' DAYS>P90'.
           05  FILLER PIC X(20) VALUE '  7-DAY TREND'.

       01  WS-S2-LINE.
           05  FILLER                   PIC XX VALUE SPACES.
           05  L2-ID                    PIC X(8).
           05  FILLER                   PIC XX VALUE SPACES.
           05  L2-NAME                  PIC X(26).
           05  FILLER                   PIC X VALUE SPACE.
           05  L2-DAYS                  PIC ZZZ9.
           05  FILLER                   PIC XX VALUE SPACES.
           05  L2-MEAN                  PIC Z(6)9.99.
           05  FILLER                   PIC X VALUE SPACE.
           05  L2-MIN                   PIC Z(6)9.99.
           05  FILLER                   PIC X VALUE SPACE.
           05  L2-MAX                   PIC Z(6)9.99.
           05  FILLER                   PIC X VALUE SPACE.
           05  L2-PCT                   PIC X(9).
           05  FILLER                   PIC X(7) VALUE SPACES.
           05  L2-LOW                   PIC Z9.
           05  FILLER                   PIC X(7) VALUE SPACES.
           05  L2-HIGH                  PIC Z9.
           05  FILLER                   PIC XX VALUE SPACES.
           05  L2-TREND                 PIC X(7).
           05  FILLER                   PIC X VALUE SPACE.
           05  L2-TPCT                  PIC X(9).

       01  WS-S3-HEAD.
           05  FILLER PIC X(14) VALUE '  BASIN'.
           05  FILLER PIC X(8)  VALUE 'GAGES'.
           05  FILLER PIC X(28) VALUE 'LOWEST GAGE (BASIN OUTFLOW)'.
           05  FILLER PIC X(9)  VALUE '      CFS'.
           05  FILLER PIC X(19) VALUE '  CLASS'.
           05  FILLER PIC X(11) VALUE ' MUCH BELOW'.
           05  FILLER PIC X(7)  VALUE '  BELOW'.
           05  FILLER PIC X(7)  VALUE ' NORMAL'.
           05  FILLER PIC X(7)  VALUE '  ABOVE'.
           05  FILLER PIC X(11) VALUE ' MUCH ABOVE'.

       01  WS-S3-LINE.
           05  FILLER                   PIC XX VALUE SPACES.
           05  L3-BASIN                 PIC X(12).
           05  FILLER                   PIC X VALUE SPACE.
           05  L3-GAGES                 PIC Z9.
           05  FILLER                   PIC X(5) VALUE SPACES.
           05  L3-OUTLET                PIC X(26).
           05  FILLER                   PIC XX VALUE SPACES.
           05  L3-CFS                   PIC Z(5)9.99.
           05  FILLER                   PIC XX VALUE SPACES.
           05  L3-CLASS                 PIC X(17).
           05  FILLER                   PIC X(9) VALUE SPACES.
           05  L3-C1                    PIC Z9.
           05  FILLER                   PIC X(5) VALUE SPACES.
           05  L3-C2                    PIC Z9.
           05  FILLER                   PIC X(5) VALUE SPACES.
           05  L3-C3                    PIC Z9.
           05  FILLER                   PIC X(5) VALUE SPACES.
           05  L3-C4                    PIC Z9.
           05  FILLER                   PIC X(9) VALUE SPACES.
           05  L3-C5                    PIC Z9.

       01  WS-SUM-LINE.
           05  FILLER                   PIC X(4) VALUE SPACES.
           05  SL-LABEL                 PIC X(34).
           05  SL-VALUE                 PIC Z(5)9.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-SITES
           PERFORM 2500-LOAD-NORMALS
           PERFORM 3000-LOAD-FLOWS
           PERFORM 4000-ANALYZE-GAGE
               VARYING SX FROM 1 BY 1 UNTIL SX > WS-NSITES
           PERFORM 5000-SORT-GAGES
           PERFORM 5500-BUILD-BASINS
           PERFORM 6000-WRITE-REPORT
           PERFORM 7000-WRITE-RESULTS
           PERFORM 9000-TERMINATE
           STOP RUN.

      *================================================================*
       1000-INITIALIZE.
      *================================================================*
           MOVE FUNCTION CURRENT-DATE TO WS-NOW
           MOVE WS-NOW(1:8) TO WS-RUN-YMD
           COMPUTE WS-RUN-INT = FUNCTION INTEGER-OF-DATE(WS-RUN-YMD)
           STRING WS-NOW(1:4) '-' WS-NOW(5:2) '-' WS-NOW(7:2)
               DELIMITED BY SIZE INTO WS-RUN-DATE
           END-STRING
           STRING WS-NOW(9:2) ':' WS-NOW(11:2) ':' WS-NOW(13:2)
               DELIMITED BY SIZE INTO WS-RUN-TIME
           END-STRING
           IF WS-NOW(17:5) = '+0000' OR WS-NOW(17:5) = '-0000'
               MOVE 'UTC' TO WS-RUN-TZ
           ELSE
               STRING 'UTC' WS-NOW(17:3) ':' WS-NOW(20:2)
                   DELIMITED BY SIZE INTO WS-RUN-TZ
               END-STRING
           END-IF
           INITIALIZE WS-SITE-TABLE
           INITIALIZE WS-BASIN-TABLE
           DISPLAY 'SFLW000I SIERRA-FLOW V3.0 STARTED ' WS-RUN-DATE
               ' ' WS-RUN-TIME ' ' FUNCTION TRIM(WS-RUN-TZ).

      *================================================================*
       2000-LOAD-SITES.
      *================================================================*
           OPEN INPUT SITES-FILE
           IF WS-FS-SITES NOT = '00'
               DISPLAY 'SFLW901E CANNOT OPEN sites.csv'
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE 'N' TO WS-EOF
           MOVE 'Y' TO WS-FIRST
           PERFORM UNTIL AT-EOF
               READ SITES-FILE
                   AT END SET AT-EOF TO TRUE
                   NOT AT END PERFORM 2100-ONE-SITE
               END-READ
           END-PERFORM
           CLOSE SITES-FILE
           MOVE WS-NSITES TO WS-ED-CNT
           DISPLAY 'SFLW001I GAGES LOADED ..............' WS-ED-CNT.

       2100-ONE-SITE.
           IF WS-FIRST = 'Y'
               MOVE 'N' TO WS-FIRST
               EXIT PARAGRAPH
           END-IF
           IF WS-NSITES >= 12
               EXIT PARAGRAPH
           END-IF
           PERFORM 8000-SPLIT-SITES
           ADD 1 TO WS-NSITES
           SET SX TO WS-NSITES
           MOVE WS-FLD(1)  TO S-ID(SX)
           MOVE WS-FLD(2)  TO S-NAME(SX)
           MOVE WS-FLD(3)  TO S-BASIN(SX)
           MOVE FUNCTION NUMVAL(WS-FLD(4)) TO S-BASIN-SEQ(SX)
           MOVE FUNCTION NUMVAL(WS-FLD(5)) TO S-SEQ(SX)
           MOVE WS-FLD(7)  TO S-REG(SX).

      *================================================================*
       2500-LOAD-NORMALS.
      *================================================================*
           OPEN INPUT NORMALS-FILE
           IF WS-FS-NORM NOT = '00'
               DISPLAY 'SFLW902E CANNOT OPEN normals.csv'
               DISPLAY 'SFLW902E RUN NORMALS FIRST'
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE 'N' TO WS-EOF
           MOVE 'Y' TO WS-FIRST
           PERFORM UNTIL AT-EOF
               READ NORMALS-FILE
                   AT END SET AT-EOF TO TRUE
                   NOT AT END PERFORM 2600-ONE-NORMAL
               END-READ
           END-PERFORM
           CLOSE NORMALS-FILE
           MOVE WS-NORMS-READ TO WS-ED-CNT
           DISPLAY 'SFLW002I DAILY NORMALS LOADED ......' WS-ED-CNT.

       2600-ONE-NORMAL.
           IF WS-FIRST = 'Y'
               MOVE 'N' TO WS-FIRST
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-FIELDS
           UNSTRING NORMALS-REC DELIMITED BY ','
               INTO WS-FLD(1) WS-FLD(2) WS-FLD(3) WS-FLD(4)
                    WS-FLD(5) WS-FLD(6) WS-FLD(7) WS-FLD(8)
                    WS-FLD(9) WS-FLD(10) WS-FLD(11)
           END-UNSTRING
           PERFORM 8100-FIND-SITE
           IF WS-FOUND = 0
               EXIT PARAGRAPH
           END-IF
           MOVE FUNCTION NUMVAL(WS-FLD(2)) TO WS-SLOT
           IF WS-SLOT < 1 OR WS-SLOT > 366
               EXIT PARAGRAPH
           END-IF
           SET SX TO WS-FOUND
           MOVE FUNCTION NUMVAL(WS-FLD(6))  TO N-YEARS(SX, WS-SLOT)
           MOVE FUNCTION NUMVAL(WS-FLD(7))  TO N-P10(SX, WS-SLOT)
           MOVE FUNCTION NUMVAL(WS-FLD(8))  TO N-P25(SX, WS-SLOT)
           MOVE FUNCTION NUMVAL(WS-FLD(9))  TO N-P50(SX, WS-SLOT)
           MOVE FUNCTION NUMVAL(WS-FLD(10)) TO N-P75(SX, WS-SLOT)
           MOVE FUNCTION NUMVAL(WS-FLD(11)) TO N-P90(SX, WS-SLOT)
           ADD 1 TO WS-NORMS-READ.

      *================================================================*
       3000-LOAD-FLOWS.
      *================================================================*
           OPEN INPUT FLOW-FILE
           IF WS-FS-FLOW NOT = '00'
               DISPLAY 'SFLW903E CANNOT OPEN streamflow.csv'
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE 'N' TO WS-EOF
           MOVE 'Y' TO WS-FIRST
           PERFORM UNTIL AT-EOF
               READ FLOW-FILE
                   AT END SET AT-EOF TO TRUE
                   NOT AT END PERFORM 3100-ONE-FLOW
               END-READ
           END-PERFORM
           CLOSE FLOW-FILE
           MOVE WS-FLOWS-READ TO WS-ED-CNT
           DISPLAY 'SFLW003I DAILY MEANS LOADED ........' WS-ED-CNT
           MOVE WS-SKIPPED TO WS-ED-CNT
           DISPLAY 'SFLW004I RECORDS SKIPPED ...........' WS-ED-CNT.

       3100-ONE-FLOW.
           IF WS-FIRST = 'Y'
               MOVE 'N' TO WS-FIRST
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-FIELDS
           UNSTRING FLOW-REC DELIMITED BY ','
               INTO WS-FLD(1) WS-FLD(2) WS-FLD(3) WS-FLD(4)
           END-UNSTRING
           PERFORM 8100-FIND-SITE
           IF WS-FOUND = 0 OR WS-FLD(3) = SPACES
                  OR WS-FLD(2)(5:1) NOT = '-'
               ADD 1 TO WS-SKIPPED
               EXIT PARAGRAPH
           END-IF
           SET SX TO WS-FOUND
           IF S-NDAYS(SX) >= 70
               ADD 1 TO WS-SKIPPED
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO S-NDAYS(SX)
           MOVE S-NDAYS(SX) TO WS-I
           MOVE WS-FLD(2)(1:10) TO D-DATE(SX, WS-I)
           STRING WS-FLD(2)(1:4) WS-FLD(2)(6:2) WS-FLD(2)(9:2)
               DELIMITED BY SIZE INTO WS-YMD-X
           END-STRING
           COMPUTE D-INT(SX, WS-I) =
               FUNCTION INTEGER-OF-DATE(WS-YMD)
           MOVE WS-FLD(2)(6:2) TO WS-MONTH
           MOVE WS-FLD(2)(9:2) TO WS-DAYN
           COMPUTE D-SLOT(SX, WS-I) = WS-CUM(WS-MONTH) + WS-DAYN
           COMPUTE D-FLOW(SX, WS-I) = FUNCTION NUMVAL(WS-FLD(3))
           ADD 1 TO WS-FLOWS-READ.

      *================================================================*
      * ONE GAGE: TODAY VS NORMAL, 30 DAYS VS NORMAL, 7-DAY TREND      *
      *================================================================*
       4000-ANALYZE-GAGE.
           IF S-NDAYS(SX) = 0
               MOVE 'NO DATA'  TO R-CLASS(SX)
               MOVE 'Y'        TO R-STALE(SX)
               MOVE 'N'        TO R-HAS-MED(SX) R-HAS-PCT30(SX)
                                  R-HAS-TREND(SX)
               ADD 1 TO WS-STALE
               MOVE 4 TO WS-RC
               DISPLAY 'SFLW010W NO DATA FOR ' S-ID(SX)
               EXIT PARAGRAPH
           END-IF
           MOVE S-NDAYS(SX) TO WS-LAST
           MOVE D-DATE(SX, WS-LAST) TO R-LAST-DATE(SX)
           MOVE D-SLOT(SX, WS-LAST) TO R-LAST-SLOT(SX)
           MOVE D-FLOW(SX, WS-LAST) TO R-LAST-FLOW(SX)

      *--- HOW OLD IS THE LATEST DAY? ---
           COMPUTE R-AGE(SX) = WS-RUN-INT - D-INT(SX, WS-LAST)
           IF R-AGE(SX) > 3
               MOVE 'Y' TO R-STALE(SX)
               ADD 1 TO WS-STALE
               MOVE 4 TO WS-RC
               DISPLAY 'SFLW011W STALE DATA FOR ' S-ID(SX)
                   ' LAST DAY ' R-LAST-DATE(SX)
           ELSE
               MOVE 'N' TO R-STALE(SX)
           END-IF

      *--- LATEST DAY AGAINST THE NORMAL FOR ITS DATE ---
           MOVE R-LAST-FLOW(SX) TO WS-FLOW
           MOVE R-LAST-SLOT(SX) TO WS-SLOT
           PERFORM 4100-CLASSIFY
           MOVE WS-CLASS TO R-CLASS(SX)
           IF N-YEARS(SX, WS-SLOT) >= 10 AND N-P50(SX, WS-SLOT) > 0
               COMPUTE R-PCT-MED(SX) ROUNDED =
                   WS-FLOW / N-P50(SX, WS-SLOT) * 100
                   ON SIZE ERROR MOVE 99999.9 TO R-PCT-MED(SX)
               END-COMPUTE
               MOVE 'Y' TO R-HAS-MED(SX)
           ELSE
               MOVE 'N' TO R-HAS-MED(SX)
           END-IF

      *--- LAST 30 DAYS ---
           IF WS-LAST > 30
               COMPUTE WS-FROM = WS-LAST - 29
           ELSE
               MOVE 1 TO WS-FROM
           END-IF
           MOVE 0 TO WS-SUM WS-SUM-MED WS-MED-DAYS
           MOVE 0 TO R-LOW-DAYS(SX) R-HIGH-DAYS(SX) R-N30(SX)
           MOVE 9999999.99 TO R-MIN30(SX)
           MOVE 0 TO R-MAX30(SX)
           PERFORM VARYING WS-I FROM WS-FROM BY 1 UNTIL WS-I > WS-LAST
               MOVE D-FLOW(SX, WS-I) TO WS-FLOW
               MOVE D-SLOT(SX, WS-I) TO WS-SLOT
               ADD 1 TO R-N30(SX)
               ADD WS-FLOW TO WS-SUM
               IF WS-FLOW < R-MIN30(SX)
                   MOVE WS-FLOW TO R-MIN30(SX)
               END-IF
               IF WS-FLOW > R-MAX30(SX)
                   MOVE WS-FLOW TO R-MAX30(SX)
               END-IF
               IF N-YEARS(SX, WS-SLOT) >= 10
                   ADD N-P50(SX, WS-SLOT) TO WS-SUM-MED
                   ADD 1 TO WS-MED-DAYS
                   IF WS-FLOW < N-P10(SX, WS-SLOT)
                       ADD 1 TO R-LOW-DAYS(SX)
                   END-IF
                   IF WS-FLOW > N-P90(SX, WS-SLOT)
                       ADD 1 TO R-HIGH-DAYS(SX)
                   END-IF
               END-IF
           END-PERFORM
           COMPUTE R-MEAN30(SX) ROUNDED = WS-SUM / R-N30(SX)
           IF WS-MED-DAYS = R-N30(SX) AND WS-SUM-MED > 0
               COMPUTE R-PCT30(SX) ROUNDED = WS-SUM / WS-SUM-MED * 100
                   ON SIZE ERROR MOVE 99999.9 TO R-PCT30(SX)
               END-COMPUTE
               MOVE 'Y' TO R-HAS-PCT30(SX)
           ELSE
               MOVE 'N' TO R-HAS-PCT30(SX)
           END-IF

      *--- LAST 7 DAYS AGAINST THE 7 BEFORE ---
           MOVE 'N' TO R-HAS-TREND(SX)
           MOVE 'STEADY' TO R-TREND(SX)
           MOVE 0 TO R-TREND-PCT(SX)
           IF WS-LAST >= 14
               MOVE 0 TO WS-SUM
               COMPUTE WS-FROM = WS-LAST - 6
               PERFORM VARYING WS-I FROM WS-FROM BY 1
                       UNTIL WS-I > WS-LAST
                   ADD D-FLOW(SX, WS-I) TO WS-SUM
               END-PERFORM
               COMPUTE WS-MEAN-A ROUNDED = WS-SUM / 7
               MOVE 0 TO WS-SUM
               COMPUTE WS-FROM = WS-LAST - 13
               COMPUTE WS-K = WS-LAST - 7
               PERFORM VARYING WS-I FROM WS-FROM BY 1
                       UNTIL WS-I > WS-K
                   ADD D-FLOW(SX, WS-I) TO WS-SUM
               END-PERFORM
               COMPUTE WS-MEAN-B ROUNDED = WS-SUM / 7
               MOVE 'Y' TO R-HAS-TREND(SX)
               IF WS-MEAN-B > 0
                   COMPUTE WS-CHANGE = WS-MEAN-A - WS-MEAN-B
                   COMPUTE R-TREND-PCT(SX) ROUNDED =
                       WS-CHANGE / WS-MEAN-B * 100
                       ON SIZE ERROR MOVE 9999.9 TO R-TREND-PCT(SX)
                   END-COMPUTE
               END-IF
               EVALUATE TRUE
                   WHEN WS-MEAN-A < 1 AND WS-MEAN-B < 1
                       MOVE 'STEADY'  TO R-TREND(SX)
                   WHEN WS-MEAN-B = 0
                       MOVE 'RISING'  TO R-TREND(SX)
                   WHEN R-TREND-PCT(SX) >= 10
                       MOVE 'RISING'  TO R-TREND(SX)
                   WHEN R-TREND-PCT(SX) <= -10
                       MOVE 'FALLING' TO R-TREND(SX)
                   WHEN OTHER
                       MOVE 'STEADY'  TO R-TREND(SX)
               END-EVALUATE
           END-IF.

      *================================================================*
      * WATERWATCH CLASS OF WS-FLOW FOR DAY WS-SLOT OF GAGE SX         *
      *================================================================*
       4100-CLASSIFY.
           EVALUATE TRUE
               WHEN N-YEARS(SX, WS-SLOT) < 10
                   MOVE 'NO NORMAL'         TO WS-CLASS
                   MOVE 0 TO WS-CLASS-I
               WHEN WS-FLOW < N-P10(SX, WS-SLOT)
                   MOVE 'MUCH BELOW NORMAL' TO WS-CLASS
                   MOVE 1 TO WS-CLASS-I
               WHEN WS-FLOW < N-P25(SX, WS-SLOT)
                   MOVE 'BELOW NORMAL'      TO WS-CLASS
                   MOVE 2 TO WS-CLASS-I
               WHEN WS-FLOW > N-P90(SX, WS-SLOT)
                   MOVE 'MUCH ABOVE NORMAL' TO WS-CLASS
                   MOVE 5 TO WS-CLASS-I
               WHEN WS-FLOW > N-P75(SX, WS-SLOT)
                   MOVE 'ABOVE NORMAL'      TO WS-CLASS
                   MOVE 4 TO WS-CLASS-I
               WHEN OTHER
                   MOVE 'NORMAL'            TO WS-CLASS
                   MOVE 3 TO WS-CLASS-I
           END-EVALUATE.

      *================================================================*
      * SORT BY BASIN, THEN UPSTREAM TO DOWNSTREAM. THE SORT RECORD    *
      * CARRIES THE TABLE INDEX, SO EVERY NUMBER STAYS WITH ITS GAGE.  *
      *================================================================*
       5000-SORT-GAGES.
           SORT SORT-FILE
               ON ASCENDING KEY SR-BASIN-SEQ SR-SEQ
               INPUT PROCEDURE 5100-SORT-IN
               OUTPUT PROCEDURE 5200-SORT-OUT.

       5100-SORT-IN.
           PERFORM VARYING SX FROM 1 BY 1 UNTIL SX > WS-NSITES
               MOVE S-BASIN-SEQ(SX) TO SR-BASIN-SEQ
               MOVE S-SEQ(SX)       TO SR-SEQ
               SET SR-IDX           TO SX
               RELEASE SORT-REC
           END-PERFORM.

       5200-SORT-OUT.
           MOVE 'N' TO WS-EOF
           PERFORM UNTIL AT-EOF
               RETURN SORT-FILE
                   AT END SET AT-EOF TO TRUE
                   NOT AT END
                       ADD 1 TO WS-NORDER
                       MOVE SR-IDX TO WS-ORDER(WS-NORDER)
               END-RETURN
           END-PERFORM.

      *================================================================*
      * BASINS: GAGE COUNT, CLASS COUNTS, AND THE LOWEST GAGE          *
      *================================================================*
       5500-BUILD-BASINS.
           PERFORM VARYING WS-OI FROM 1 BY 1 UNTIL WS-OI > WS-NORDER
               SET SX TO WS-ORDER(WS-OI)
               MOVE 0 TO WS-FOUND
               PERFORM VARYING BX FROM 1 BY 1 UNTIL BX > WS-NBASINS
                   IF B-NAME(BX) = S-BASIN(SX)
                       SET WS-FOUND TO BX
                   END-IF
               END-PERFORM
               IF WS-FOUND = 0
                   ADD 1 TO WS-NBASINS
                   MOVE WS-NBASINS TO WS-FOUND
                   SET BX TO WS-FOUND
                   MOVE S-BASIN(SX)     TO B-NAME(BX)
                   MOVE S-BASIN-SEQ(SX) TO B-SEQ(BX)
               END-IF
               SET BX TO WS-FOUND
               ADD 1 TO B-GAGES(BX)
               IF S-SEQ(SX) >= B-OUTLET-SEQ(BX)
                   MOVE S-SEQ(SX) TO B-OUTLET-SEQ(BX)
                   SET B-OUTLET(BX) TO SX
               END-IF
               IF S-NDAYS(SX) > 0
                   MOVE R-LAST-FLOW(SX) TO WS-FLOW
                   MOVE R-LAST-SLOT(SX) TO WS-SLOT
                   PERFORM 4100-CLASSIFY
                   IF WS-CLASS-I > 0
                       ADD 1 TO B-CLASS-N(BX, WS-CLASS-I)
                   END-IF
               END-IF
           END-PERFORM.

      *================================================================*
       6000-WRITE-REPORT.
      *================================================================*
           OPEN OUTPUT REPORT-FILE
           IF WS-FS-RPT NOT = '00'
               DISPLAY 'SFLW904E CANNOT OPEN streamflow-report.txt'
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 6100-BANNER
           PERFORM 6200-SECTION-I
           PERFORM 6300-SECTION-II
           PERFORM 6400-SECTION-III
           PERFORM 6500-SECTION-IV
           WRITE RPT-LINE FROM WS-RULE-EQ
           MOVE SPACES TO WS-LINE
           MOVE 'END OF REPORT - SIERRA-FLOW V3.0' TO WS-LINE(51:32)
           WRITE RPT-LINE FROM WS-LINE
           WRITE RPT-LINE FROM WS-RULE-EQ
           CLOSE REPORT-FILE.

       6100-BANNER.
           WRITE RPT-LINE FROM WS-RULE-EQ
           WRITE RPT-LINE FROM WS-BLANK
           MOVE SPACES TO WS-LINE
           MOVE 'SIERRA NEVADA WATERSHED ANALYSIS SYSTEM'
               TO WS-LINE(47:39)
           WRITE RPT-LINE FROM WS-LINE
           MOVE SPACES TO WS-LINE
           MOVE 'USGS STREAMFLOW DATA PROCESSING REPORT  V3.0'
               TO WS-LINE(45:44)
           WRITE RPT-LINE FROM WS-LINE
           MOVE SPACES TO WS-LINE
           STRING 'RUN ' WS-RUN-DATE ' ' WS-RUN-TIME ' '
               FUNCTION TRIM(WS-RUN-TZ)
               DELIMITED BY SIZE INTO WS-LINE(51:40)
           END-STRING
           WRITE RPT-LINE FROM WS-LINE
           WRITE RPT-LINE FROM WS-BLANK
           WRITE RPT-LINE FROM WS-RULE-EQ
           WRITE RPT-LINE FROM WS-BLANK.

       6200-SECTION-I.
           MOVE 'SECTION I: LATEST DAILY MEAN VS NORMAL FOR THE DATE'
               TO WS-LINE
           WRITE RPT-LINE FROM WS-LINE
           MOVE SPACES TO WS-LINE
           STRING '  NORMAL = PERCENTILES OF DAILY FLOW FOR THE DATE, '
               'WATER YEARS 1996-2025, 7-DAY WINDOW. CLASSES AS USGS '
               'WATERWATCH.' DELIMITED BY SIZE INTO WS-LINE
           END-STRING
           WRITE RPT-LINE FROM WS-LINE
           WRITE RPT-LINE FROM WS-BLANK
           WRITE RPT-LINE FROM WS-S1-HEAD
           WRITE RPT-LINE FROM WS-RULE-DASH
           PERFORM VARYING WS-OI FROM 1 BY 1 UNTIL WS-OI > WS-NORDER
               SET SX TO WS-ORDER(WS-OI)
               MOVE SPACES TO WS-S1-LINE
               MOVE S-ID(SX)   TO L1-ID
               MOVE S-NAME(SX) TO L1-NAME
               IF S-NDAYS(SX) = 0
                   MOVE 'NO DATA' TO L1-CLASS
               ELSE
                   MOVE R-LAST-SLOT(SX) TO WS-SLOT
                   MOVE R-LAST-DATE(SX) TO L1-DATE
                   MOVE R-LAST-FLOW(SX) TO L1-CFS
                   MOVE N-P10(SX, WS-SLOT) TO L1-P10
                   MOVE N-P25(SX, WS-SLOT) TO L1-P25
                   MOVE N-P50(SX, WS-SLOT) TO L1-P50
                   MOVE N-P75(SX, WS-SLOT) TO L1-P75
                   MOVE N-P90(SX, WS-SLOT) TO L1-P90
                   IF R-HAS-MED(SX) = 'Y'
                       MOVE R-PCT-MED(SX) TO WS-ED-PCT
                       STRING WS-ED-PCT '%' DELIMITED BY SIZE
                           INTO L1-PCT
                       END-STRING
                   ELSE
                       MOVE '     --' TO L1-PCT
                   END-IF
                   MOVE R-CLASS(SX) TO L1-CLASS
                   IF R-STALE(SX) = 'Y'
                       MOVE '*' TO L1-FLAG
                   END-IF
               END-IF
               WRITE RPT-LINE FROM WS-S1-LINE
           END-PERFORM
           WRITE RPT-LINE FROM WS-BLANK.

       6300-SECTION-II.
           MOVE 'SECTION II: LAST 30 DAYS VS NORMAL FOR THOSE DATES'
               TO WS-LINE
           WRITE RPT-LINE FROM WS-LINE
           MOVE SPACES TO WS-LINE
           STRING '  % NORMAL = 30-DAY TOTAL FLOW / TOTAL OF THE DAILY '
               'MEDIANS. TREND = LAST 7 DAYS VS THE 7 BEFORE, '
               '+/-10% OR MORE.' DELIMITED BY SIZE INTO WS-LINE
           END-STRING
           WRITE RPT-LINE FROM WS-LINE
           WRITE RPT-LINE FROM WS-BLANK
           WRITE RPT-LINE FROM WS-S2-HEAD
           WRITE RPT-LINE FROM WS-RULE-DASH
           PERFORM VARYING WS-OI FROM 1 BY 1 UNTIL WS-OI > WS-NORDER
               SET SX TO WS-ORDER(WS-OI)
               IF S-NDAYS(SX) > 0
                   MOVE SPACES TO WS-S2-LINE
                   MOVE S-ID(SX)        TO L2-ID
                   MOVE S-NAME(SX)      TO L2-NAME
                   MOVE R-N30(SX)       TO L2-DAYS
                   MOVE R-MEAN30(SX)    TO L2-MEAN
                   MOVE R-MIN30(SX)     TO L2-MIN
                   MOVE R-MAX30(SX)     TO L2-MAX
                   IF R-HAS-PCT30(SX) = 'Y'
                       MOVE R-PCT30(SX) TO WS-ED-PCT
                       STRING ' ' WS-ED-PCT '%' DELIMITED BY SIZE
                           INTO L2-PCT
                       END-STRING
                   ELSE
                       MOVE '      --' TO L2-PCT
                   END-IF
                   MOVE R-LOW-DAYS(SX)  TO L2-LOW
                   MOVE R-HIGH-DAYS(SX) TO L2-HIGH
                   MOVE R-TREND(SX)     TO L2-TREND
                   IF R-HAS-TREND(SX) = 'Y'
                      AND R-TREND(SX) NOT = 'STEADY'
                       MOVE R-TREND-PCT(SX) TO WS-ED-SPCT
                       STRING WS-ED-SPCT '%' DELIMITED BY SIZE
                           INTO L2-TPCT
                       END-STRING
                   END-IF
                   WRITE RPT-LINE FROM WS-S2-LINE
               END-IF
           END-PERFORM
           WRITE RPT-LINE FROM WS-BLANK.

       6400-SECTION-III.
           MOVE 'SECTION III: WATERSHED BASINS' TO WS-LINE
           WRITE RPT-LINE FROM WS-LINE
           MOVE SPACES TO WS-LINE
           STRING '  GAGES ON ONE RIVER MEASURE THE SAME WATER, SO '
               'THEY ARE NOT ADDED. THE LOWEST GAGE IS WHAT LEAVES '
               'THE BASIN.' DELIMITED BY SIZE INTO WS-LINE
           END-STRING
           WRITE RPT-LINE FROM WS-LINE
           WRITE RPT-LINE FROM WS-BLANK
           WRITE RPT-LINE FROM WS-S3-HEAD
           WRITE RPT-LINE FROM WS-RULE-DASH
           PERFORM VARYING BX FROM 1 BY 1 UNTIL BX > WS-NBASINS
               MOVE SPACES TO WS-S3-LINE
               MOVE B-NAME(BX)  TO L3-BASIN
               MOVE B-GAGES(BX) TO L3-GAGES
               SET SX TO B-OUTLET(BX)
               MOVE S-NAME(SX)  TO L3-OUTLET
               MOVE R-LAST-FLOW(SX) TO L3-CFS
               MOVE R-CLASS(SX) TO L3-CLASS
               MOVE B-CLASS-N(BX, 1) TO L3-C1
               MOVE B-CLASS-N(BX, 2) TO L3-C2
               MOVE B-CLASS-N(BX, 3) TO L3-C3
               MOVE B-CLASS-N(BX, 4) TO L3-C4
               MOVE B-CLASS-N(BX, 5) TO L3-C5
               WRITE RPT-LINE FROM WS-S3-LINE
           END-PERFORM
           WRITE RPT-LINE FROM WS-BLANK.

       6500-SECTION-IV.
           MOVE 'SECTION IV: RUN SUMMARY' TO WS-LINE
           WRITE RPT-LINE FROM WS-LINE
           WRITE RPT-LINE FROM WS-BLANK
           MOVE 'GAGES PROCESSED ...................' TO SL-LABEL
           MOVE WS-NSITES TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUM-LINE
           MOVE 'DAILY NORMALS READ ................' TO SL-LABEL
           MOVE WS-NORMS-READ TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUM-LINE
           MOVE 'DAILY MEANS READ ..................' TO SL-LABEL
           MOVE WS-FLOWS-READ TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUM-LINE
           MOVE 'RECORDS SKIPPED (INVALID) .........' TO SL-LABEL
           MOVE WS-SKIPPED TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUM-LINE
           MOVE 'GAGES STALE OR WITHOUT DATA .......' TO SL-LABEL
           MOVE WS-STALE TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUM-LINE
           MOVE 'WATERSHED BASINS ..................' TO SL-LABEL
           MOVE WS-NBASINS TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUM-LINE
           MOVE 'RETURN CODE .......................' TO SL-LABEL
           MOVE WS-RC TO SL-VALUE
           WRITE RPT-LINE FROM WS-SUM-LINE
           WRITE RPT-LINE FROM WS-BLANK.

      *================================================================*
      * results.csv: THE SAME NUMBERS, ONE LINE PER GAGE, FOR THE WEB  *
      *================================================================*
       7000-WRITE-RESULTS.
           OPEN OUTPUT RESULTS-FILE
           IF WS-FS-RES NOT = '00'
               DISPLAY 'SFLW905E CANNOT OPEN results.csv'
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE SPACES TO RES-REC
           STRING 'site_id,basin,seq,last_date,last_cfs,n_years,'
               'p10,p25,p50,p75,p90,class,pct_median,days_30,'
               'mean_30,min_30,max_30,pct_normal_30,days_below_p10,'
               'days_above_p90,trend,trend_pct,stale,run_date,'
               'run_time,rc' DELIMITED BY SIZE INTO RES-REC
           END-STRING
           WRITE RES-REC
           PERFORM VARYING WS-OI FROM 1 BY 1 UNTIL WS-OI > WS-NORDER
               SET SX TO WS-ORDER(WS-OI)
               PERFORM 7100-RESULT-LINE
           END-PERFORM
           CLOSE RESULTS-FILE.

       7100-RESULT-LINE.
           MOVE SPACES TO RES-REC
           MOVE 1 TO WS-PTR
           MOVE S-SEQ(SX) TO WS-ED-SMALL
           STRING FUNCTION TRIM(S-ID(SX)) ','
                  FUNCTION TRIM(S-BASIN(SX)) ','
                  FUNCTION TRIM(WS-ED-SMALL) ','
                  FUNCTION TRIM(R-LAST-DATE(SX)) ','
                  DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
           END-STRING
           IF S-NDAYS(SX) = 0
               STRING ',,,,,,,NO DATA,,,,,,,,,,,Y,'
                   DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
               END-STRING
               PERFORM 7200-RUN-FIELDS
               WRITE RES-REC
               EXIT PARAGRAPH
           END-IF
           MOVE R-LAST-SLOT(SX) TO WS-SLOT
           MOVE R-LAST-FLOW(SX) TO WS-ED-CFS
           PERFORM 7300-ADD-CFS
           MOVE N-YEARS(SX, WS-SLOT) TO WS-ED-SMALL
           STRING FUNCTION TRIM(WS-ED-SMALL) ','
               DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
           END-STRING
           MOVE N-P10(SX, WS-SLOT) TO WS-ED-CFS
           PERFORM 7300-ADD-CFS
           MOVE N-P25(SX, WS-SLOT) TO WS-ED-CFS
           PERFORM 7300-ADD-CFS
           MOVE N-P50(SX, WS-SLOT) TO WS-ED-CFS
           PERFORM 7300-ADD-CFS
           MOVE N-P75(SX, WS-SLOT) TO WS-ED-CFS
           PERFORM 7300-ADD-CFS
           MOVE N-P90(SX, WS-SLOT) TO WS-ED-CFS
           PERFORM 7300-ADD-CFS
           STRING FUNCTION TRIM(R-CLASS(SX)) ','
               DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
           END-STRING
           IF R-HAS-MED(SX) = 'Y'
               MOVE R-PCT-MED(SX) TO WS-ED-PCT
               STRING FUNCTION TRIM(WS-ED-PCT)
                   DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
               END-STRING
           END-IF
           MOVE R-N30(SX) TO WS-ED-SMALL
           STRING ',' FUNCTION TRIM(WS-ED-SMALL) ','
               DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
           END-STRING
           MOVE R-MEAN30(SX) TO WS-ED-CFS
           PERFORM 7300-ADD-CFS
           MOVE R-MIN30(SX) TO WS-ED-CFS
           PERFORM 7300-ADD-CFS
           MOVE R-MAX30(SX) TO WS-ED-CFS
           PERFORM 7300-ADD-CFS
           IF R-HAS-PCT30(SX) = 'Y'
               MOVE R-PCT30(SX) TO WS-ED-PCT
               STRING FUNCTION TRIM(WS-ED-PCT)
                   DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
               END-STRING
           END-IF
           MOVE R-LOW-DAYS(SX) TO WS-ED-SMALL
           STRING ',' FUNCTION TRIM(WS-ED-SMALL) ','
               DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
           END-STRING
           MOVE R-HIGH-DAYS(SX) TO WS-ED-SMALL
           STRING FUNCTION TRIM(WS-ED-SMALL) ','
                  FUNCTION TRIM(R-TREND(SX)) ','
               DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
           END-STRING
           IF R-HAS-TREND(SX) = 'Y'
               MOVE R-TREND-PCT(SX) TO WS-ED-SPCT
               STRING FUNCTION TRIM(WS-ED-SPCT)
                   DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
               END-STRING
           END-IF
           STRING ',' R-STALE(SX) ','
               DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
           END-STRING
           PERFORM 7200-RUN-FIELDS
           WRITE RES-REC.

       7200-RUN-FIELDS.
           MOVE WS-RC TO WS-ED-SMALL
           STRING WS-RUN-DATE ',' WS-RUN-TIME ','
                  FUNCTION TRIM(WS-ED-SMALL)
               DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
           END-STRING.

       7300-ADD-CFS.
           STRING FUNCTION TRIM(WS-ED-CFS) ','
               DELIMITED BY SIZE INTO RES-REC WITH POINTER WS-PTR
           END-STRING.

      *================================================================*
      * CSV HELPERS                                                    *
      *================================================================*
       8000-SPLIT-SITES.
           MOVE SPACES TO WS-FIELDS
           UNSTRING SITES-REC DELIMITED BY ','
               INTO WS-FLD(1) WS-FLD(2) WS-FLD(3) WS-FLD(4)
                    WS-FLD(5) WS-FLD(6) WS-FLD(7) WS-FLD(8)
                    WS-FLD(9) WS-FLD(10)
           END-UNSTRING.

       8100-FIND-SITE.
           MOVE 0 TO WS-FOUND
           PERFORM VARYING WS-J FROM 1 BY 1
                   UNTIL WS-J > WS-NSITES OR WS-FOUND > 0
               IF S-ID(WS-J) = WS-FLD(1)(1:8)
                   MOVE WS-J TO WS-FOUND
               END-IF
           END-PERFORM.

      *================================================================*
       9000-TERMINATE.
      *================================================================*
           MOVE WS-STALE TO WS-ED-CNT
           DISPLAY 'SFLW005I GAGES STALE OR NO DATA ....' WS-ED-CNT
           DISPLAY 'SFLW006I REPORT WRITTEN: streamflow-report.txt'
           DISPLAY 'SFLW007I RESULTS WRITTEN: results.csv'
           MOVE WS-RC TO RETURN-CODE
           MOVE WS-RC TO WS-ED-SMALL
           DISPLAY 'SFLW999I SIERRA-FLOW ENDED  RC=' WS-ED-SMALL.
