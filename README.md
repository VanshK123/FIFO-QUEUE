# FIFO Queue Project

A comprehensive digital design project implementing both **Synchronous** and **Asynchronous FIFO** queues in Verilog, with emphasis on Clock Domain Crossing (CDC) techniques, performance analysis, and thorough verification.

### Important Note - This project is currently being built check the TEST_RESULTS_SUMMARY.md to see status

## Overview

This project demonstrates:
- Synchronous FIFO with single clock domain
- Asynchronous FIFO with dual clock domains and CDC handling
- Gray code counters for safe clock domain crossing
- Multi-stage synchronizers for metastability protection
- Comprehensive self-checking testbenches
- Performance analysis and visualization

## Quick Start

### Prerequisites

- **Icarus Verilog** (iverilog) - Verilog simulator
- **GTKWave** - Waveform viewer
- **Python 3** (optional) - For analysis scripts
- **matplotlib** (optional) - For generating plots

Install on Ubuntu/Debian:
```bash
sudo apt install iverilog gtkwave python3 python3-pip
pip3 install matplotlib numpy
```

### Running Simulations

1. **Run all tests:**
   ```bash
   cd sim
   make test
   ```

2. **Run individual simulations:**
   ```bash
   # Synchronous FIFO
   ./run_sync_fifo.sh

   # Asynchronous FIFO
   ./run_async_fifo.sh
   ```

3. **View waveforms:**
   ```bash
   make wave_sync    # Synchronous FIFO
   make wave_async   # Asynchronous FIFO
   ```

4. **Generate analysis reports:**
   ```bash
   cd scripts
   python3 analyze_performance.py
   python3 plot_results.py
   ```

## Project Structure

```
fifo_project/
├── README.md                    # This file
├── PROJECT_REPORT.md            # Technical documentation
├── todo.md                      # Project specification
├── rtl/                         # RTL source files
│   ├── fifo_sync.v             # Synchronous FIFO
│   ├── fifo_async.v            # Asynchronous FIFO
│   ├── gray_counter.v          # Gray code counter
│   ├── synchronizer.v          # Multi-stage synchronizer
│   └── fifo_pkg.vh             # Common parameters
├── tb/                          # Testbenches
│   ├── fifo_sync_tb.v          # Sync FIFO testbench
│   ├── fifo_async_tb.v         # Async FIFO testbench
│   └── test_params.vh          # Test parameters
├── sim/                         # Simulation files
│   ├── Makefile                # Build automation
│   ├── run_sync_fifo.sh        # Sync FIFO script
│   ├── run_async_fifo.sh       # Async FIFO script
│   └── run_all_tests.sh        # Complete test suite
├── scripts/                     # Analysis scripts
│   ├── analyze_performance.py  # Performance analysis
│   ├── plot_results.py         # Generate plots
│   └── check_coverage.py       # Coverage analysis
└── results/                     # Output directory
    ├── waveforms/              # VCD files
    ├── logs/                   # Simulation logs
    └── reports/                # Analysis reports
```

## Design Specifications

| Parameter | Value |
|-----------|-------|
| Data Width | 32 bits |
| FIFO Depth | 16 entries |
| Sync Stages | 2 (configurable) |
| Write Clock | 100 MHz |
| Read Clock | 66.67 MHz (async) |

## Key Features

### Synchronous FIFO
- Single clock domain operation
- Full/Empty detection using MSB trick
- Almost full/empty thresholds
- Overflow/underflow detection
- Peak occupancy tracking

### Asynchronous FIFO
- Dual clock domain operation
- Gray code pointers for safe CDC
- Multi-stage synchronizers (configurable)
- Conservative full/empty detection
- Independent reset per domain

## Test Coverage

The testbenches verify:
- Reset behavior
- Basic read/write operations
- Fill and drain operations
- Overflow/underflow detection
- Simultaneous read/write
- Random operation patterns
- Burst operations
- Performance metrics
- Clock ratio variations (async)
- CDC stress testing (async)

## Expected Output

```
================================
FIFO SYNCHRONOUS TESTBENCH
================================
[TEST 1] Reset Test.............. PASS
[TEST 2] Single Write/Read....... PASS
[TEST 3] Fill FIFO............... PASS
[TEST 4] Drain FIFO.............. PASS
[TEST 5] Overflow Detection...... PASS
[TEST 6] Underflow Detection..... PASS
[TEST 7] Simultaneous R/W........ PASS
[TEST 8] Random Operations....... PASS
[TEST 9] Burst Write/Read........ PASS
[TEST 10] Performance Test....... PASS

================================
SIMULATION COMPLETE - ALL TESTS PASSED!
================================
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make all` | Build and run both FIFOs |
| `make sync` | Run synchronous FIFO |
| `make async` | Run asynchronous FIFO |
| `make wave_sync` | View sync waveforms |
| `make wave_async` | View async waveforms |
| `make clean` | Remove generated files |
| `make test` | Full test suite |
| `make help` | Show help |

## Documentation

See [PROJECT_REPORT.md](PROJECT_REPORT.md) for:
- Detailed design methodology
- CDC theory and implementation
- Verification strategy
- Performance analysis
- Computer architecture concepts

## References

- Cliff Cummings, "Simulation and Synthesis Techniques for Asynchronous FIFO Design", SNUG 2002
- Cliff Cummings, "Clock Domain Crossing (CDC) Design & Verification Techniques"
- IEEE Standard 1364-2005 (Verilog)

