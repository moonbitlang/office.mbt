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
    args = parser.parse_args()

    report_path = Path(args.report)
    if not report_path.exists():
        raise FileNotFoundError(f"report not found: {report_path}")

    data = json.loads(report_path.read_text())

    print(f"Report: {report_path}")
    print(f"Result: {data.get('result')}")
    print(f"Mismatch count: {data.get('mismatch_count')}")
    print(f"Total compare ms: {data.get('total_scenario_compare_ms')}")
    print(f"Selected scenarios: {', '.join(data.get('selected_scenarios', []))}")
    print("Scenario summary:")

    for scenario in data.get("scenarios", []):
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

    mismatches = data.get("mismatches", [])
    if mismatches:
        print("Mismatches:")
        for msg in mismatches:
            print(f"- {msg}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
