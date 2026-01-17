# FPGA Synthesis Directory

This directory contains scripts and outputs for FPGA synthesis of the FIFO designs.

## Quick Start

### 1. Install Yosys (if not already installed)

```bash
sudo apt install yosys
```

### 2. Run Synthesis

```bash
cd syn
make all          # Synthesize both designs
```

### 3. View Results

```bash
make reports      # Display resource utilization summary
```

### 4. Post-Synthesis Simulation (Optional)

```bash
make sim_sync     # Simulate synthesized sync FIFO
make sim_async    # Simulate synthesized async FIFO
```

## Directory Structure

```
syn/
├── scripts/              # Yosys synthesis scripts
│   ├── synth_fifo_sync.ys
│   └── synth_fifo_async.ys
├── netlists/             # Generated netlists (after synthesis)
│   ├── fifo_sync_synth.v
│   ├── fifo_async_synth.v
│   ├── fifo_sync_synth.json
│   └── fifo_async_synth.json
├── reports/              # Synthesis reports
│   ├── fifo_sync_synth.rpt
│   ├── fifo_async_synth.rpt
│   ├── postsyn_sync.log
│   └── postsyn_async.log
├── Makefile              # Build automation
└── README.md             # This file
```

## Available Targets

| Command | Description |
|---------|-------------|
| `make all` | Synthesize both FIFO designs (default) |
| `make synth_sync` | Synthesize only synchronous FIFO |
| `make synth_async` | Synthesize only asynchronous FIFO |
| `make sim_sync` | Post-synthesis simulation (sync FIFO) |
| `make sim_async` | Post-synthesis simulation (async FIFO) |
| `make reports` | Display resource utilization summary |
| `make clean` | Remove all generated files |
| `make help` | Show help message |

## What Synthesis Does

1. **Reads RTL**: Parses your Verilog source files
2. **Elaborates**: Builds design hierarchy
3. **Optimizes**: Performs high-level optimizations (FSM, memory, logic)
4. **Technology Mapping**: Maps to FPGA primitives (LUTs, FFs, BRAM)
5. **Generates Netlist**: Outputs gate-level Verilog
6. **Reports Resources**: Shows FPGA resource utilization

## Understanding the Reports

### Resource Utilization

After running `make reports`, you'll see:

- **Total Cells**: Number of logic elements
- **Flip-Flops**: Number of registers (data storage)
- **Logic Cells (LUTs)**: Lookup tables for combinational logic
- **Multiplexers**: Data selection logic
- **Wires**: Interconnections
- **Memories**: RAM/FIFO blocks

### Cell Breakdown

Shows which types of cells are used:
- `$dff` - D flip-flop (registered outputs)
- `$mux` - Multiplexer (data selection)
- `$eq`, `$ne` - Comparators (empty/full detection)
- `$add` - Adders (pointer increment)
- `$mem` - Memory blocks (FIFO storage)

## Post-Synthesis Simulation

Post-synthesis simulation verifies that:
1. Synthesis didn't break functionality
2. All 20 tests still pass
3. Timing behavior is preserved

The synthesized netlist is a gate-level representation, so simulation is slower but more accurate.

## Advanced: Technology-Specific Synthesis

To target specific FPGA families, modify the synthesis scripts:

### Xilinx 7-Series
```tcl
synth_xilinx -top fifo_sync -family xc7
```

### Lattice iCE40
```tcl
synth_ice40 -top fifo_sync
```

### Lattice ECP5
```tcl
synth_ecp5 -top fifo_sync
```

## Analyzing Results

Run the Python analysis script:

```bash
cd scripts
./analyze_synthesis.py
```

This generates a detailed comparison between sync and async FIFO resource usage.

## Next Steps

After synthesis, you can:

1. **Place & Route**: Use `nextpnr` for complete FPGA implementation
2. **Timing Analysis**: Determine maximum clock frequency
3. **Program FPGA**: Generate bitstream and load onto real hardware
4. **Power Analysis**: Estimate power consumption

See `INSTALL_FPGA_TOOLS.md` in the project root for advanced toolchain setup.

## Troubleshooting

### "yosys: command not found"
Install Yosys: `sudo apt install yosys`

### Synthesis warnings about latches
Check for incomplete case/if statements in RTL (not an issue for this design)

### Post-synthesis simulation fails
The testbench may need timing adjustments for gate-level simulation

## Expected Resource Usage

**Synchronous FIFO** (DATA_WIDTH=32, DEPTH=16):
- ~50-100 flip-flops (pointers, flags, data registers)
- ~50-150 logic cells (comparators, control logic)
- 1 memory block (16x32-bit FIFO storage)

**Asynchronous FIFO** (same parameters):
- ~100-200 flip-flops (dual clock domains, CDC synchronizers)
- ~100-250 logic cells (Gray code conversion, dual comparators)
- 1 memory block (16x32-bit FIFO storage)

Async FIFO uses ~2x resources due to CDC overhead.
