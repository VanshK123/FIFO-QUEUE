#!/usr/bin/env python3
"""
Synthesis Results Analyzer
Parses Yosys synthesis reports and generates resource utilization summary
"""

import re
import sys
from pathlib import Path

def parse_yosys_report(report_file):
    """Parse Yosys synthesis report to extract resource utilization"""

    if not Path(report_file).exists():
        return None

    with open(report_file, 'r') as f:
        content = f.read()

    results = {
        'cells': {},
        'wires': 0,
        'memories': 0,
        'processes': 0
    }

    # Extract number of cells by type
    cell_pattern = r'\s+(\w+)\s+(\d+)'
    in_stat_section = False

    for line in content.split('\n'):
        if 'Printing statistics' in line:
            in_stat_section = True
            continue

        if in_stat_section:
            if line.strip() == '':
                continue
            if '===' in line or '---' in line:
                break

            match = re.match(cell_pattern, line)
            if match:
                cell_type = match.group(1)
                count = int(match.group(2))
                results['cells'][cell_type] = count

        # Extract wire count
        if 'Number of wires:' in line:
            match = re.search(r'(\d+)', line)
            if match:
                results['wires'] = int(match.group(1))

        # Extract memory count
        if 'Number of memories:' in line:
            match = re.search(r'(\d+)', line)
            if match:
                results['memories'] = int(match.group(1))

    return results

def count_resources(results):
    """Count FPGA resources from cell types"""

    resources = {
        'logic_cells': 0,
        'flip_flops': 0,
        'muxes': 0,
        'memory_bits': 0,
        'total_cells': 0
    }

    if not results:
        return resources

    for cell_type, count in results['cells'].items():
        resources['total_cells'] += count

        # Count flip-flops (DFF variants)
        if 'DFF' in cell_type or 'FF' in cell_type:
            resources['flip_flops'] += count

        # Count multiplexers
        if 'MUX' in cell_type:
            resources['muxes'] += count

        # Count logic cells (LUT, gates)
        if any(x in cell_type for x in ['LUT', 'AND', 'OR', 'XOR', 'NOT', 'NAND', 'NOR']):
            resources['logic_cells'] += count

    return resources

def print_report(design_name, results, resources):
    """Print formatted synthesis report"""

    print(f"\n{'='*70}")
    print(f"SYNTHESIS REPORT: {design_name}")
    print(f"{'='*70}\n")

    if not results:
        print("ERROR: No synthesis results found!")
        return

    print("Resource Utilization:")
    print(f"  Total Cells:        {resources['total_cells']:6d}")
    print(f"  Flip-Flops:         {resources['flip_flops']:6d}")
    print(f"  Logic Cells (LUTs): {resources['logic_cells']:6d}")
    print(f"  Multiplexers:       {resources['muxes']:6d}")
    print(f"  Wires:              {results['wires']:6d}")
    print(f"  Memories:           {results['memories']:6d}")

    print(f"\nCell Breakdown:")
    # Sort cells by count (descending)
    sorted_cells = sorted(results['cells'].items(), key=lambda x: x[1], reverse=True)
    for cell_type, count in sorted_cells[:15]:  # Top 15 cell types
        print(f"  {cell_type:20s} {count:6d}")

    if len(sorted_cells) > 15:
        print(f"  ... and {len(sorted_cells) - 15} more cell types")

    print(f"\n{'='*70}\n")

def main():
    """Main function"""

    # Parse reports
    sync_report = Path('../syn/reports/fifo_sync_synth.rpt')
    async_report = Path('../syn/reports/fifo_async_synth.rpt')

    print("\n" + "="*70)
    print("FPGA SYNTHESIS ANALYSIS")
    print("="*70)

    # Synchronous FIFO
    if sync_report.exists():
        sync_results = parse_yosys_report(sync_report)
        sync_resources = count_resources(sync_results)
        print_report("Synchronous FIFO", sync_results, sync_resources)
    else:
        print(f"\nWARNING: {sync_report} not found!")
        print("Run 'make synth_sync' in syn/ directory first.\n")

    # Asynchronous FIFO
    if async_report.exists():
        async_results = parse_yosys_report(async_report)
        async_resources = count_resources(async_results)
        print_report("Asynchronous FIFO", async_results, async_resources)
    else:
        print(f"\nWARNING: {async_report} not found!")
        print("Run 'make synth_async' in syn/ directory first.\n")

    # Comparison
    if sync_report.exists() and async_report.exists():
        print("="*70)
        print("COMPARISON: Sync vs Async FIFO")
        print("="*70)
        print(f"\n{'Resource':<25s} {'Sync':>12s} {'Async':>12s} {'Difference':>15s}")
        print("-"*70)

        sync_res = count_resources(parse_yosys_report(sync_report))
        async_res = count_resources(parse_yosys_report(async_report))

        for key in ['total_cells', 'flip_flops', 'logic_cells', 'muxes']:
            sync_val = sync_res[key]
            async_val = async_res[key]
            diff = async_val - sync_val
            diff_pct = (diff / sync_val * 100) if sync_val > 0 else 0
            print(f"{key.replace('_', ' ').title():<25s} {sync_val:12d} {async_val:12d} "
                  f"{diff:+6d} ({diff_pct:+6.1f}%)")

        print("\n" + "="*70)
        print("Async FIFO Overhead: Clock domain crossing logic (Gray counters,")
        print("synchronizers) increases resource usage compared to Sync FIFO.")
        print("="*70 + "\n")

if __name__ == '__main__':
    main()
