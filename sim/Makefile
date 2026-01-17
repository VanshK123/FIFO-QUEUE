#==============================================================================
# Makefile for FIFO Project
#
# Targets:
#   all        - Build and run both sync and async FIFO tests
#   sync       - Compile and run synchronous FIFO
#   async      - Compile and run asynchronous FIFO
#   wave_sync  - Open GTKWave for sync FIFO
#   wave_async - Open GTKWave for async FIFO
#   clean      - Remove all generated files
#   test       - Run complete test suite
#   help       - Show this help message
#
#==============================================================================

# Directories
RTL_DIR    = ../rtl
TB_DIR     = ../tb
RESULTS_DIR = ../results
WAVE_DIR   = $(RESULTS_DIR)/waveforms
LOG_DIR    = $(RESULTS_DIR)/logs

# Compiler settings
IVERILOG   = iverilog
VVP        = vvp
GTKWAVE    = gtkwave

# Compiler flags
IVFLAGS    = -g2012 -Wall -I$(RTL_DIR) -I$(TB_DIR)

# Source files
SYNC_RTL   = $(RTL_DIR)/fifo_sync.v
SYNC_TB    = $(TB_DIR)/fifo_sync_tb.v

ASYNC_RTL  = $(RTL_DIR)/fifo_async.v \
             $(RTL_DIR)/gray_counter.v \
             $(RTL_DIR)/synchronizer.v
ASYNC_TB   = $(TB_DIR)/fifo_async_tb.v

# Output files
SYNC_VVP   = fifo_sync.vvp
ASYNC_VVP  = fifo_async.vvp

#==============================================================================
# Default target
#==============================================================================
.PHONY: all
all: sync async
	@echo ""
	@echo "==================================="
	@echo "All simulations completed!"
	@echo "==================================="
	@echo "Waveforms saved to: $(WAVE_DIR)/"
	@echo ""

#==============================================================================
# Create output directories
#==============================================================================
$(WAVE_DIR):
	@mkdir -p $(WAVE_DIR)

$(LOG_DIR):
	@mkdir -p $(LOG_DIR)

#==============================================================================
# Synchronous FIFO
#==============================================================================
.PHONY: sync
sync: $(WAVE_DIR) $(LOG_DIR)
	@echo ""
	@echo "==================================="
	@echo "Compiling Synchronous FIFO..."
	@echo "==================================="
	$(IVERILOG) $(IVFLAGS) -o $(SYNC_VVP) $(SYNC_RTL) $(SYNC_TB)
	@echo ""
	@echo "Running Synchronous FIFO simulation..."
	@echo "==================================="
	cd $(WAVE_DIR) && $(VVP) ../../sim/$(SYNC_VVP) | tee ../../$(LOG_DIR)/fifo_sync.log
	@echo ""
	@echo "Sync FIFO simulation complete!"
	@echo "Waveform: $(WAVE_DIR)/fifo_sync.vcd"
	@echo "Log: $(LOG_DIR)/fifo_sync.log"
	@echo ""

#==============================================================================
# Asynchronous FIFO
#==============================================================================
.PHONY: async
async: $(WAVE_DIR) $(LOG_DIR)
	@echo ""
	@echo "==================================="
	@echo "Compiling Asynchronous FIFO..."
	@echo "==================================="
	$(IVERILOG) $(IVFLAGS) -o $(ASYNC_VVP) $(ASYNC_RTL) $(ASYNC_TB)
	@echo ""
	@echo "Running Asynchronous FIFO simulation..."
	@echo "==================================="
	cd $(WAVE_DIR) && $(VVP) ../../sim/$(ASYNC_VVP) | tee ../../$(LOG_DIR)/fifo_async.log
	@echo ""
	@echo "Async FIFO simulation complete!"
	@echo "Waveform: $(WAVE_DIR)/fifo_async.vcd"
	@echo "Log: $(LOG_DIR)/fifo_async.log"
	@echo ""

#==============================================================================
# Waveform viewing
#==============================================================================
.PHONY: wave_sync
wave_sync:
	@echo "Opening GTKWave for Sync FIFO..."
	@if [ -f wave_sync.gtkw ]; then \
		$(GTKWAVE) $(WAVE_DIR)/fifo_sync.vcd wave_sync.gtkw & \
	else \
		$(GTKWAVE) $(WAVE_DIR)/fifo_sync.vcd & \
	fi

.PHONY: wave_async
wave_async:
	@echo "Opening GTKWave for Async FIFO..."
	@if [ -f wave_async.gtkw ]; then \
		$(GTKWAVE) $(WAVE_DIR)/fifo_async.vcd wave_async.gtkw & \
	else \
		$(GTKWAVE) $(WAVE_DIR)/fifo_async.vcd & \
	fi

#==============================================================================
# Clean
#==============================================================================
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -f *.vvp
	rm -f $(WAVE_DIR)/*.vcd
	rm -f $(LOG_DIR)/*.log
	@echo "Clean complete!"

#==============================================================================
# Full test suite
#==============================================================================
.PHONY: test
test: clean all
	@echo ""
	@echo "==================================="
	@echo "Test Suite Complete!"
	@echo "==================================="
	@echo ""
	@echo "Results Summary:"
	@echo "----------------"
	@grep -E "(PASS|FAIL|Success Rate)" $(LOG_DIR)/*.log || true
	@echo ""

#==============================================================================
# Help
#==============================================================================
.PHONY: help
help:
	@echo ""
	@echo "FIFO Project Makefile"
	@echo "====================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build and run both sync and async FIFO tests (default)"
	@echo "  sync       - Compile and run synchronous FIFO"
	@echo "  async      - Compile and run asynchronous FIFO"
	@echo "  wave_sync  - Open GTKWave for sync FIFO waveforms"
	@echo "  wave_async - Open GTKWave for async FIFO waveforms"
	@echo "  clean      - Remove all generated files"
	@echo "  test       - Clean and run complete test suite"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make sync        # Run only sync FIFO test"
	@echo "  make async       # Run only async FIFO test"
	@echo "  make wave_sync   # View sync FIFO waveforms"
	@echo "  make test        # Run full test suite with clean"
	@echo ""
