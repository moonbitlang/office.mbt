#!/usr/bin/env python3
from __future__ import annotations

import argparse
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


def moonbit_function_names(formula_eval_mbt: Path) -> set[str]:
    """
    Heuristic: collect uppercase-ish string literals from formula_eval.mbt,
    then normalize `_XLFN.` prefix.
    """
    text = formula_eval_mbt.read_text(encoding="utf-8", errors="replace")
    # Examples: "SUM", "ISO.CEILING", "MODE.MULT", "_XLFN.SEQUENCE"
    lit_re = re.compile(r"\"([A-Z_][A-Z0-9_\\.]*?)\"")
    out: set[str] = set()
    for m in lit_re.finditer(text):
        out.add(_normalize_fn_name(m.group(1)))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--excelize-calc", default="excelize/calc.go")
    ap.add_argument("--moonbit-formula", default="xlsx/formula_eval.mbt")
    ap.add_argument("--show-extra", action="store_true", help="Also show functions present in MoonBit but not Excelize.")
    args = ap.parse_args()

    excelize = excelize_function_names(Path(args.excelize_calc))
    moonbit = moonbit_function_names(Path(args.moonbit_formula))

    missing = sorted(excelize - moonbit)
    extra = sorted(moonbit - excelize)

    print(f"Excelize formula funcs (method-derived): {len(excelize)}")
    print(f"MoonBit formula names (string-literal heuristic): {len(moonbit)}")
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
