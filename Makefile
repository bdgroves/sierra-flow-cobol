# Sierra Flow - USGS Streamflow Processor
# GNU COBOL Makefile

COBC     = cobc
COBFLAGS = -x -free
TARGET   = sierra-flow
SOURCE   = SIERRA-FLOW.cob
INPUT    = streamflow.csv
OUTPUT   = streamflow-report.txt

.PHONY: all build run clean check

all: build run

build:
	@echo "Compiling $(SOURCE)..."
	$(COBC) $(COBFLAGS) -o $(TARGET) $(SOURCE)
	@echo "Build complete: ./$(TARGET)"

run: $(TARGET) $(INPUT)
	@echo "Running Sierra Flow processor..."
	./$(TARGET)
	@echo ""
	@echo "--- REPORT OUTPUT ---"
	@cat $(OUTPUT)

clean:
	@rm -f $(TARGET) $(OUTPUT)
	@echo "Cleaned build artifacts."

check:
	@which cobc > /dev/null 2>&1 || \
		(echo "ERROR: GnuCOBOL not found. Install with:" && \
		 echo "  Ubuntu/Debian: sudo apt install gnucobol" && \
		 echo "  macOS:         brew install gnucobol" && \
		 echo "  Windows:       Use WSL or GnuCOBOL installer from sourceforge" && \
		 exit 1)
	@echo "GnuCOBOL found: $$(cobc --version | head -1)"
