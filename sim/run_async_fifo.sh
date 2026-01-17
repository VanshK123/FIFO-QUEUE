#!/bin/bash
#==============================================================================
# run_async_fifo.sh
# Script to compile and simulate the Asynchronous FIFO
#==============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=================================="
echo "Asynchronous FIFO Simulation"
echo "=================================="
echo "Project directory: $PROJECT_DIR"
echo ""

# Change to sim directory
cd "$SCRIPT_DIR"

# Run make
make async

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo "Simulation completed successfully!"
    echo ""
    echo "To view waveforms:"
    echo "  make wave_async"
    echo ""
    echo "Or manually:"
    echo "  gtkwave $PROJECT_DIR/results/waveforms/fifo_async.vcd"
else
    echo ""
    echo "Simulation failed! Check the errors above."
    exit 1
fi
