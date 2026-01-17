# FPGA Synthesis Tools Installation

## Required Tools

### 1. Yosys (Synthesis)
Open-source synthesis tool that converts Verilog RTL to gate-level netlist.

```bash
sudo apt install yosys
```

### 2. Nextpnr (Optional - Place & Route)
For complete FPGA implementation with timing analysis.

```bash
sudo apt install nextpnr-ice40 nextpnr-ecp5
```

### 3. IceStorm Tools (Optional - for iCE40 FPGAs)
Complete toolchain for Lattice iCE40 FPGAs.

```bash
sudo apt install fpga-icestorm
```

## Quick Install (Synthesis Only)

For basic synthesis and post-synthesis simulation:

```bash
sudo apt install yosys
```

This is sufficient for:
- RTL synthesis
- Resource utilization reports
- Post-synthesis gate-level simulation
- Technology mapping to generic or FPGA-specific cells

## Verify Installation

```bash
yosys -V
```

Should output version information.

## What We'll Do

1. **Synthesis**: Convert your FIFO Verilog to optimized gate-level netlist
2. **Technology Mapping**: Map to FPGA primitives (LUTs, FFs, BRAM)
3. **Resource Reports**: See how many FPGA resources are used
4. **Post-Synthesis Sim**: Verify synthesized design still passes all tests
5. **Timing Analysis**: Estimate maximum clock frequency

## Target FPGAs

We'll create scripts for multiple targets:
- Generic (vendor-independent)
- Xilinx 7-Series (Artix-7, Kintex-7, Virtex-7)
- Lattice iCE40 (open-source toolchain)
- Lattice ECP5

Choose based on what hardware you have or plan to use!
