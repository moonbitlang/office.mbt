#!/usr/bin/env python3
from __future__ import annotations

import argparse
import glob
import re
from pathlib import Path


def _normalize_fn_name(name: str) -> str:
    n = name.strip().upper()
    if n.startswith("_XLFN."):
        n = n[len("_XLFN.") :]
    return n


def excelize_function_names(calc_go: Path) -> set[str]:
    """
    Extract function names supported by Excelize's formula engine.

    Excelize normalizes function names by removing `_xlfn.` and replacing `.`
    with `dot` to map to `formulaFuncs` method names. We reverse that here.
    """
    text = calc_go.read_text(encoding="utf-8", errors="replace")
    method_re = re.compile(r"func\s+\(fn\s+\*formulaFuncs\)\s+([A-Za-z0-9_]+)\s*\(")
    out: set[str] = set()
    for m in method_re.finditer(text):
        raw = m.group(1)
        # Excelize's function dispatcher maps to *exported* methods on formulaFuncs.
        # Helpers are typically lower-cased; ignore those to avoid false positives.
        if not raw or not raw[0].isupper():
            continue
        # Excelize uses `dot` in identifiers to represent '.' in function names.
        name = raw.replace("dot", ".")
        # Some functions are implemented as helpers but still end up callable; keep them.
        out.add(_normalize_fn_name(name))
    return out


def moonbit_function_names(formula_files: list[Path]) -> set[str]:
    """
    Heuristic:
    - collect names compared against the formula dispatcher variable `name`
      (e.g. `if name == "ROW"`)
    - collect string-case arms inside `match name { ... }` blocks
      (e.g. `"SUM" =>`, `"SUM" | "SUBTOTAL" =>`)
    - normalize `_XLFN.` prefix
    """
    eq_re = re.compile(r'\bname\s*==\s*"([A-Z_][A-Z0-9_\\.]*?)"')
    # Examples: "SUM" =>, "SUM" | "SUBTOTAL" =>, "_XLFN.SEQUENCE" =>
    case_re = re.compile(r"\"([A-Z_][A-Z0-9_\\.]*?)\"\s*(?:\||=>)")
    out: set[str] = set()
    for file in formula_files:
        text = file.read_text(encoding="utf-8", errors="replace")
        for m in eq_re.finditer(text):
            out.add(_normalize_fn_name(m.group(1)))
        lines = text.splitlines()
        i = 0
        while i < len(lines):
            line = lines[i]
            if re.search(r"\bmatch\s+name\s*\{", line):
                depth = line.count("{") - line.count("}")
                block_lines: list[str] = []
                i += 1
                while i < len(lines) and depth > 0:
                    arm = lines[i]
                    block_lines.append(arm)
                    depth += arm.count("{") - arm.count("}")
                    i += 1
                block_text = "\n".join(block_lines)
                for m in case_re.finditer(block_text):
                    out.add(_normalize_fn_name(m.group(1)))
                continue
            i += 1
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--excelize-calc", default="excelize/calc.go")
    ap.add_argument(
        "--moonbit-formula",
        action="append",
        default=[
            "xlsx/formula_eval.mbt",
            "xlsx/formula_builtins.mbt",
            "xlsx/formula_builtins_financial.mbt",
            "xlsx/formula_builtins_stats.mbt",
        ],
        help=(
            "MoonBit formula implementation file(s) or glob(s). "
            "Can be repeated. Defaults to core formula evaluator + builtins."
        ),
    )
    ap.add_argument("--show-extra", action="store_true", help="Also show functions present in MoonBit but not Excelize.")
    args = ap.parse_args()

    excelize = excelize_function_names(Path(args.excelize_calc))
    moonbit_files: list[Path] = []
    seen: set[Path] = set()
    for pattern in args.moonbit_formula:
        matches = [Path(p) for p in glob.glob(pattern)]
        if not matches:
            matches = [Path(pattern)]
        for path in matches:
            if path in seen:
                continue
            seen.add(path)
            moonbit_files.append(path)
    moonbit = moonbit_function_names(moonbit_files)

    missing = sorted(excelize - moonbit)
    extra = sorted(moonbit - excelize)

    print(f"Excelize formula funcs (method-derived): {len(excelize)}")
    print(f"MoonBit formula names (dispatch+literal heuristic): {len(moonbit)}")
    print(f"Missing in MoonBit: {len(missing)}")
    for name in missing[:500]:
        print(f"  - {name}")
    if len(missing) > 500:
        print(f"  ... ({len(missing)-500} more)")

    if args.show_extra:
        print(f"\nExtra in MoonBit (heuristic): {len(extra)}")
        for name in extra[:200]:
            print(f"  + {name}")
        if len(extra) > 200:
            print(f"  ... ({len(extra)-200} more)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
