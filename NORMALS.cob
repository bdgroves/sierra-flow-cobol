      *================================================================*
      * NORMALS.COB  VERSION 1.0                                       *
      * BUILDS THE NORMAL FLOW FOR EVERY DAY OF THE YEAR               *
      *                                                                *
      * INPUT : history.csv  DAILY MEAN DISCHARGE, WATER YEARS         *
      *                      1996-2025, ALL EIGHT GAGES (USGS)         *
      * OUTPUT: normals.csv  FOR EACH GAGE AND DAY OF THE YEAR, THE    *
      *                      10TH, 25TH, 50TH, 75TH AND 90TH           *
      *                      PERCENTILE OF DAILY FLOW                  *
      *                                                                *
      * METHOD: EACH DAILY VALUE IS RELEASED TO THE SORT SEVEN TIMES,  *
      *         ONCE FOR EVERY DAY WITHIN 3 DAYS OF ITS DATE, SO EACH  *
      *         DAY'S NORMAL COMES FROM A 7-DAY WINDOW ACROSS 30       *
      *         YEARS (ABOUT 210 VALUES). THE SORT ORDERS THEM BY      *
      *         GAGE, DAY AND FLOW; THE OUTPUT PROCEDURE READS EACH    *
      *         GROUP AND INTERPOLATES THE PERCENTILES (WEIBULL RANK   *
      *         P*(N+1), THE PLOTTING POSITION USGS USES).             *
      *                                                                *
      * DAYS ARE NUMBERED 1-366 ON A LEAP-YEAR CALENDAR (FEB 29 = 60)  *
      * AND THE WINDOW WRAPS FROM DEC 31 TO JAN 1.                     *
      *                                                                *
      * COMPILE: cobc -x -o normals NORMALS.cob                        *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NORMALS.
       AUTHOR. BROOKS GROVES.
       DATE-WRITTEN. 2026-10-02.
       SECURITY. UNCLASSIFIED - PUBLIC DATA.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT HIST-FILE ASSIGN TO 'history.csv'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-HIST.
           SELECT NORM-FILE ASSIGN TO 'normals.csv'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS-NORM.
           SELECT SORT-FILE ASSIGN TO 'normals-sort.tmp'.

       DATA DIVISION.
       FILE SECTION.
       FD  HIST-FILE.
       01  HIST-REC                     PIC X(80).

       FD  NORM-FILE.
       01  NORM-REC                     PIC X(120).

       SD  SORT-FILE.
       01  SORT-REC.
           05  SR-SITE                  PIC X(8).
           05  SR-SLOT                  PIC 9(3).
           05  SR-FLOW                  PIC 9(7)V99.
           05  SR-YEAR                  PIC 9(4).

       WORKING-STORAGE SECTION.
       01  WS-FS-HIST                   PIC XX.
       01  WS-FS-NORM                   PIC XX.
       01  WS-EOF                       PIC X VALUE 'N'.
           88  AT-EOF                   VALUE 'Y'.
       01  WS-FIRST                     PIC X VALUE 'Y'.

      *--- CSV FIELDS ---
       01  WS-F-SITE                    PIC X(20).
       01  WS-F-DATE                    PIC X(20).
       01  WS-F-CFS                     PIC X(20).

      *--- CUMULATIVE DAYS BEFORE EACH MONTH, LEAP-YEAR CALENDAR ---
       01  WS-CUM-DATA.
           05  FILLER                   PIC X(36) VALUE
               '000031060091121152182213244274305335'.
       01  WS-CUM-TABLE REDEFINES WS-CUM-DATA.
           05  WS-CUM                   PIC 999 OCCURS 12.

       01  WS-MONTH                     PIC 99.
       01  WS-DAY                       PIC 99.
       01  WS-YEAR                      PIC 9(4).
       01  WS-SLOT                      PIC 9(3).
       01  WS-K                         PIC S9.
       01  WS-TARGET                    PIC S9(4).
       01  WS-FLOW                      PIC 9(7)V99.

      *--- ONE GROUP (GAGE + DAY OF YEAR) FROM THE SORT ---
       01  WS-G-SITE                    PIC X(8) VALUE SPACES.
       01  WS-G-SLOT                    PIC 9(3) VALUE 0.
       01  WS-N                         PIC 9(4) VALUE 0.
       01  WS-VALUES.
           05  WS-V                     PIC 9(7)V99 OCCURS 400.
       01  WS-YEARS-SEEN.
           05  WS-YS                    PIC X OCCURS 100.
       01  WS-NYEARS                    PIC 9(3) VALUE 0.
       01  WS-YI                        PIC 9(3).

      *--- PERCENTILE WORK ---
       01  WS-P                         PIC V99.
       01  WS-RANK                      PIC 9(4)V9(4).
       01  WS-RI                        PIC 9(4).
       01  WS-RF                        PIC V9(4).
       01  WS-RESULT                    PIC 9(7)V99.
       01  WS-PCT-OUT.
           05  WS-PO                    PIC 9(7)V99 OCCURS 5.
       01  WS-PX                        PIC 9.
       01  WS-PLIST-DATA.
           05  FILLER                   PIC X(10) VALUE '1025507590'.
       01  WS-PLIST REDEFINES WS-PLIST-DATA.
           05  WS-PL                    PIC V99 OCCURS 5.

      *--- OUTPUT FORMATTING ---
       01  WS-ED-VAL                    PIC Z(6)9.99.
       01  WS-ED-SLOT                   PIC ZZ9.
       01  WS-ED-N                      PIC ZZZ9.
       01  WS-ED-M                      PIC Z9.
       01  WS-ED-D                      PIC Z9.
       01  WS-OUT-M                     PIC 99.
       01  WS-OUT-D                     PIC 99.
       01  WS-PTR                       PIC 9(3).
       01  WS-MI                        PIC 99.

      *--- COUNTERS ---
       01  WS-READ                      PIC 9(7) VALUE 0.
       01  WS-SKIPPED                   PIC 9(7) VALUE 0.
       01  WS-RELEASED                  PIC 9(8) VALUE 0.
       01  WS-RETURNED                  PIC 9(8) VALUE 0.
       01  WS-WRITTEN                   PIC 9(6) VALUE 0.
       01  WS-THIN                      PIC 9(6) VALUE 0.
       01  WS-ED-CNT                    PIC Z(7)9.

       PROCEDURE DIVISION.
       0000-MAIN.
           DISPLAY 'NRML000I NORMALS V1.0 STARTED'
           OPEN OUTPUT NORM-FILE
           IF WS-FS-NORM NOT = '00'
               DISPLAY 'NRML901E CANNOT OPEN normals.csv'
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           MOVE SPACES TO NORM-REC
           STRING 'site_id,slot,month,day,n_values,n_years,'
                  'p10,p25,p50,p75,p90' DELIMITED BY SIZE
                  INTO NORM-REC
           END-STRING
           WRITE NORM-REC
           SORT SORT-FILE
               ON ASCENDING KEY SR-SITE SR-SLOT SR-FLOW
               INPUT PROCEDURE 1000-RELEASE-WINDOWS
               OUTPUT PROCEDURE 2000-BUILD-PERCENTILES
           CLOSE NORM-FILE
           MOVE WS-READ TO WS-ED-CNT
           DISPLAY 'NRML010I DAILY VALUES READ ......' WS-ED-CNT
           MOVE WS-SKIPPED TO WS-ED-CNT
           DISPLAY 'NRML011I SKIPPED (NO VALUE) .....' WS-ED-CNT
           MOVE WS-RELEASED TO WS-ED-CNT
           DISPLAY 'NRML012I RECORDS SORTED .........' WS-ED-CNT
           MOVE WS-WRITTEN TO WS-ED-CNT
           DISPLAY 'NRML013I NORMALS WRITTEN ........' WS-ED-CNT
           IF WS-THIN > 0
               MOVE WS-THIN TO WS-ED-CNT
               DISPLAY 'NRML020W DAYS WITH UNDER 10 YEARS' WS-ED-CNT
               MOVE 4 TO RETURN-CODE
           END-IF
           DISPLAY 'NRML999I NORMALS ENDED'
           STOP RUN.

      *================================================================*
      * INPUT PROCEDURE: READ history.csv, RELEASE EACH VALUE SEVEN    *
      * TIMES (DAY-3 TO DAY+3)                                         *
      *================================================================*
       1000-RELEASE-WINDOWS.
           OPEN INPUT HIST-FILE
           IF WS-FS-HIST NOT = '00'
               DISPLAY 'NRML902E CANNOT OPEN history.csv'
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM UNTIL AT-EOF
               READ HIST-FILE
                   AT END SET AT-EOF TO TRUE
                   NOT AT END PERFORM 1100-ONE-VALUE
               END-READ
           END-PERFORM
           CLOSE HIST-FILE.

       1100-ONE-VALUE.
           IF WS-FIRST = 'Y'
               MOVE 'N' TO WS-FIRST
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-READ
           MOVE SPACES TO WS-F-SITE WS-F-DATE WS-F-CFS
           UNSTRING HIST-REC DELIMITED BY ','
               INTO WS-F-SITE WS-F-DATE WS-F-CFS
           END-UNSTRING
           IF WS-F-CFS = SPACES OR WS-F-DATE(5:1) NOT = '-'
               ADD 1 TO WS-SKIPPED
               EXIT PARAGRAPH
           END-IF
           MOVE WS-F-DATE(1:4) TO WS-YEAR
           MOVE WS-F-DATE(6:2) TO WS-MONTH
           MOVE WS-F-DATE(9:2) TO WS-DAY
           COMPUTE WS-SLOT = WS-CUM(WS-MONTH) + WS-DAY
           COMPUTE WS-FLOW = FUNCTION NUMVAL(WS-F-CFS)
           PERFORM VARYING WS-K FROM -3 BY 1 UNTIL WS-K > 3
               COMPUTE WS-TARGET = WS-SLOT + WS-K
               IF WS-TARGET < 1
                   ADD 366 TO WS-TARGET
               END-IF
               IF WS-TARGET > 366
                   SUBTRACT 366 FROM WS-TARGET
               END-IF
               MOVE WS-F-SITE(1:8) TO SR-SITE
               MOVE WS-TARGET      TO SR-SLOT
               MOVE WS-FLOW        TO SR-FLOW
               MOVE WS-YEAR        TO SR-YEAR
               RELEASE SORT-REC
               ADD 1 TO WS-RELEASED
           END-PERFORM.

      *================================================================*
      * OUTPUT PROCEDURE: RETURN SORTED VALUES, ONE GROUP PER GAGE AND *
      * DAY OF YEAR, AND WRITE ITS PERCENTILES                         *
      *================================================================*
       2000-BUILD-PERCENTILES.
           MOVE 'N' TO WS-EOF
           PERFORM UNTIL AT-EOF
               RETURN SORT-FILE
                   AT END SET AT-EOF TO TRUE
                   NOT AT END PERFORM 2100-ONE-SORTED
               END-RETURN
           END-PERFORM
           IF WS-N > 0
               PERFORM 2200-WRITE-GROUP
           END-IF.

       2100-ONE-SORTED.
           ADD 1 TO WS-RETURNED
           IF WS-N > 0 AND
              (SR-SITE NOT = WS-G-SITE OR SR-SLOT NOT = WS-G-SLOT)
               PERFORM 2200-WRITE-GROUP
           END-IF
           IF WS-N = 0
               MOVE SR-SITE TO WS-G-SITE
               MOVE SR-SLOT TO WS-G-SLOT
               MOVE ALL 'N' TO WS-YEARS-SEEN
           END-IF
           IF WS-N < 400
               ADD 1 TO WS-N
               MOVE SR-FLOW TO WS-V(WS-N)
           END-IF
           COMPUTE WS-YI = FUNCTION MOD(SR-YEAR, 100) + 1
           IF WS-YS(WS-YI) = 'N'
               MOVE 'Y' TO WS-YS(WS-YI)
               ADD 1 TO WS-NYEARS
           END-IF.

       2200-WRITE-GROUP.
           PERFORM VARYING WS-PX FROM 1 BY 1 UNTIL WS-PX > 5
               MOVE WS-PL(WS-PX) TO WS-P
               PERFORM 2300-PERCENTILE
               MOVE WS-RESULT TO WS-PO(WS-PX)
           END-PERFORM
      *--- CALENDAR MONTH AND DAY FOR THIS SLOT ---
           MOVE 1 TO WS-OUT-M
           PERFORM VARYING WS-MI FROM 2 BY 1 UNTIL WS-MI > 12
               IF WS-G-SLOT > WS-CUM(WS-MI)
                   MOVE WS-MI TO WS-OUT-M
               END-IF
           END-PERFORM
           COMPUTE WS-OUT-D = WS-G-SLOT - WS-CUM(WS-OUT-M)
           IF WS-NYEARS < 10
               ADD 1 TO WS-THIN
           END-IF
           MOVE SPACES TO NORM-REC
           MOVE 1 TO WS-PTR
           MOVE WS-G-SLOT TO WS-ED-SLOT
           MOVE WS-OUT-M  TO WS-ED-M
           MOVE WS-OUT-D  TO WS-ED-D
           STRING WS-G-SITE DELIMITED BY SPACE
                  ',' FUNCTION TRIM(WS-ED-SLOT)
                  ',' FUNCTION TRIM(WS-ED-M)
                  ',' FUNCTION TRIM(WS-ED-D)
                  DELIMITED BY SIZE
                  INTO NORM-REC WITH POINTER WS-PTR
           END-STRING
           MOVE WS-N TO WS-ED-N
           STRING ',' FUNCTION TRIM(WS-ED-N) DELIMITED BY SIZE
                  INTO NORM-REC WITH POINTER WS-PTR
           END-STRING
           MOVE WS-NYEARS TO WS-ED-N
           STRING ',' FUNCTION TRIM(WS-ED-N) DELIMITED BY SIZE
                  INTO NORM-REC WITH POINTER WS-PTR
           END-STRING
           PERFORM VARYING WS-PX FROM 1 BY 1 UNTIL WS-PX > 5
               MOVE WS-PO(WS-PX) TO WS-ED-VAL
               STRING ',' FUNCTION TRIM(WS-ED-VAL) DELIMITED BY SIZE
                      INTO NORM-REC WITH POINTER WS-PTR
               END-STRING
           END-PERFORM
           WRITE NORM-REC
           ADD 1 TO WS-WRITTEN
           MOVE 0 TO WS-N WS-NYEARS.

      *================================================================*
      * PERCENTILE OF THE SORTED GROUP, WEIBULL PLOTTING POSITION:     *
      * RANK = P * (N + 1), INTERPOLATED BETWEEN NEIGHBOURS            *
      *================================================================*
       2300-PERCENTILE.
           COMPUTE WS-RANK = WS-P * (WS-N + 1)
           EVALUATE TRUE
               WHEN WS-RANK <= 1
                   MOVE WS-V(1) TO WS-RESULT
               WHEN WS-RANK >= WS-N
                   MOVE WS-V(WS-N) TO WS-RESULT
               WHEN OTHER
                   MOVE WS-RANK TO WS-RI
                   COMPUTE WS-RF = WS-RANK - WS-RI
                   COMPUTE WS-RESULT ROUNDED = WS-V(WS-RI) +
                       WS-RF * (WS-V(WS-RI + 1) - WS-V(WS-RI))
           END-EVALUATE.
