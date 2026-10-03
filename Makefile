# SIERRA-FLOW - GnuCOBOL batch
#   make          fetch, compile and run (builds normals the first time)
#   make normals  rebuild normals.csv from 30 years of USGS history
#   make report   show the last report

.PHONY: all normals report clean check

all: check
	./run_job.sh
	@cat streamflow-report.txt

normals: check
	./run_job.sh --normals

report:
	@cat streamflow-report.txt

clean:
	rm -f sierra-flow normals history.csv *.tmp

check:
	@which cobc > /dev/null 2>&1 || (echo "GnuCOBOL not found: sudo apt install gnucobol3 | brew install gnucobol" && exit 1)
	@which python3 > /dev/null 2>&1 || (echo "Python 3 not found" && exit 1)
