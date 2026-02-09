#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Scenario:
    name: str
    mbt_file: str
    excelize_file: str
    keys: tuple[str, ...]


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
    return re.findall(r"<sheet[^>]*\\bname=\"([^\"]+)\"", workbook_xml)


def fingerprint(path: Path) -> dict[str, object]:
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        ws_names = [n for n in names if re.fullmatch(r"xl/worksheets/sheet\\d+\\.xml", n)]
        table_names = [n for n in names if re.fullmatch(r"xl/tables/table\\d+\\.xml", n)]
        chart_names = [n for n in names if re.fullmatch(r"xl/charts/chart\\d+\\.xml", n)]
        drawing_names = [n for n in names if re.fullmatch(r"xl/drawings/drawing\\d+\\.xml", n)]
        vml_names = [n for n in names if re.fullmatch(r"xl/drawings/vmlDrawing\\d+\\.vml", n)]
        slicer_names = [n for n in names if re.fullmatch(r"xl/slicers/slicer\\d+\\.xml", n)]
        pivot_names = [n for n in names if re.fullmatch(r"xl/pivotTables/pivotTable\\d+\\.xml", n)]
        pivot_cache_names = [
            n
            for n in names
            if re.fullmatch(r"xl/pivotCache/pivotCacheDefinition\\d+\\.xml", n)
        ]
        workbook_xml = read_text_from_zip(z, "xl/workbook.xml")
        conditional_count = 0
        x14_conditional_count = 0
        data_validation_count = 0
        cf_rule_types: list[str] = []
        form_control_count = 0
        form_control_types: list[str] = []
        chart_types: list[str] = []
        for ws in ws_names:
            text = read_text_from_zip(z, ws)
            conditional_count += len(re.findall(r"<conditionalFormatting\\b", text))
            x14_conditional_count += len(re.findall(r"<x14:conditionalFormatting\\b", text))
            data_validation_count += len(re.findall(r"<dataValidation\\b", text))
            cf_rule_types.extend(re.findall(r"<cfRule[^>]*\\btype=\"([^\"]+)\"", text))
            cf_rule_types.extend(re.findall(r"<x14:cfRule[^>]*\\btype=\"([^\"]+)\"", text))
        for vml in vml_names:
            text = read_text_from_zip(z, vml)
            types = re.findall(r"<x:ClientData[^>]*\\bObjectType=\"([^\"]+)\"", text)
            form_control_count += len(types)
            form_control_types.extend(types)
        for chart in chart_names:
            text = read_text_from_zip(z, chart)
            chart_types.extend(
                re.findall(r"<(?:c:)?([A-Za-z0-9]+Chart)\\b", text)
            )
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
            "form_controls": form_control_count,
            "form_control_types": sorted(form_control_types),
            "chart_types": sorted(chart_types),
        }


def copy_fixture_outputs(repo_root: Path, excelize_out: Path) -> None:
    fixture_dir = repo_root / "demos_out_go"
    mapping = {
        "dashboard.xlsx": "dashboard.xlsx",
        "controls.xlsx": "excelize_controls.xlsx",
        "controls_rerun.xlsx": "excelize_controls_rerun.xlsx",
        "cf.xlsx": "excelize_cf.xlsx",
    }
    excelize_out.mkdir(parents=True, exist_ok=True)
    for out_name, fixture_name in mapping.items():
        src = fixture_dir / fixture_name
        dst = excelize_out / out_name
        if not src.exists():
            raise FileNotFoundError(f"missing fixture: {src}")
        shutil.copyfile(src, dst)


def can_run_go() -> bool:
    return shutil.which("go") is not None


def generate_excelize_outputs(repo_root: Path, excelize_out: Path) -> str:
    excelize_out.mkdir(parents=True, exist_ok=True)
    excelize_dir = repo_root / "excelize"
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
        return "go-generated"
    copy_fixture_outputs(repo_root, excelize_out)
    return "fixture-copied"


def validate_xlsx_outputs(repo_root: Path, out_dir: Path) -> None:
    validator = repo_root / "scripts" / "validate_xlsx.sh"
    for path in sorted(out_dir.glob("*.xlsx")):
        run(["bash", str(validator), str(path)], cwd=repo_root)


def compare_scenario(mbt_path: Path, excelize_path: Path, scenario: Scenario) -> list[str]:
    mbt = fingerprint(mbt_path)
    excelize = fingerprint(excelize_path)
    mismatches: list[str] = []
    for key in scenario.keys:
        if mbt.get(key) != excelize.get(key):
            mismatches.append(
                f"{scenario.name}: key `{key}` mismatch: mbtexcel={mbt.get(key)!r}, excelize={excelize.get(key)!r}"
            )
    return mismatches


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
    args = parser.parse_args()

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

    print(f"Excelize output source: {excelize_source}")
    all_mismatches: list[str] = []
    for scenario in selected:
        mbt_file = mbt_out / scenario.mbt_file
        excelize_file = excelize_out / scenario.excelize_file
        if not mbt_file.exists():
            all_mismatches.append(f"{scenario.name}: missing mbtexcel file: {mbt_file}")
            continue
        if not excelize_file.exists():
            all_mismatches.append(f"{scenario.name}: missing excelize file: {excelize_file}")
            continue
        mismatches = compare_scenario(mbt_file, excelize_file, scenario)
        if mismatches:
            all_mismatches.extend(mismatches)
            print(f"[FAIL] {scenario.name}")
        else:
            print(f"[PASS] {scenario.name}")

    if all_mismatches:
        print("\nMismatches:")
        for msg in all_mismatches:
            print(f"- {msg}")
        return 1

    print("\nSemantic parity checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
