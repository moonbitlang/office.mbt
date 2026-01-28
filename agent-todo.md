# Agent TODOs (Excelize parity)

This file tracks incremental parity work vs the vendored Excelize snapshot in
`excelize/`.

References:
- Human-written gap summary: `docs/excelize-parity.md`
- Generated (names-only) report: `docs/excelize-parity-generated.md` (regen via `python3 scripts/excelize_parity_report.py --out docs/excelize-parity-generated.md`)

## Workflow (per item)

1. Add/extend MoonBit API (+ docs if needed)
2. Add focused tests (prefer snapshots via `inspect`)
3. Run `moon info && moon fmt`
4. Run `moon test` (use `moon test --update` if snapshots legitimately change)
5. Commit with a detailed message and push to `origin/main`

## Feature worklist

### Styles / formatting
- [ ] Expand `xlsx.Style` beyond number formats (Font/Fill/Border/Alignment/Protection parity with Excelize `Style` in `excelize/xmlStyles.go`)
  - [x] Font (cell styles + conditional styles)
  - [x] Fill (pattern/solid + conditional fill)
  - [x] Border (basic left/right/top/bottom + conditional border)
  - [x] Alignment (basic + conditional alignment)
  - [x] Protection (locked/hidden + conditional protection)

### Charts
- [x] Add high-level chart builder types (partial parity with Excelize `Chart*` types in `excelize/xmlChart.go` / `excelize/chart.go`)

### Drawings: pictures & shapes
- [x] Add picture `name` / `alt_text` options (partial parity with Excelize `GraphicOptions` in `excelize/xmlDrawing.go`)
- [x] Add picture lock-aspect option (partial `GraphicOptions` parity)
- [x] Follow-up: picture positioning (oneCell/twoCell/absolute) (more `GraphicOptions` parity)
- [x] Follow-up: picture autofit options (AutoFit / AutoFitIgnoreAspect) (more `GraphicOptions` parity)
- [x] Follow-up: picture `PrintObject` / `Locked` flags (writes `xdr:clientData` attrs) (more `GraphicOptions` parity)
- [ ] Expand `xlsx.Shape` to support size/fill/line/rich text paragraphs (Excelize `Shape`/`ShapeLine` in `excelize/xmlDrawing.go`)
  - [x] Size (width/height + scale) and basic rich-text paragraphs
  - [x] Solid fill (color + transparency) and line (color + width)
  - [x] Name/alt text + `xdr:clientData` flags
  - [x] Positioning (oneCell/twoCell/absolute)

### Sparklines
- [x] Add `SparklineOptions` basic parity (style presets, markers/high/low/first/last/negative, axis, reverse, seriesColor) and round-trip via `SparklineGroupOptions`
- [x] Follow-ups: date axis, hidden, weight, manual min/max, empty cell modes (Excelize `SparklineOptions` in `excelize/xmlWorksheet.go`)

### Pivot tables & slicers
- [ ] Add `PivotTableOptions` builder (Excelize `PivotTableOptions` in `excelize/pivotTable.go`)
- [ ] Add `SlicerOptions` builder (Excelize `SlicerOptions` in `excelize/slicer.go`)

### Cells: formula/hyperlink opts
- [x] Add `FormulaOpts` parity where meaningful (Excelize `FormulaOpts` in `excelize/cell.go`)
- [x] Add `HyperlinkOpts`-like API for richer hyperlinks (Excelize `HyperlinkOpts` in `excelize/cell.go`)

### Conditional formatting
- [ ] Add higher-level `ConditionalFormatOptions` parity (Excelize `ConditionalFormatOptions` in `excelize/xmlWorksheet.go`)

### Tables
- [x] Expand `xlsx.Table` options (row/col stripes, first/last column emphasis, etc.) (Excelize `Table` in `excelize/table.go` / `excelize/xmlTable.go`)
