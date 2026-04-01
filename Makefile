# Sierra Flow v2 - USGS Streamflow Processor
# GNU COBOL Makefile

COBC     = cobc
COBFLAGS = -x
TARGET   = sierra-flow
SOURCE   = SIERRA-FLOW.cob
OUTPUT   = streamflow-report.txt

.PHONY: all build run fetch clean check

all: fetch build run

fetch:
	@echo "Fetching live USGS data..."
	python3 fetch_usgs.py

build:
	@echo "Compiling $(SOURCE)..."
	$(COBC) $(COBFLAGS) -o $(TARGET) $(SOURCE)
	@echo "Build complete: ./$(TARGET)"

run: $(TARGET)
	@echo "Running Sierra Flow v2..."
	./$(TARGET)
	@echo ""
	@echo "--- REPORT ---"
	@cat $(OUTPUT)

clean:
	@rm -f $(TARGET) $(OUTPUT) sort-work.tmp
	@echo "Cleaned."

check:
	@which cobc > /dev/null 2>&1 || \
		(echo "ERROR: GnuCOBOL not found." && \
		 echo "  Ubuntu/Debian: sudo apt install gnucobol" && \
		 echo "  macOS:         brew install gnucobol" && \
		 exit 1)
	@which python3 > /dev/null 2>&1 || \
		(echo "ERROR: Python3 not found." && exit 1)
	@echo "GnuCOBOL: $$(cobc --version | head -1)"
	@echo "Python:   $$(python3 --version)"
