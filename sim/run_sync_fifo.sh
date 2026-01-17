#!/bin/bash
#==============================================================================
# run_sync_fifo.sh
# Script to compile and simulate the Synchronous FIFO
#==============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=================================="
echo "Synchronous FIFO Simulation"
echo "=================================="
echo "Project directory: $PROJECT_DIR"
echo ""

# Change to sim directory
cd "$SCRIPT_DIR"

# Run make
make sync

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo "Simulation completed successfully!"
    echo ""
    echo "To view waveforms:"
    echo "  make wave_sync"
    echo ""
    echo "Or manually:"
    echo "  gtkwave $PROJECT_DIR/results/waveforms/fifo_sync.vcd"
else
    echo ""
    echo "Simulation failed! Check the errors above."
    exit 1
fi
