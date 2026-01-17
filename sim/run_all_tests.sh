#!/bin/bash
#==============================================================================
# run_all_tests.sh
# Master script to run complete FIFO test suite
#==============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Masters-Level FIFO Test Suite"
echo "=========================================="
echo "Project directory: $PROJECT_DIR"
echo "Date: $(date)"
echo ""

# Change to sim directory
cd "$SCRIPT_DIR"

# Run the test suite
echo "Running complete test suite..."
echo ""
make test

# Check if analysis scripts exist and run them
if [ -f "$PROJECT_DIR/scripts/analyze_performance.py" ]; then
    echo ""
    echo "=========================================="
    echo "Running Performance Analysis..."
    echo "=========================================="
    cd "$PROJECT_DIR/scripts"
    python3 analyze_performance.py 2>/dev/null || echo "Note: Performance analysis requires Python 3"
fi

if [ -f "$PROJECT_DIR/scripts/plot_results.py" ]; then
    echo ""
    echo "=========================================="
    echo "Generating Performance Plots..."
    echo "=========================================="
    python3 plot_results.py 2>/dev/null || echo "Note: Plotting requires matplotlib"
fi

echo ""
echo "=========================================="
echo "Test Suite Complete!"
echo "=========================================="
echo ""
echo "Results available in:"
echo "  Waveforms: $PROJECT_DIR/results/waveforms/"
echo "  Logs:      $PROJECT_DIR/results/logs/"
echo "  Reports:   $PROJECT_DIR/results/reports/"
echo ""
echo "To view waveforms:"
echo "  cd $SCRIPT_DIR"
echo "  make wave_sync   # Synchronous FIFO"
echo "  make wave_async  # Asynchronous FIFO"
echo ""
