#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import semantic_parity


def assert_equal(actual: object, expected: object, message: str) -> None:
    if actual != expected:
        raise AssertionError(f"{message}: expected={expected!r}, actual={actual!r}")


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]

    dashboard = semantic_parity.fingerprint(repo_root / "demos_out_go" / "dashboard.xlsx")
    assert_equal(dashboard["sheet_names"], ["Data", "Dashboard"], "dashboard sheet names")
    assert_equal(dashboard["worksheets"], 2, "dashboard worksheet count")
    assert_equal(dashboard["tables"], 1, "dashboard table count")
    assert_equal(dashboard["charts"], 1, "dashboard chart count")
    assert_equal(dashboard["drawings"], 1, "dashboard drawing count")
    assert_equal(dashboard["chart_types"], ["lineChart"], "dashboard chart types")

    controls = semantic_parity.fingerprint(
        repo_root / "demos_out_go" / "excelize_controls.xlsx"
    )
    assert_equal(controls["sheet_names"], ["Sheet1"], "controls sheet names")
    assert_equal(controls["form_controls"], 3, "controls form control count")
    assert_equal(
        controls["form_control_types"],
        ["Checkbox", "Scroll", "Spin"],
        "controls form control types",
    )
    assert_equal(
        controls["worksheet_rel_targets"],
        ["../drawings/vmlDrawing1.vml"],
        "controls worksheet rel targets",
    )

    shared_strings = semantic_parity.fingerprint(
        repo_root / "excelize" / "test" / "SharedStrings.xlsx"
    )
    assert_equal(
        shared_strings["sheet_names"],
        ["Sheet1", "Sheet2"],
        "shared_strings sheet names",
    )
    assert_equal(shared_strings["worksheets"], 2, "shared_strings worksheet count")
    assert_equal(
        shared_strings["shared_string_items"], 2, "shared_strings item count"
    )

    assert_equal(
        semantic_parity.normalize_rel_target("/xl/sharedStrings.xml"),
        "sharedStrings.xml",
        "normalize absolute workbook target",
    )
    assert_equal(
        semantic_parity.normalize_rel_target("../drawings/drawing12.xml"),
        "../drawings/drawing*.xml",
        "normalize drawing target id",
    )
    assert_equal(
        semantic_parity.normalize_rel_target("calcChain.xml"),
        None,
        "ignore calcChain target",
    )

    print("semantic parity fingerprint regression checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
