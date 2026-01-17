#!/usr/bin/env python3
"""
Test Coverage Analysis Script for FIFO Project

Analyzes test coverage by parsing testbench files and simulation logs:
- Lists all test scenarios
- Checks which tests were executed
- Reports coverage metrics

Usage:
    python3 check_coverage.py
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple
from dataclasses import dataclass


@dataclass
class TestScenario:
    """Represents a test scenario"""
    name: str
    category: str
    description: str
    executed: bool = False
    passed: bool = False


def find_project_dirs() -> Tuple[Path, Path, Path]:
    """Find project directories"""
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    tb_dir = project_dir / "tb"
    log_dir = project_dir / "results" / "logs"

    return project_dir, tb_dir, log_dir


def extract_tests_from_testbench(tb_file: Path) -> List[TestScenario]:
    """Extract test scenarios from testbench file"""
    tests = []

    if not tb_file.exists():
        return tests

    with open(tb_file, 'r') as f:
        content = f.read()

    # Find task definitions that look like tests
    task_pattern = r'task\s+(test_\w+)\s*;'

    for match in re.finditer(task_pattern, content):
        task_name = match.group(1)

        # Try to find description in comments
        desc = task_name.replace('test_', '').replace('_', ' ').title()

        tests.append(TestScenario(
            name=task_name,
            category="functional",
            description=desc
        ))

    return tests


def check_test_execution(log_file: Path, tests: List[TestScenario]) -> List[TestScenario]:
    """Check which tests were executed and their results"""
    if not log_file.exists():
        return tests

    with open(log_file, 'r') as f:
        content = f.read()

    # Find test results in log
    result_pattern = r'\[TEST \d+\] (.+?)\.+ (PASS|FAIL)'

    executed_tests = {}
    for match in re.finditer(result_pattern, content):
        test_name = match.group(1).strip()
        passed = match.group(2) == 'PASS'
        executed_tests[test_name.lower()] = passed

    # Update test status
    for test in tests:
        # Try to match by name
        test_key = test.description.lower()
        if test_key in executed_tests:
            test.executed = True
            test.passed = executed_tests[test_key]
        else:
            # Try alternative matching
            for key, passed in executed_tests.items():
                if test.name.replace('test_', '').replace('_', ' ') in key or \
                   key in test.name.replace('test_', '').replace('_', ' '):
                    test.executed = True
                    test.passed = passed
                    break

    return tests


def generate_coverage_report(sync_tests: List[TestScenario],
                             async_tests: List[TestScenario]) -> str:
    """Generate coverage report"""
    lines = []
    lines.append("=" * 70)
    lines.append("FIFO PROJECT - TEST COVERAGE REPORT")
    lines.append("=" * 70)
    lines.append("")

    # Required test categories
    required_tests = {
        "Basic Functionality": [
            "Reset behavior",
            "Single write/read",
            "Fill FIFO",
            "Drain FIFO",
            "Simultaneous read/write"
        ],
        "Corner Cases": [
            "Overflow detection",
            "Underflow detection",
            "Pointer wrap-around"
        ],
        "Stress Tests": [
            "Random operations",
            "Burst operations",
            "Performance test"
        ],
        "CDC Tests (Async only)": [
            "Clock ratio variations",
            "CDC stress test"
        ]
    }

    # Synchronous FIFO Coverage
    lines.append("-" * 70)
    lines.append("SYNCHRONOUS FIFO COVERAGE")
    lines.append("-" * 70)

    sync_executed = sum(1 for t in sync_tests if t.executed)
    sync_total = len(sync_tests)

    lines.append(f"\nTests Defined: {sync_total}")
    lines.append(f"Tests Executed: {sync_executed}")
    lines.append(f"Coverage: {sync_executed*100//sync_total if sync_total > 0 else 0}%")
    lines.append("")

    lines.append("Test Status:")
    for test in sync_tests:
        status = "PASS" if test.passed else ("FAIL" if test.executed else "NOT RUN")
        symbol = "[+]" if test.passed else ("[-]" if test.executed else "[ ]")
        lines.append(f"  {symbol} {test.description}: {status}")

    lines.append("")

    # Asynchronous FIFO Coverage
    lines.append("-" * 70)
    lines.append("ASYNCHRONOUS FIFO COVERAGE")
    lines.append("-" * 70)

    async_executed = sum(1 for t in async_tests if t.executed)
    async_total = len(async_tests)

    lines.append(f"\nTests Defined: {async_total}")
    lines.append(f"Tests Executed: {async_executed}")
    lines.append(f"Coverage: {async_executed*100//async_total if async_total > 0 else 0}%")
    lines.append("")

    lines.append("Test Status:")
    for test in async_tests:
        status = "PASS" if test.passed else ("FAIL" if test.executed else "NOT RUN")
        symbol = "[+]" if test.passed else ("[-]" if test.executed else "[ ]")
        lines.append(f"  {symbol} {test.description}: {status}")

    lines.append("")

    # Required Coverage Checklist
    lines.append("-" * 70)
    lines.append("REQUIRED TEST COVERAGE CHECKLIST")
    lines.append("-" * 70)
    lines.append("")

    all_tests = sync_tests + async_tests
    all_test_names = [t.description.lower() for t in all_tests]

    for category, tests in required_tests.items():
        lines.append(f"{category}:")
        for test in tests:
            covered = any(test.lower() in name for name in all_test_names)
            symbol = "[x]" if covered else "[ ]"
            lines.append(f"  {symbol} {test}")
        lines.append("")

    # Summary
    lines.append("=" * 70)
    total_executed = sync_executed + async_executed
    total_tests = sync_total + async_total
    total_passed = sum(1 for t in sync_tests + async_tests if t.passed)

    lines.append(f"OVERALL COVERAGE: {total_executed}/{total_tests} tests executed "
                f"({total_executed*100//total_tests if total_tests > 0 else 0}%)")
    lines.append(f"PASS RATE: {total_passed}/{total_executed} tests passed "
                f"({total_passed*100//total_executed if total_executed > 0 else 0}%)")
    lines.append("=" * 70)

    return "\n".join(lines)


def main():
    """Main entry point"""
    print("FIFO Test Coverage Analysis")
    print("=" * 40)

    project_dir, tb_dir, log_dir = find_project_dirs()

    print(f"Testbench directory: {tb_dir}")
    print(f"Log directory: {log_dir}")
    print("")

    # Extract tests from testbenches
    sync_tb = tb_dir / "fifo_sync_tb.v"
    async_tb = tb_dir / "fifo_async_tb.v"

    sync_tests = extract_tests_from_testbench(sync_tb)
    async_tests = extract_tests_from_testbench(async_tb)

    # Check execution status
    sync_log = log_dir / "fifo_sync.log"
    async_log = log_dir / "fifo_async.log"

    sync_tests = check_test_execution(sync_log, sync_tests)
    async_tests = check_test_execution(async_log, async_tests)

    # Generate report
    report = generate_coverage_report(sync_tests, async_tests)
    print(report)

    # Save report
    report_dir = project_dir / "results" / "reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    report_file = report_dir / "coverage_report.txt"

    with open(report_file, 'w') as f:
        f.write(report)

    print(f"\nReport saved to: {report_file}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
