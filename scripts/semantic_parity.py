#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
import zipfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Scenario:
    name: str
    mbt_file: str
    excelize_file: str
    keys: tuple[str, ...]


SUMMARY_KEYS: tuple[str, ...] = (
    "worksheets",
    "tables",
    "charts",
    "drawings",
    "vml_drawings",
    "form_controls",
    "conditional_formatting",
    "x14_conditional_formatting",
    "data_validations",
    "shared_string_items",
    "has_shared_strings_part",
    "has_calc_chain_part",
)


SCENARIOS: tuple[Scenario, ...] = (
    Scenario(
        name="dashboard",
        mbt_file="dashboard.xlsx",
        excelize_file="dashboard.xlsx",
        keys=(
            "sheet_names",
            "worksheets",
            "tables",
            "charts",
            "drawings",
            "vml_drawings",
            "form_controls",
            "form_control_types",
            "conditional_formatting",
            "x14_conditional_formatting",
            "data_validations",
            "chart_types",
            "has_shared_strings_part",
            "has_styles_part",
            "has_theme_part",
            "workbook_rel_targets",
            "worksheet_rel_targets",
            "drawing_rel_targets",
        ),
    ),
    Scenario(
        name="controls",
        mbt_file="controls.xlsx",
        excelize_file="controls.xlsx",
        keys=(
            "sheet_names",
            "worksheets",
            "tables",
            "charts",
            "drawings",
            "vml_drawings",
            "form_controls",
            "form_control_types",
            "conditional_formatting",
            "x14_conditional_formatting",
            "data_validations",
            "chart_types",
            "has_shared_strings_part",
            "has_calc_chain_part",
            "has_styles_part",
            "has_theme_part",
            "workbook_rel_targets",
            "worksheet_rel_targets",
            "drawing_rel_targets",
        ),
    ),
    Scenario(
        name="cf",
        mbt_file="cf.xlsx",
        excelize_file="cf.xlsx",
        keys=(
            "sheet_names",
            "worksheets",
            "tables",
            "charts",
            "drawings",
            "vml_drawings",
            "form_controls",
            "form_control_types",
            "conditional_formatting",
            "x14_conditional_formatting",
            "data_validations",
            "cf_rule_types",
            "chart_types",
            "has_shared_strings_part",
            "has_calc_chain_part",
            "has_styles_part",
            "has_theme_part",
            "workbook_rel_targets",
            "worksheet_rel_targets",
            "drawing_rel_targets",
        ),
    ),
    Scenario(
        name="controls_rerun",
        mbt_file="controls.xlsx",
        excelize_file="controls_rerun.xlsx",
        keys=(
            "sheet_names",
            "worksheets",
            "tables",
            "charts",
            "drawings",
            "vml_drawings",
            "form_controls",
            "form_control_types",
            "conditional_formatting",
            "x14_conditional_formatting",
            "data_validations",
            "chart_types",
            "has_shared_strings_part",
            "has_calc_chain_part",
            "has_styles_part",
            "has_theme_part",
            "workbook_rel_targets",
            "worksheet_rel_targets",
            "drawing_rel_targets",
        ),
    ),
    Scenario(
        name="shared_strings",
        mbt_file="shared_strings.xlsx",
        excelize_file="shared_strings.xlsx",
        keys=(
            "sheet_names",
            "worksheets",
            "shared_string_items",
            "has_shared_strings_part",
            "has_calc_chain_part",
            "has_styles_part",
            "has_theme_part",
            "workbook_rel_targets",
            "worksheet_rel_targets",
            "drawing_rel_targets",
        ),
    ),
)


def run(cmd: list[str], cwd: Path | None = None) -> None:
    proc = subprocess.run(cmd, cwd=cwd, text=True)
    if proc.returncode != 0:
        joined = " ".join(cmd)
        where = f" (cwd={cwd})" if cwd else ""
        raise RuntimeError(f"command failed: {joined}{where}")


def read_text_from_zip(z: zipfile.ZipFile, name: str) -> str:
    return z.read(name).decode("utf-8", "ignore")


def workbook_sheet_names(workbook_xml: str) -> list[str]:
    return re.findall(r"<sheet[^>]*\bname=\"([^\"]+)\"", workbook_xml)


def rel_targets(rels_xml: str) -> list[str]:
    return re.findall(r"<Relationship[^>]*\bTarget=\"([^\"]+)\"", rels_xml)


def normalize_rel_target(target: str) -> str | None:
    # Normalize known relationship-target variability so comparisons focus on structure:
    # - leading absolute `/xl/` vs relative paths
    # - numeric OOXML part ids (`drawing1.xml` vs `drawing2.xml`)
    # - calcChain presence (implementation detail in these fixtures)
    normalized = target.replace("\\", "/")
    if normalized.startswith("/xl/"):
        normalized = normalized[len("/xl/") :]
    elif normalized.startswith("xl/"):
        normalized = normalized[len("xl/") :]

    if normalized == "calcChain.xml":
        return None

    normalized = re.sub(
        r"(\.\./drawings/drawing)\d+(\.xml)$", r"\1*.xml", normalized
    )
    normalized = re.sub(
        r"(\.\./charts/chart)\d+(\.xml)$", r"\1*.xml", normalized
    )
    normalized = re.sub(
        r"(\.\./tables/table)\d+(\.xml)$", r"\1*.xml", normalized
    )
    normalized = re.sub(
        r"(\.\./media/image)\d+(\.[A-Za-z0-9]+)$", r"\1*\2", normalized
    )
    return normalized


def normalized_rel_targets(rels_xml: str) -> list[str]:
    normalized: list[str] = []
    for target in rel_targets(rels_xml):
        value = normalize_rel_target(target)
        if value is not None:
            normalized.append(value)
    return normalized


def fingerprint(path: Path) -> dict[str, object]:
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        ws_names = [n for n in names if re.fullmatch(r"xl/worksheets/sheet\d+\.xml", n)]
        table_names = [n for n in names if re.fullmatch(r"xl/tables/table\d+\.xml", n)]
        chart_names = [n for n in names if re.fullmatch(r"xl/charts/chart\d+\.xml", n)]
        drawing_names = [n for n in names if re.fullmatch(r"xl/drawings/drawing\d+\.xml", n)]
        vml_names = [n for n in names if re.fullmatch(r"xl/drawings/vmlDrawing\d+\.vml", n)]
        slicer_names = [n for n in names if re.fullmatch(r"xl/slicers/slicer\d+\.xml", n)]
        pivot_names = [n for n in names if re.fullmatch(r"xl/pivotTables/pivotTable\d+\.xml", n)]
        pivot_cache_names = [
            n
            for n in names
            if re.fullmatch(r"xl/pivotCache/pivotCacheDefinition\d+\.xml", n)
        ]
        worksheet_rel_names = [
            n
            for n in names
            if re.fullmatch(r"xl/worksheets/_rels/sheet\d+\.xml\.rels", n)
        ]
        drawing_rel_names = [
            n
            for n in names
            if re.fullmatch(r"xl/drawings/_rels/drawing\d+\.xml\.rels", n)
        ]
        workbook_xml = read_text_from_zip(z, "xl/workbook.xml")
        has_shared_strings_part = "xl/sharedStrings.xml" in names
        has_calc_chain_part = "xl/calcChain.xml" in names
        has_styles_part = "xl/styles.xml" in names
        has_theme_part = "xl/theme/theme1.xml" in names
        workbook_rel_targets: list[str] = []
        worksheet_rel_targets: list[str] = []
        drawing_rel_targets: list[str] = []
        if "xl/_rels/workbook.xml.rels" in names:
            workbook_rel_targets = normalized_rel_targets(
                read_text_from_zip(z, "xl/_rels/workbook.xml.rels")
            )
        for rel_name in worksheet_rel_names:
            worksheet_rel_targets.extend(
                normalized_rel_targets(read_text_from_zip(z, rel_name))
            )
        for rel_name in drawing_rel_names:
            drawing_rel_targets.extend(
                normalized_rel_targets(read_text_from_zip(z, rel_name))
            )
        conditional_count = 0
        x14_conditional_count = 0
        data_validation_count = 0
        cf_rule_types: list[str] = []
        form_control_count = 0
        form_control_types: list[str] = []
        chart_types: list[str] = []
        shared_string_items = 0
        if "xl/sharedStrings.xml" in names:
            shared_strings = read_text_from_zip(z, "xl/sharedStrings.xml")
            shared_string_items = len(re.findall(r"<si\b", shared_strings))
        for ws in ws_names:
            text = read_text_from_zip(z, ws)
            conditional_count += len(re.findall(r"<conditionalFormatting\b", text))
            x14_conditional_count += len(re.findall(r"<x14:conditionalFormatting\b", text))
            data_validation_count += len(re.findall(r"<dataValidation\b", text))
            cf_rule_types.extend(re.findall(r"<cfRule[^>]*\btype=\"([^\"]+)\"", text))
            cf_rule_types.extend(re.findall(r"<x14:cfRule[^>]*\btype=\"([^\"]+)\"", text))
        for vml in vml_names:
            text = read_text_from_zip(z, vml)
            types = re.findall(r"<x:ClientData[^>]*\bObjectType=\"([^\"]+)\"", text)
            form_control_count += len(types)
            form_control_types.extend(types)
        for chart in chart_names:
            text = read_text_from_zip(z, chart)
            chart_types.extend(re.findall(r"<(?:c:)?([A-Za-z0-9]+Chart)\b", text))
        return {
            "sheet_names": workbook_sheet_names(workbook_xml),
            "worksheets": len(ws_names),
            "tables": len(table_names),
            "charts": len(chart_names),
            "drawings": len(drawing_names),
            "vml_drawings": len(vml_names),
            "slicers": len(slicer_names),
            "pivot_tables": len(pivot_names),
            "pivot_caches": len(pivot_cache_names),
            "conditional_formatting": conditional_count,
            "x14_conditional_formatting": x14_conditional_count,
            "data_validations": data_validation_count,
            "cf_rule_types": sorted(cf_rule_types),
            "shared_string_items": shared_string_items,
            "has_shared_strings_part": has_shared_strings_part,
            "has_calc_chain_part": has_calc_chain_part,
            "has_styles_part": has_styles_part,
            "has_theme_part": has_theme_part,
            "form_controls": form_control_count,
            "form_control_types": sorted(form_control_types),
            "chart_types": sorted(chart_types),
            "workbook_rel_targets": sorted(workbook_rel_targets),
            "worksheet_rel_targets": sorted(worksheet_rel_targets),
            "drawing_rel_targets": sorted(drawing_rel_targets),
        }


def copy_fixture_outputs(repo_root: Path, excelize_out: Path) -> None:
    mapping = {
        "dashboard.xlsx": repo_root / "demos_out_go" / "dashboard.xlsx",
        "controls.xlsx": repo_root / "demos_out_go" / "excelize_controls.xlsx",
        "controls_rerun.xlsx": repo_root / "demos_out_go" / "excelize_controls_rerun.xlsx",
        "cf.xlsx": repo_root / "demos_out_go" / "excelize_cf.xlsx",
        "shared_strings.xlsx": repo_root / "excelize" / "test" / "SharedStrings.xlsx",
    }
    excelize_out.mkdir(parents=True, exist_ok=True)
    for out_name, src in mapping.items():
        dst = excelize_out / out_name
        if not src.exists():
            raise FileNotFoundError(f"missing fixture: {src}")
        shutil.copyfile(src, dst)


def can_run_go() -> bool:
    return shutil.which("go") is not None


def generate_excelize_outputs(repo_root: Path, excelize_out: Path) -> str:
    excelize_out.mkdir(parents=True, exist_ok=True)
    excelize_dir = repo_root / "excelize"
    shared_strings_fixture = repo_root / "excelize" / "test" / "SharedStrings.xlsx"
    if can_run_go():
        run(["go", "run", "./_mbtexcel_gen_dashboard/main.go", str(excelize_out / "dashboard.xlsx")], cwd=excelize_dir)
        run(["go", "run", "./_mbtexcel_gen_controls/main.go", str(excelize_out / "controls.xlsx")], cwd=excelize_dir)
        run(
            [
                "go",
                "run",
                "./_mbtexcel_gen_controls/main.go",
                str(excelize_out / "controls_rerun.xlsx"),
            ],
            cwd=excelize_dir,
        )
        run(["go", "run", "./_mbtexcel_gen_cf/main.go", str(excelize_out / "cf.xlsx")], cwd=excelize_dir)
        shutil.copyfile(shared_strings_fixture, excelize_out / "shared_strings.xlsx")
        return "go-generated"
    copy_fixture_outputs(repo_root, excelize_out)
    return "fixture-copied"


def validate_xlsx_outputs(repo_root: Path, out_dir: Path) -> None:
    validator = repo_root / "scripts" / "validate_xlsx.sh"
    for path in sorted(out_dir.glob("*.xlsx")):
        run(["bash", str(validator), str(path)], cwd=repo_root)


def compare_scenario(
    mbt_path: Path, excelize_path: Path, scenario: Scenario
) -> tuple[list[str], dict[str, object], dict[str, object]]:
    mbt = fingerprint(mbt_path)
    excelize = fingerprint(excelize_path)
    mismatches: list[str] = []
    for key in scenario.keys:
        if mbt.get(key) != excelize.get(key):
            mismatches.append(
                f"{scenario.name}: key `{key}` mismatch: mbtexcel={mbt.get(key)!r}, excelize={excelize.get(key)!r}"
            )
    return mismatches, mbt, excelize


def summary_view(fingerprint_data: dict[str, object]) -> dict[str, object]:
    return {key: fingerprint_data.get(key) for key in SUMMARY_KEYS}


def main() -> int:
    parser = argparse.ArgumentParser(description="Run semantic parity checks against Excelize outputs.")
    parser.add_argument("--mbt-dir", default="_build/semantic_parity/mbt")
    parser.add_argument("--excelize-dir", default="_build/semantic_parity/excelize")
    parser.add_argument("--skip-validate", action="store_true")
    parser.add_argument(
        "--validate-excelize",
        action="store_true",
        help="Also validate Excelize outputs with OpenXML validator.",
    )
    parser.add_argument(
        "--scenario",
        action="append",
        choices=[s.name for s in SCENARIOS],
        help="Only run selected scenario(s). Repeatable.",
    )
    parser.add_argument(
        "--print-fingerprints-on-fail",
        action="store_true",
        help="Print selected fingerprint keys for failing scenarios.",
    )
    parser.add_argument(
        "--print-summary",
        action="store_true",
        help="Print compact per-scenario summary keys on success.",
    )
    parser.add_argument(
        "--print-durations",
        action="store_true",
        help="Print per-scenario comparison durations.",
    )
    parser.add_argument(
        "--sort-scenarios",
        action="store_true",
        help="Run selected scenarios in alphabetical order.",
    )
    parser.add_argument(
        "--list-scenarios",
        action="store_true",
        help="List available scenarios and exit.",
    )
    parser.add_argument(
        "--json-report",
        help="Write machine-readable parity report JSON to this path.",
    )
    args = parser.parse_args()

    if args.list_scenarios:
        for scenario in SCENARIOS:
            print(
                f"{scenario.name}\tmbt={scenario.mbt_file}\texcelize={scenario.excelize_file}"
            )
        return 0

    repo_root = Path(__file__).resolve().parents[1]
    mbt_out = (repo_root / args.mbt_dir).resolve()
    excelize_out = (repo_root / args.excelize_dir).resolve()

    run(["moon", "run", "cmd/parity", "--", str(mbt_out)], cwd=repo_root)
    excelize_source = generate_excelize_outputs(repo_root, excelize_out)

    if not args.skip_validate:
        validate_xlsx_outputs(repo_root, mbt_out)
        if args.validate_excelize:
            validate_xlsx_outputs(repo_root, excelize_out)

    selected = SCENARIOS
    if args.scenario:
        keep = set(args.scenario)
        selected = tuple(s for s in SCENARIOS if s.name in keep)
    if args.sort_scenarios:
        selected = tuple(sorted(selected, key=lambda scenario: scenario.name))
    if args.scenario and not selected:
        print(
            "No scenarios selected after applying --scenario filters.",
            file=sys.stderr,
        )
        return 2

    selected_names = ", ".join(s.name for s in selected)
    print("Semantic parity run configuration:")
    print(f"- mbtexcel output dir: {mbt_out}")
    print(f"- excelize output dir: {excelize_out}")
    print(f"- selected scenarios: {selected_names}")
    print(f"- skip validator: {args.skip_validate}")
    print(f"- validate excelize outputs: {args.validate_excelize}")

    print(f"Excelize output source: {excelize_source}")
    all_mismatches: list[str] = []
    scenario_reports: list[dict[str, object]] = []
    compare_start = time.perf_counter()
    for scenario in selected:
        scenario_start = time.perf_counter()
        mbt_file = mbt_out / scenario.mbt_file
        excelize_file = excelize_out / scenario.excelize_file
        if not mbt_file.exists():
            msg = f"{scenario.name}: missing mbtexcel file: {mbt_file}"
            all_mismatches.append(msg)
            scenario_reports.append(
                {
                    "name": scenario.name,
                    "status": "missing_mbtexcel_file",
                    "duration_ms": (time.perf_counter() - scenario_start) * 1000.0,
                    "mbt_file": str(mbt_file),
                    "excelize_file": str(excelize_file),
                    "mismatches": [msg],
                }
            )
            continue
        if not excelize_file.exists():
            msg = f"{scenario.name}: missing excelize file: {excelize_file}"
            all_mismatches.append(msg)
            scenario_reports.append(
                {
                    "name": scenario.name,
                    "status": "missing_excelize_file",
                    "duration_ms": (time.perf_counter() - scenario_start) * 1000.0,
                    "mbt_file": str(mbt_file),
                    "excelize_file": str(excelize_file),
                    "mismatches": [msg],
                }
            )
            continue
        mismatches, mbt_fingerprint, excelize_fingerprint = compare_scenario(
            mbt_file, excelize_file, scenario
        )
        duration_ms = (time.perf_counter() - scenario_start) * 1000.0
        status_suffix = (
            f" ({duration_ms:.1f} ms)" if args.print_durations else ""
        )
        if mismatches:
            all_mismatches.extend(mismatches)
            print(f"[FAIL] {scenario.name}{status_suffix}")
            if args.print_fingerprints_on_fail:
                selected_mbt = {
                    key: mbt_fingerprint.get(key) for key in scenario.keys
                }
                selected_excelize = {
                    key: excelize_fingerprint.get(key) for key in scenario.keys
                }
                print("  mbtexcel fingerprint:")
                print(json.dumps(selected_mbt, indent=2, sort_keys=True))
                print("  excelize fingerprint:")
                print(json.dumps(selected_excelize, indent=2, sort_keys=True))
        else:
            print(f"[PASS] {scenario.name}{status_suffix}")
            if args.print_summary:
                print(
                    "  summary: "
                    + json.dumps(
                        summary_view(mbt_fingerprint), sort_keys=True
                    )
                )
        scenario_reports.append(
            {
                "name": scenario.name,
                "status": "fail" if mismatches else "pass",
                "duration_ms": duration_ms,
                "mbt_file": str(mbt_file),
                "excelize_file": str(excelize_file),
                "keys": list(scenario.keys),
                "mismatches": mismatches,
                "mbtexcel": {key: mbt_fingerprint.get(key) for key in scenario.keys},
                "excelize": {
                    key: excelize_fingerprint.get(key) for key in scenario.keys
                },
                "summary": summary_view(mbt_fingerprint),
            }
        )

    total_ms = (time.perf_counter() - compare_start) * 1000.0
    if args.json_report:
        report_path = Path(args.json_report)
        if not report_path.is_absolute():
            report_path = (repo_root / report_path).resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report = {
            "result": "pass" if not all_mismatches else "fail",
            "excelize_output_source": excelize_source,
            "mbtexcel_output_dir": str(mbt_out),
            "excelize_output_dir": str(excelize_out),
            "selected_scenarios": [s.name for s in selected],
            "skip_validate": args.skip_validate,
            "validate_excelize": args.validate_excelize,
            "total_scenario_compare_ms": total_ms,
            "mismatch_count": len(all_mismatches),
            "mismatches": all_mismatches,
            "scenarios": scenario_reports,
        }
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(f"JSON report written: {report_path}")

    if all_mismatches:
        print("\nMismatches:")
        for msg in all_mismatches:
            print(f"- {msg}")
        if args.print_durations:
            print(f"\nTotal scenario compare time: {total_ms:.1f} ms")
        return 1

    if args.print_durations:
        print(f"Total scenario compare time: {total_ms:.1f} ms")

    print("\nSemantic parity checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
