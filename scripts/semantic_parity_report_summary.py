#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Print a compact summary from semantic parity JSON report."
    )
    parser.add_argument(
        "report",
        nargs="?",
        default="_build/semantic_parity/report_fast.json",
        help="Path to semantic parity JSON report.",
    )
    parser.add_argument(
        "--top-slowest",
        type=int,
        default=0,
        help="Print top N slowest scenarios by duration_ms.",
    )
    parser.add_argument(
        "--only-failures",
        action="store_true",
        help="Show only non-pass scenarios in scenario summary output.",
    )
    parser.add_argument(
        "--sort-scenarios",
        action="store_true",
        help="Sort scenario summary output by scenario name.",
    )
    args = parser.parse_args()

    report_path = Path(args.report)
    if not report_path.exists():
        raise FileNotFoundError(f"report not found: {report_path}")

    data = json.loads(report_path.read_text())
    metadata = data.get("metadata", {})

    print(f"Report: {report_path}")
    if metadata:
        print(f"Tool: {metadata.get('tool')}")
        print(f"Python: {metadata.get('python_version')}")
        print(f"Generated UTC: {metadata.get('generated_at_utc')}")
        argv = metadata.get("argv")
        if isinstance(argv, list):
            print(f"Args: {' '.join(str(v) for v in argv)}")
    print(f"Result: {data.get('result')}")
    print(f"Mismatch count: {data.get('mismatch_count')}")
    print(f"Total compare ms: {data.get('total_scenario_compare_ms')}")
    selected = data.get("selected_scenarios", [])
    if args.sort_scenarios:
        selected = sorted(selected)
    print(f"Selected scenarios: {', '.join(selected)}")
    print("Scenario summary:")

    all_scenarios = data.get("scenarios", [])
    if args.sort_scenarios:
        all_scenarios = sorted(all_scenarios, key=lambda s: str(s.get("name")))
    scenarios = all_scenarios
    if args.only_failures:
        scenarios = [s for s in all_scenarios if s.get("status") != "pass"]

    if not scenarios:
        print("- (none)")

    for scenario in scenarios:
        summary = scenario.get("summary", {})
        print(
            "- "
            f"{scenario.get('name')} "
            f"status={scenario.get('status')} "
            f"duration_ms={scenario.get('duration_ms'):.1f} "
            f"ws={summary.get('worksheets')} "
            f"charts={summary.get('charts')} "
            f"controls={summary.get('form_controls')} "
            f"cf={summary.get('conditional_formatting')}"
        )

    if args.top_slowest > 0:
        print(f"Top {args.top_slowest} slowest scenarios:")
        ranked = sorted(
            scenarios if args.only_failures else all_scenarios,
            key=lambda scenario: float(scenario.get("duration_ms", 0.0)),
            reverse=True,
        )
        for scenario in ranked[: args.top_slowest]:
            print(
                "- "
                f"{scenario.get('name')} "
                f"duration_ms={float(scenario.get('duration_ms', 0.0)):.1f} "
                f"status={scenario.get('status')}"
            )

    mismatches = data.get("mismatches", [])
    if mismatches:
        print("Mismatches:")
        for msg in mismatches:
            print(f"- {msg}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
