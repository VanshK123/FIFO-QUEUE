#==============================================================================
# Makefile for FPGA Synthesis
#
# Targets:
#   all           - Synthesize both FIFO designs
#   synth_sync    - Synthesize synchronous FIFO
#   synth_async   - Synthesize asynchronous FIFO
#   sim_sync      - Post-synthesis simulation of sync FIFO
#   sim_async     - Post-synthesis simulation of async FIFO
#   reports       - Generate resource utilization summary
#   clean         - Remove all generated files
#   help          - Show this help message
#
#==============================================================================

# Tools
YOSYS     = yosys
IVERILOG  = iverilog
VVP       = vvp

# Directories
SCRIPTS_DIR  = scripts
REPORTS_DIR  = reports
NETLISTS_DIR = netlists
TB_DIR       = ../tb
RESULTS_DIR  = ../results

# Synthesis scripts
SYNC_SYNTH_SCRIPT  = $(SCRIPTS_DIR)/synth_fifo_sync.ys
ASYNC_SYNTH_SCRIPT = $(SCRIPTS_DIR)/synth_fifo_async.ys

# Generated netlists
SYNC_NETLIST  = $(NETLISTS_DIR)/fifo_sync_synth.v
ASYNC_NETLIST = $(NETLISTS_DIR)/fifo_async_synth.v

#==============================================================================
# Default target
#==============================================================================
.PHONY: all
all: synth_sync synth_async reports
	@echo ""
	@echo "================================================"
	@echo "FPGA Synthesis Complete!"
	@echo "================================================"
	@echo ""

#==============================================================================
# Create directories
#==============================================================================
$(REPORTS_DIR):
	@mkdir -p $(REPORTS_DIR)

$(NETLISTS_DIR):
	@mkdir -p $(NETLISTS_DIR)

#==============================================================================
# Synthesis
#==============================================================================
.PHONY: synth_sync
synth_sync: $(REPORTS_DIR) $(NETLISTS_DIR)
	@echo ""
	@echo "================================================"
	@echo "Synthesizing Synchronous FIFO..."
	@echo "================================================"
	$(YOSYS) -s $(SYNC_SYNTH_SCRIPT)
	@echo ""
	@echo "Sync FIFO synthesis complete!"
	@echo "Netlist: $(SYNC_NETLIST)"
	@echo ""

.PHONY: synth_async
synth_async: $(REPORTS_DIR) $(NETLISTS_DIR)
	@echo ""
	@echo "================================================"
	@echo "Synthesizing Asynchronous FIFO..."
	@echo "================================================"
	$(YOSYS) -s $(ASYNC_SYNTH_SCRIPT)
	@echo ""
	@echo "Async FIFO synthesis complete!"
	@echo "Netlist: $(ASYNC_NETLIST)"
	@echo ""

#==============================================================================
# Post-synthesis simulation
#==============================================================================
.PHONY: sim_sync
sim_sync: synth_sync
	@echo ""
	@echo "================================================"
	@echo "Running Post-Synthesis Simulation (Sync FIFO)"
	@echo "================================================"
	@echo "NOTE: Parameters are synthesized away in gate-level netlist"
	@echo "      Running functional simulation only..."
	$(IVERILOG) -g2012 -DPOST_SYNTHESIS -o $(NETLISTS_DIR)/fifo_sync_postsyn.vvp \
		$(SYNC_NETLIST) $(TB_DIR)/fifo_sync_tb.v
	$(VVP) $(NETLISTS_DIR)/fifo_sync_postsyn.vvp | tee $(REPORTS_DIR)/postsyn_sync.log
	@echo ""
	@echo "Post-synthesis simulation complete!"
	@echo ""

.PHONY: sim_async
sim_async: synth_async
	@echo ""
	@echo "================================================"
	@echo "Running Post-Synthesis Simulation (Async FIFO)"
	@echo "================================================"
	@echo "NOTE: Parameters are synthesized away in gate-level netlist"
	@echo "      Running functional simulation only..."
	$(IVERILOG) -g2012 -DPOST_SYNTHESIS -o $(NETLISTS_DIR)/fifo_async_postsyn.vvp \
		$(ASYNC_NETLIST) $(TB_DIR)/fifo_async_tb.v
	$(VVP) $(NETLISTS_DIR)/fifo_async_postsyn.vvp | tee $(REPORTS_DIR)/postsyn_async.log
	@echo ""
	@echo "Post-synthesis simulation complete!"
	@echo ""

#==============================================================================
# Reports
#==============================================================================
.PHONY: reports
reports:
	@echo ""
	@echo "================================================"
	@echo "FPGA Resource Utilization Summary"
	@echo "================================================"
	@echo ""
	@if [ -f $(REPORTS_DIR)/fifo_sync_synth.rpt ]; then \
		echo "--- Synchronous FIFO ---"; \
		grep -A 20 "Printing statistics" $(REPORTS_DIR)/fifo_sync_synth.rpt | head -25; \
		echo ""; \
	fi
	@if [ -f $(REPORTS_DIR)/fifo_async_synth.rpt ]; then \
		echo "--- Asynchronous FIFO ---"; \
		grep -A 20 "Printing statistics" $(REPORTS_DIR)/fifo_async_synth.rpt | head -25; \
		echo ""; \
	fi
	@echo "================================================"
	@echo "Full reports available in: $(REPORTS_DIR)/"
	@echo "================================================"
	@echo ""

#==============================================================================
# Clean
#==============================================================================
.PHONY: clean
clean:
	@echo "Cleaning synthesis artifacts..."
	rm -rf $(NETLISTS_DIR)/*.v $(NETLISTS_DIR)/*.json $(NETLISTS_DIR)/*.vvp
	rm -rf $(REPORTS_DIR)/*.rpt $(REPORTS_DIR)/*.log
	@echo "Clean complete!"

#==============================================================================
# Help
#==============================================================================
.PHONY: help
help:
	@echo ""
	@echo "FPGA Synthesis Makefile"
	@echo "======================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all         - Synthesize both FIFO designs (default)"
	@echo "  synth_sync  - Synthesize synchronous FIFO only"
	@echo "  synth_async - Synthesize asynchronous FIFO only"
	@echo "  sim_sync    - Run post-synthesis simulation (sync)"
	@echo "  sim_async   - Run post-synthesis simulation (async)"
	@echo "  reports     - Display resource utilization summary"
	@echo "  clean       - Remove all generated files"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make all          # Synthesize both designs"
	@echo "  make synth_sync   # Synthesize only sync FIFO"
	@echo "  make sim_sync     # Synthesize + simulate sync FIFO"
	@echo "  make reports      # View resource usage"
	@echo ""
