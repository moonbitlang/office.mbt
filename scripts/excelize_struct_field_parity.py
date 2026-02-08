#!/usr/bin/env python3
"""
Rough field-level parity audit between vendored Excelize Go structs and MoonBit public structs.

This is heuristic and will produce false positives/negatives:
- It ignores types and focuses only on field names (normalized to snake_case).
- It only sees public MoonBit structs (from generated .mbti).

Tip:
- Many MoonBit ports intentionally use different field names to avoid keywords
  (e.g. `typ` vs `type`) or to more closely match OOXML attribute spellings
  (e.g. `sqref` vs Excelize `SqRef` -> `sq_ref`). Use `--normalize-known`
  to reduce this noise.
"""

from __future__ import annotations

import argparse
import pathlib
import re
from dataclasses import dataclass
from typing import Iterable


def camel_to_snake(name: str) -> str:
    s = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", name)
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)
    return s.lower()


@dataclass(frozen=True)
class GoStruct:
    name: str
    fields: list[str]  # snake_case
    file: pathlib.Path


@dataclass(frozen=True)
class MbStruct:
    name: str
    fields: list[str]  # as-is (already snake_case)
    file: pathlib.Path


_GO_STRUCT_RE = re.compile(
    r"(?m)^type\s+([A-Z]\w*)\s+struct\s*\{\s*$"
)


def parse_go_structs(excelize_dir: pathlib.Path) -> dict[str, GoStruct]:
    structs: dict[str, GoStruct] = {}
    for p in excelize_dir.rglob("*.go"):
        if p.name.endswith("_test.go"):
            continue
        txt = p.read_text(encoding="utf-8", errors="ignore")
        for m in _GO_STRUCT_RE.finditer(txt):
            name = m.group(1)
            start = m.end()
            # Find matching closing brace at column 0.
            # Cheap heuristic: scan lines until a line that starts with "}".
            lines = txt[start:].splitlines()
            fields: list[str] = []
            for line in lines:
                if line.startswith("}"):
                    break
                # Trim comments and tags
                raw = line.strip()
                if not raw or raw.startswith("//"):
                    continue
                # Embedded/anonymous fields start with '*' or identifier and no spacing? We'll ignore if it doesn't
                # look like "Name <type>".
                # FieldName is first token.
                tok = raw.split()[0]
                # Skip embedded types (e.g. `xml.Name` or `*foo`)
                if tok.startswith("*") or "." in tok:
                    continue
                if tok[0].islower():
                    continue
                # Skip if this is a closing brace with indentation
                if tok == "}":
                    break
                fields.append(camel_to_snake(tok))
            structs[name] = GoStruct(name=name, fields=fields, file=p)
    return structs


_MB_STRUCT_RE = re.compile(r"(?m)^pub(?:\(all\))?\s+struct\s+([A-Za-z0-9_]+)\s*\{\s*$")


def parse_mbti_structs(paths: list[pathlib.Path]) -> dict[str, MbStruct]:
    structs: dict[str, MbStruct] = {}
    for p in paths:
        txt = p.read_text(encoding="utf-8", errors="ignore")
        lines = txt.splitlines()
        i = 0
        while i < len(lines):
            m = _MB_STRUCT_RE.match(lines[i])
            if not m:
                i += 1
                continue
            name = m.group(1)
            i += 1
            fields: list[str] = []
            while i < len(lines):
                line = lines[i].strip()
                i += 1
                if line == "}":
                    break
                if not line:
                    continue
                # field lines look like:
                #   mut offset_x : Int?
                #   name : String
                parts = line.split()
                if not parts:
                    continue
                if parts[0] == "mut" and len(parts) >= 2:
                    field = parts[1]
                else:
                    field = parts[0]
                if field.endswith(":"):
                    field = field[:-1]
                # Ignore weird lines
                if not re.match(r"^[a-z_][a-z0-9_]*$", field):
                    continue
                fields.append(field)
            structs[name] = MbStruct(name=name, fields=fields, file=p)
    return structs


_KNOWN_ALIASES: dict[str, list[set[str]]] = {
    # Keywords / naming conventions.
    "Border": [{"type", "typ"}],
    "Fill": [{"type", "typ"}, {"color", "colors"}],
    "ConditionalFormatOptions": [{"type", "format_type"}],
    "DataValidation": [{"type", "validation_type"}],
    "FormulaOpts": [{"type", "formula_type"}, {"ref", "range_ref"}],
    "WorkbookPropsOptions": [{"date1904", "date_1904"}],
    # OOXML attribute spellings vs camel->snake.
    "Selection": [{"sq_ref", "sqref"}],
    # Port naming.
    "FormControl": [{"type", "control_type"}, {"macro", "macro_name"}],
    "SlicerOptions": [{"macro", "macro_name"}],
    # Excelize typo in field name (historic): HighColor (Go) -> hight_color (snake).
    "SparklineOptions": [
        {"location", "locations"},
        {"range", "ranges"},
        {"max", "cust_max", "manual_max"},
        {"min", "cust_min", "manual_min"},
        {"type", "sparkline_type"},
        {"hight_color", "high_color"},
    ],
    "Chart": [
        {"type", "typ"},
        {"title", "title_rich"},
        {"fill", "fill_color", "fill_transparency"},
        {"bubble_size", "bubble_scale"},
    ],
    "ChartLine": [{"type", "typ"}, {"fill", "color", "transparency"}],
    "ChartDataLabel": [{"fill", "fill_color", "fill_transparency"}],
    "ChartDataPoint": [{"fill", "fill_color"}],
    "ChartMarker": [{"fill", "fill_color", "fill_transparency"}],
    "ChartPlotArea": [{"fill", "fill_color", "fill_transparency"}],
    "ChartSeries": [
        {"sizes", "bubble_size"},
        {"fill", "fill_color", "fill_transparency"},
    ],
    "ChartUpDownBar": [{"fill", "fill_color"}],
    "ChartAxis": [{"title", "title_rich"}],
    "Shape": [
        {"cell", "reference"},
        {"type", "shape_type"},
        {"macro", "macro_name", "macro_alias"},
    ],
    "Style": [{"num_fmt", "number_format"}],
    "Table": [{"name", "display_name"}, {"range", "range_ref"}],
}


# Some Excelize structs map to differently named MoonBit structs.
_STRUCT_EQUIVALENTS: dict[str, str] = {
    "Chart": "ChartOptions",
}

# MoonBit-only public extension fields that should not be counted as parity
# differences when --normalize-known is enabled.
_KNOWN_MOONBIT_EXTRAS: dict[str, set[str]] = {
    "Chart": {"combo_charts"},
    "Fill": {
        "fg_theme",
        "fg_indexed",
        "fg_tint",
        "bg_theme",
        "bg_indexed",
        "bg_tint",
    },
    "Font": {
        "outline",
        "shadow",
        "condense",
        "extend",
        "family_number",
        "scheme",
    },
    "ChartAxis": {"ax_id"},
    "Table": {"id", "columns"},
}


def _canonicalize_fields(
    struct_name: str,
    fields: Iterable[str],
    normalize_known: bool,
) -> list[str]:
    if not normalize_known:
        return list(fields)
    groups = _KNOWN_ALIASES.get(struct_name, [])
    rep: dict[str, str] = {}
    for g in groups:
        # Prefer the shortest spelling as representative (stable in output).
        r = sorted(g, key=lambda x: (len(x), x))[0]
        for f in g:
            rep[f] = r
    out: list[str] = []
    for f in fields:
        out.append(rep.get(f, f))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--excelize-dir", default="excelize")
    ap.add_argument(
        "--mbti",
        action="append",
        default=["pkg.generated.mbti", "xlsx/pkg.generated.mbti"],
        help="Generated MoonBit interface files (.mbti). Can be repeated.",
    )
    ap.add_argument(
        "--types",
        help="Comma-separated list of Go struct names to include (default: all parsed).",
    )
    ap.add_argument(
        "--out",
        help="Write report to this file (default: stdout).",
    )
    ap.add_argument(
        "--normalize-known",
        action="store_true",
        help="Apply small alias rules to reduce known false positives (typ/type, sqref/sq_ref, etc.).",
    )
    args = ap.parse_args()

    repo_root = pathlib.Path(".").resolve()
    excelize_dir = (repo_root / args.excelize_dir).resolve()
    mbti_paths = [(repo_root / p).resolve() for p in args.mbti]

    go_structs = parse_go_structs(excelize_dir)
    mb_structs = parse_mbti_structs(mbti_paths)

    include: set[str] | None = None
    if args.types:
        include = {t.strip() for t in args.types.split(",") if t.strip()}

    lines: list[str] = []
    rows: list[tuple[str, list[str], list[str], pathlib.Path]] = []
    for go_name, go_s in sorted(go_structs.items(), key=lambda x: x[0]):
        if include is not None and go_name not in include:
            continue
        mb_name = _STRUCT_EQUIVALENTS.get(go_name, go_name)
        mb = mb_structs.get(mb_name)
        if not mb:
            continue

        go_fields = _canonicalize_fields(go_name, go_s.fields, args.normalize_known)
        mb_fields = _canonicalize_fields(go_name, mb.fields, args.normalize_known)

        go_set = set(go_fields)
        mb_set = set(mb_fields)
        missing = [f for f in go_fields if f not in mb_set]
        extra = [f for f in mb_fields if f not in go_set]
        if args.normalize_known:
            known_extra = _KNOWN_MOONBIT_EXTRAS.get(go_name, set())
            if known_extra:
                extra = [f for f in extra if f not in known_extra]
        if missing or extra:
            rows.append((go_name, missing, extra, go_s.file))

    if not rows:
        lines.append("No field-level differences found (heuristic).")
        if args.out:
            pathlib.Path(args.out).write_text("\n".join(lines) + "\n", encoding="utf-8")
        else:
            print(lines[0])
        return 0

    for name, missing, extra, file in rows:
        lines.append(f"\n{name} ({file.relative_to(repo_root)}):")
        if missing:
            lines.append("  missing: " + ", ".join(missing))
        if extra:
            lines.append("  extra:   " + ", ".join(extra))

    if args.normalize_known:
        lines.append("\n(note) --normalize-known was enabled.")

    out = "\n".join(lines) + "\n"
    if args.out:
        pathlib.Path(args.out).write_text(out, encoding="utf-8")
    else:
        print(out, end="")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
