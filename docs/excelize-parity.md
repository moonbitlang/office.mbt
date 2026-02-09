# Excelize parity (mbtexcel)

This repo vendors a snapshot of Excelize in `excelize/` and ports the workbook
logic to MoonBit in `xlsx/`.

## Scope of comparison

- Excelize snapshot: `excelize@37b730a` (see `git -C excelize rev-parse HEAD`)
- mbtexcel snapshot: current checkout (see `git rev-parse HEAD`)

When I say “parity” below, I mean **end-user features and ergonomics**, not just
“there exists an API method with the same name”.

## TL;DR

- **Method-name parity is very high**: by normalized name, every exported
  Excelize function / `(*File)` method has a corresponding exported MoonBit API
  name (often on `Workbook` / `Worksheet` / `StreamWriter`).
- **Feature parity is high but not 100%**: most “option-struct driven” features
  now have typed MoonBit models (styles, charts, shapes, sparklines, pivot
  tables, slicers, tables, pictures, conditional formats), but some models are
  still **subsets** of Excelize and a few features remain unsupported.

## Major remaining parity gaps / differences

### 1) Some option models are still smaller than Excelize’s

Most major Excelize option structs have MoonBit counterparts, but some are
still subsets (missing some rarely-used flags/fields). The biggest remaining
examples are usually in “long tail” formatting knobs (styles, charts, rich
text).

Impact:
- Some advanced formatting knobs require extending the MoonBit model (or falling
  back to emitting raw OOXML XML in places where that’s exposed).

### 2) Rich text font model is close to Excelize’s `Font`, but not identical

- Excelize rich text runs reference `Font` (includes theme/indexed/tint colors)
  (`excelize/xmlSharedStrings.go`, `excelize/xmlStyles.go`).
- mbtexcel rich text uses `RichTextFont` and now covers the most common font
  run properties (bold/italic/underline/size/rFont, strike/outline/shadow/
  condense/extend/charset/family/scheme/vertAlign, plus color rgb/theme/indexed
  and tint), but it is still a separate type (not a perfect 1:1 mirror).

Impact:
- Rich text works well for typical usage; if you rely on niche font run
  attributes, validate on real files and add targeted tests.

### 3) Styles and charts aim for practical parity, not a perfect mirror

The style model (`Style` / `Font` / `Fill` / `Border` / `Alignment` /
`Protection`) and chart option types are implemented for common usage, but may
still differ in edge cases and long-tail options compared to Excelize.
For example, style fonts now include more tags (strike/shadow/charset/scheme/
vertAlign), fills support transparency via ARGB alpha and Excelize-style
gradient fills (shading variants), and font/fill colors support theme/indexed +
tint, but there are still areas where the MoonBit model may not expose every
Excelize knob.
For charts, `ChartOptions` now covers common types (bar/col/line/area/pie/
doughnut/radar/scatter/bubble/stock/3D/ofPie) and basic axis/legend +
per-series styling options.

Impact:
- If you rely on very specific Excel formatting behaviors, validate on real
  files and consider adding targeted tests for those cases.

### 4) Some picture formats may not have accurate auto-sizing

mbtexcel infers picture size from image bytes to compute EMU extents.
Common raster formats are supported; however, Windows metafiles like
EMZ/WMZ (gzip-compressed EMF/WMF) are now decompressed and sized correctly.

### 5) VML form controls: mostly supported, with a few remaining gaps

mbtexcel can write and parse VML form controls including macro/cellLink/checked,
sizing (width/height + anchor), scroll/spin options (val/min/max/inc/page +
horizontal), basic `GraphicOptions` flags (printObject/positioning), and
per-control VML presets (fill/stroke + common `<x:ClientData>` defaults).

Remaining gaps are mostly long-tail preset/styling parity for specific control
types and edge-case behaviors.

## Notes / intentional differences

- **Async I/O**: some APIs are `async` in MoonBit (e.g. file I/O, writing to a
  writer). Excelize is synchronous.
- **VBA projects**: supported as raw `vbaProject.bin` bytes (OLE/CFB header
  validated) without attempting to parse/modify macro internals.
- **Formula evaluation**: both projects have formula evaluation APIs, but exact
  supported function coverage and edge-case behavior may differ (this hasn’t
  been exhaustively parity-audited here).

## Parity regression command

Use this fixed-entrypoint script for local/CI semantic parity checks:

```sh
scripts/test_semantic_parity.sh
```

It runs `scripts/semantic_parity.py` with stable output directories under
`_build/semantic_parity/` and fails fast on any scenario mismatch. Extra
arguments are forwarded to the Python runner (for example,
`--scenario controls` or `--print-fingerprints-on-fail`).
The wrapper also enables compact per-scenario summaries in successful runs.

For the full parity gate (semantic parity + demo roundtrip/openxml suites):

```sh
scripts/test_parity_gates.sh
```

## How to keep this doc up to date

1. Identify Excelize features that are “option-struct driven” (usually the
   biggest parity gaps early in a port).
2. For each feature, decide whether mbtexcel should:
   - port the same option model, or
   - expose “raw OOXML XML” and keep the API thin.

For a mechanically-generated, “names-only” view, see
`docs/excelize-parity-generated.md` (regenerate with
`python3 scripts/excelize_parity_report.py --out docs/excelize-parity-generated.md`).
