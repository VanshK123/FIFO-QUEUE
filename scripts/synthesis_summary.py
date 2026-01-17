#!/usr/bin/env python3
"""
Quick Synthesis Summary
Parses Yosys reports and displays resource comparison
"""

import re

def parse_report(filename):
    """Parse Yosys synthesis report"""
    with open(filename, 'r') as f:
        lines = f.readlines()

    cells = {}
    total_cells = 0
    wires = 0

    for line in lines:
        # Parse total cell count
        if 'Number of cells:' in line:
            total_cells = int(line.split()[-1])

        # Parse wire count
        if 'Number of wires:' in line:
            wires = int(line.split()[-1])

        # Parse individual cell types
        if line.strip().startswith('$_'):
            parts = line.split()
            cell_type = parts[0]
            count = int(parts[1])
            cells[cell_type] = count

    return {'total_cells': total_cells, 'cells': cells, 'wires': wires}

def count_ffs(cells):
    """Count all flip-flop types"""
    ff_count = 0
    for cell_type, count in cells.items():
        if 'DFF' in cell_type or 'FF' in cell_type:
            ff_count += count
    return ff_count

def count_logic(cells):
    """Count combinational logic cells"""
    logic_count = 0
    logic_types = ['AND', 'OR', 'XOR', 'NAND', 'NOR', 'XNOR', 'NOT']
    for cell_type, count in cells.items():
        for ltype in logic_types:
            if ltype in cell_type:
                logic_count += count
                break
    return logic_count

def count_mux(cells):
    """Count multiplexers"""
    return cells.get('$_MUX_', 0)

# Parse reports
print("\n" + "="*80)
print(" "*25 + "FPGA SYNTHESIS RESULTS")
print("="*80 + "\n")

sync_data = parse_report('../syn/reports/fifo_sync_synth.rpt')
async_data = parse_report('../syn/reports/fifo_async_synth.rpt')

# Calculate resources
sync_ff = count_ffs(sync_data['cells'])
sync_logic = count_logic(sync_data['cells'])
sync_mux = count_mux(sync_data['cells'])

async_ff = count_ffs(async_data['cells'])
async_logic = count_logic(async_data['cells'])
async_mux = count_mux(async_data['cells'])

# Display comparison table
print(f"{'Resource':<25} {'Sync FIFO':>12} {'Async FIFO':>12} {'Difference':>15}")
print("-"*80)

def print_row(name, sync_val, async_val):
    diff = async_val - sync_val
    diff_pct = (diff / sync_val * 100) if sync_val > 0 else 0
    print(f"{name:<25} {sync_val:>12} {async_val:>12} {diff:>+6} ({diff_pct:>+5.1f}%)")

print_row("Total Cells", sync_data['total_cells'], async_data['total_cells'])
print_row("Flip-Flops (Registers)", sync_ff, async_ff)
print_row("Logic Gates", sync_logic, async_logic)
print_row("Multiplexers", sync_mux, async_mux)
print_row("Wires", sync_data['wires'], async_data['wires'])

print("\n" + "-"*80)
print("\nDETAILED BREAKDOWN:\n")

# Sync FIFO details
print("SYNCHRONOUS FIFO:")
print(f"  Total Resources: {sync_data['total_cells']} cells")
print(f"  - Flip-Flops:    {sync_ff} ({sync_ff/sync_data['total_cells']*100:.1f}%)")
print(f"  - Multiplexers:  {sync_mux} ({sync_mux/sync_data['total_cells']*100:.1f}%)")
print(f"  - Logic Gates:   {sync_logic} ({sync_logic/sync_data['total_cells']*100:.1f}%)")
print()

# Top cell types for sync
print("  Top Cell Types:")
sorted_cells = sorted(sync_data['cells'].items(), key=lambda x: x[1], reverse=True)
for cell, count in sorted_cells[:8]:
    print(f"    {cell:<20} {count:>5} cells")

print("\n" + "-"*80 + "\n")

# Async FIFO details
print("ASYNCHRONOUS FIFO:")
print(f"  Total Resources: {async_data['total_cells']} cells")
print(f"  - Flip-Flops:    {async_ff} ({async_ff/async_data['total_cells']*100:.1f}%)")
print(f"  - Multiplexers:  {async_mux} ({async_mux/async_data['total_cells']*100:.1f}%)")
print(f"  - Logic Gates:   {async_logic} ({async_logic/async_data['total_cells']*100:.1f}%)")
print()

# Top cell types for async
print("  Top Cell Types:")
sorted_cells = sorted(async_data['cells'].items(), key=lambda x: x[1], reverse=True)
for cell, count in sorted_cells[:8]:
    print(f"    {cell:<20} {count:>5} cells")

print("\n" + "="*80)
print("\nKEY INSIGHTS:")
print("-"*80)
overhead_pct = ((async_data['total_cells'] - sync_data['total_cells']) /
                sync_data['total_cells'] * 100)
print(f"\n1. Async FIFO has {overhead_pct:.1f}% more resources than Sync FIFO")
print(f"   - Additional {async_ff - sync_ff} flip-flops for CDC synchronization")
print(f"   - Gray code counters for metastability-safe pointer crossing")
print(f"   - 2-stage synchronizers for each pointer (wr→rd and rd→wr domains)")
print()
print("2. Main Resources:")
print(f"   - Sync:  {sync_ff} FFs, {sync_logic} gates, {sync_mux} muxes")
print(f"   - Async: {async_ff} FFs, {async_logic} gates, {async_mux} muxes")
print()
print("3. FIFO Memory Implementation:")
print("   - Both use distributed RAM (512 DFFE cells for 16x32-bit storage)")
print("   - Could be optimized to use FPGA Block RAM (BRAM) for larger FIFOs")
print()
print("="*80 + "\n")
