#!/usr/bin/env python3
"""
Performance Analysis Script for FIFO Project

Analyzes simulation logs and generates performance metrics:
- Throughput (MB/s, transactions/sec)
- Latency statistics
- Occupancy statistics
- Test pass/fail summary

Usage:
    python3 analyze_performance.py [--log-dir PATH]
"""

import re
import sys
import os
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from datetime import datetime


@dataclass
class TestResult:
    """Container for individual test results"""
    name: str
    passed: bool
    details: str = ""


@dataclass
class PerformanceMetrics:
    """Container for performance metrics"""
    total_writes: int = 0
    total_reads: int = 0
    peak_occupancy: int = 0
    fifo_depth: int = 16
    throughput_mbps: float = 0.0
    success_rate: float = 0.0


def find_log_dir() -> Path:
    """Find the logs directory"""
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    log_dir = project_dir / "results" / "logs"

    if not log_dir.exists():
        # Try current directory
        log_dir = Path("../results/logs")

    return log_dir


def parse_sync_log(log_file: Path) -> Tuple[List[TestResult], PerformanceMetrics]:
    """Parse synchronous FIFO simulation log"""
    tests = []
    metrics = PerformanceMetrics()

    if not log_file.exists():
        print(f"Warning: Log file not found: {log_file}")
        return tests, metrics

    with open(log_file, 'r') as f:
        content = f.read()

    # Parse test results
    test_pattern = r'\[TEST (\d+)\] (.+?)\.+ (PASS|FAIL)'
    for match in re.finditer(test_pattern, content):
        test_num = int(match.group(1))
        test_name = match.group(2).strip()
        passed = match.group(3) == 'PASS'
        tests.append(TestResult(name=test_name, passed=passed))

    # Parse performance metrics
    writes_match = re.search(r'Total Writes:\s*(\d+)', content)
    if writes_match:
        metrics.total_writes = int(writes_match.group(1))

    reads_match = re.search(r'Total Reads:\s*(\d+)', content)
    if reads_match:
        metrics.total_reads = int(reads_match.group(1))

    peak_match = re.search(r'Peak Occupancy:\s*(\d+)/(\d+)', content)
    if peak_match:
        metrics.peak_occupancy = int(peak_match.group(1))
        metrics.fifo_depth = int(peak_match.group(2))

    throughput_match = re.search(r'Throughput:\s*([\d.]+)\s*MB/s', content)
    if throughput_match:
        metrics.throughput_mbps = float(throughput_match.group(1))

    success_match = re.search(r'Success Rate:\s*(\d+)%', content)
    if success_match:
        metrics.success_rate = float(success_match.group(1))

    return tests, metrics


def parse_async_log(log_file: Path) -> Tuple[List[TestResult], PerformanceMetrics]:
    """Parse asynchronous FIFO simulation log"""
    # Same format as sync, reuse the parser
    return parse_sync_log(log_file)


def generate_report(sync_results: Tuple[List[TestResult], PerformanceMetrics],
                    async_results: Tuple[List[TestResult], PerformanceMetrics],
                    output_file: Optional[Path] = None) -> str:
    """Generate formatted performance report"""
    sync_tests, sync_metrics = sync_results
    async_tests, async_metrics = async_results

    lines = []
    lines.append("=" * 70)
    lines.append("FIFO PROJECT - PERFORMANCE ANALYSIS REPORT")
    lines.append("=" * 70)
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")

    # Synchronous FIFO Results
    lines.append("-" * 70)
    lines.append("SYNCHRONOUS FIFO RESULTS")
    lines.append("-" * 70)

    if sync_tests:
        lines.append("")
        lines.append("Test Results:")
        passed = sum(1 for t in sync_tests if t.passed)
        failed = len(sync_tests) - passed
        for test in sync_tests:
            status = "PASS" if test.passed else "FAIL"
            lines.append(f"  [{status}] {test.name}")
        lines.append("")
        lines.append(f"Summary: {passed}/{len(sync_tests)} tests passed ({passed*100//len(sync_tests)}%)")

    if sync_metrics.total_writes > 0:
        lines.append("")
        lines.append("Performance Metrics:")
        lines.append(f"  Total Writes:    {sync_metrics.total_writes}")
        lines.append(f"  Total Reads:     {sync_metrics.total_reads}")
        lines.append(f"  Peak Occupancy:  {sync_metrics.peak_occupancy}/{sync_metrics.fifo_depth} "
                    f"({sync_metrics.peak_occupancy*100//sync_metrics.fifo_depth}%)")
        if sync_metrics.throughput_mbps > 0:
            lines.append(f"  Throughput:      {sync_metrics.throughput_mbps:.2f} MB/s")

    lines.append("")

    # Asynchronous FIFO Results
    lines.append("-" * 70)
    lines.append("ASYNCHRONOUS FIFO RESULTS")
    lines.append("-" * 70)

    if async_tests:
        lines.append("")
        lines.append("Test Results:")
        passed = sum(1 for t in async_tests if t.passed)
        failed = len(async_tests) - passed
        for test in async_tests:
            status = "PASS" if test.passed else "FAIL"
            lines.append(f"  [{status}] {test.name}")
        lines.append("")
        lines.append(f"Summary: {passed}/{len(async_tests)} tests passed ({passed*100//len(async_tests)}%)")

    if async_metrics.total_writes > 0:
        lines.append("")
        lines.append("Performance Metrics:")
        lines.append(f"  Total Writes:    {async_metrics.total_writes}")
        lines.append(f"  Total Reads:     {async_metrics.total_reads}")
        if async_metrics.throughput_mbps > 0:
            lines.append(f"  Throughput:      {async_metrics.throughput_mbps:.2f} MB/s")

    lines.append("")

    # Comparison
    lines.append("-" * 70)
    lines.append("COMPARISON SUMMARY")
    lines.append("-" * 70)
    lines.append("")

    total_sync_tests = len(sync_tests) if sync_tests else 0
    total_async_tests = len(async_tests) if async_tests else 0
    sync_passed = sum(1 for t in sync_tests if t.passed) if sync_tests else 0
    async_passed = sum(1 for t in async_tests if t.passed) if async_tests else 0

    lines.append("                          Sync FIFO    Async FIFO")
    lines.append("                          ---------    ----------")
    lines.append(f"  Tests Passed:           {sync_passed:5d}        {async_passed:5d}")
    lines.append(f"  Tests Failed:           {total_sync_tests - sync_passed:5d}        {total_async_tests - async_passed:5d}")
    lines.append(f"  Total Writes:           {sync_metrics.total_writes:5d}        {async_metrics.total_writes:5d}")
    lines.append(f"  Total Reads:            {sync_metrics.total_reads:5d}        {async_metrics.total_reads:5d}")

    lines.append("")
    lines.append("=" * 70)

    all_passed = (sync_passed == total_sync_tests and
                  async_passed == total_async_tests and
                  total_sync_tests > 0 and total_async_tests > 0)

    if all_passed:
        lines.append("OVERALL STATUS: ALL TESTS PASSED")
    elif total_sync_tests == 0 and total_async_tests == 0:
        lines.append("OVERALL STATUS: NO SIMULATION DATA FOUND")
        lines.append("Run 'make test' in the sim/ directory first.")
    else:
        lines.append("OVERALL STATUS: SOME TESTS FAILED")

    lines.append("=" * 70)

    report = "\n".join(lines)

    # Write to file if specified
    if output_file:
        output_file.parent.mkdir(parents=True, exist_ok=True)
        with open(output_file, 'w') as f:
            f.write(report)
        print(f"Report saved to: {output_file}")

    return report


def main():
    """Main entry point"""
    log_dir = find_log_dir()

    print("FIFO Performance Analysis")
    print("=" * 40)
    print(f"Looking for logs in: {log_dir}")
    print("")

    # Parse log files
    sync_log = log_dir / "fifo_sync.log"
    async_log = log_dir / "fifo_async.log"

    sync_results = parse_sync_log(sync_log)
    async_results = parse_async_log(async_log)

    # Generate report
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    report_file = project_dir / "results" / "reports" / "performance_report.txt"

    report = generate_report(sync_results, async_results, report_file)
    print(report)

    return 0


if __name__ == "__main__":
    sys.exit(main())
