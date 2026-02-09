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
    parser.add_argument(
        "--no-metadata",
        action="store_true",
        help="Hide report metadata header lines.",
    )
    parser.add_argument(
        "--as-json",
        action="store_true",
        help="Emit summary as JSON instead of human-readable text.",
    )
    parser.add_argument(
        "--compact",
        action="store_true",
        help="Emit only minimal fields for lightweight parsing.",
    )
    parser.add_argument(
        "--redact-sensitive",
        action="store_true",
        help="Redact argv and wrapper_env values in metadata output.",
    )
    args = parser.parse_args()

    report_path = Path(args.report)
    if not report_path.exists():
        raise FileNotFoundError(f"report not found: {report_path}")

    data = json.loads(report_path.read_text())
    metadata = data.get("metadata", {})
    selected = data.get("selected_scenarios", [])
    if args.sort_scenarios:
        selected = sorted(selected)

    all_scenarios = data.get("scenarios", [])
    if args.sort_scenarios:
        all_scenarios = sorted(all_scenarios, key=lambda s: str(s.get("name")))
    scenarios = all_scenarios
    if args.only_failures:
        scenarios = [s for s in all_scenarios if s.get("status") != "pass"]

    ranked = sorted(
        scenarios if args.only_failures else all_scenarios,
        key=lambda scenario: float(scenario.get("duration_ms", 0.0)),
        reverse=True,
    )
    mismatches = data.get("mismatches", [])

    if args.as_json:
        metadata_out = metadata
        if args.redact_sensitive and isinstance(metadata, dict):
            metadata_out = dict(metadata)
            if "argv" in metadata_out:
                metadata_out["argv"] = "<redacted>"
            wrapper_env = metadata_out.get("wrapper_env")
            if isinstance(wrapper_env, dict):
                metadata_out["wrapper_env"] = {
                    key: ("<redacted>" if value not in (None, "") else value)
                    for key, value in wrapper_env.items()
                }
        compact_scenarios = [
            {
                "name": scenario.get("name"),
                "status": scenario.get("status"),
                "duration_ms": scenario.get("duration_ms"),
            }
            for scenario in scenarios
        ]
        payload: dict[str, object]
        if args.compact:
            payload = {
                "result": data.get("result"),
                "mismatch_count": data.get("mismatch_count"),
                "total_compare_ms": data.get("total_scenario_compare_ms"),
                "selected_scenarios": selected,
                "scenarios": compact_scenarios,
            }
            if mismatches:
                payload["mismatches"] = mismatches
            if args.top_slowest > 0:
                payload["top_slowest"] = [
                    {
                        "name": scenario.get("name"),
                        "status": scenario.get("status"),
                        "duration_ms": scenario.get("duration_ms"),
                    }
                    for scenario in ranked[: args.top_slowest]
                ]
        else:
            payload = {
                "report": str(report_path),
                "result": data.get("result"),
                "mismatch_count": data.get("mismatch_count"),
                "total_compare_ms": data.get("total_scenario_compare_ms"),
                "selected_scenarios": selected,
                "scenarios": scenarios,
                "mismatches": mismatches,
            }
            if not args.no_metadata:
                payload["metadata"] = metadata_out
            if args.top_slowest > 0:
                payload["top_slowest"] = ranked[: args.top_slowest]
        print(json.dumps(payload, sort_keys=True))
        return 0

    if args.compact:
        print(
            f"result={data.get('result')} "
            f"mismatch_count={data.get('mismatch_count')} "
            f"total_compare_ms={data.get('total_scenario_compare_ms')}"
        )
        for scenario in scenarios:
            print(
                f"{scenario.get('name')} "
                f"status={scenario.get('status')} "
                f"duration_ms={scenario.get('duration_ms'):.1f}"
            )
        if mismatches:
            for msg in mismatches:
                print(f"mismatch={msg}")
        return 0

    print(f"Report: {report_path}")
    if metadata and not args.no_metadata:
        print(f"Tool: {metadata.get('tool')}")
        print(f"Python: {metadata.get('python_version')}")
        print(f"Generated UTC: {metadata.get('generated_at_utc')}")
        argv = metadata.get("argv")
        if isinstance(argv, list):
            if args.redact_sensitive:
                print("Args: <redacted>")
            else:
                print(f"Args: {' '.join(str(v) for v in argv)}")
        wrapper_env = metadata.get("wrapper_env")
        if isinstance(wrapper_env, dict):
            active_env = {
                key: value
                for key, value in wrapper_env.items()
                if value not in (None, "")
            }
            if active_env:
                if args.redact_sensitive:
                    pretty_env = " ".join(
                        f"{key}=<redacted>" for key in sorted(active_env)
                    )
                else:
                    pretty_env = " ".join(
                        f"{key}={value}" for key, value in sorted(active_env.items())
                    )
                print(f"Wrapper env: {pretty_env}")
    print(f"Result: {data.get('result')}")
    print(f"Mismatch count: {data.get('mismatch_count')}")
    print(f"Total compare ms: {data.get('total_scenario_compare_ms')}")
    print(f"Selected scenarios: {', '.join(selected)}")
    print("Scenario summary:")

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
        for scenario in ranked[: args.top_slowest]:
            print(
                "- "
                f"{scenario.get('name')} "
                f"duration_ms={float(scenario.get('duration_ms', 0.0)):.1f} "
                f"status={scenario.get('status')}"
            )

    if mismatches:
        print("Mismatches:")
        for msg in mismatches:
            print(f"- {msg}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
