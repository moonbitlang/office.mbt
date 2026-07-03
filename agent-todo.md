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

### Codex deep-audit gaps (2026-07-03)

Verified gaps vs `.repos/excelize` found by a codex CLI cross-audit; the
well-scoped ones were fixed on `feat/excelize-parity-gaps`. Remaining:

- [x] Typed cell values: `Workbook::set_cell_time` / `set_cell_duration` +
      `time_to_excel_date` (feat/excelize-parity-round2)
- [x] Stream writer typed rows: `StreamWriter::new_time_cell` /
      `new_duration_cell` (feat/excelize-parity-round2); nil/blank stream
      cells still render as empty-string cells rather than bare `<c/>`
- [ ] Default charset transcoding: Go XML decoders default to
      `charset.NewReaderLabel`; MoonBit raises on declared non-UTF8 XML unless
      a transcoder is supplied (`xlsx/read.mbt:57`, `mbtexcel.mbt:181`)
- [ ] GetPictures cell/embedded images: Go also returns rich-value cell
      images, `IMAGE()`, and WPS `DISPIMG` pictures; MoonBit only scans
      drawing objects (`.repos/excelize/picture.go:540,1077,1107`)
- [x] SECURITY: encryption salts were fully deterministic (ChaCha8 fixed
      default seed); now time-seeded per process + `set_random_source` hook
      for crypto-grade entropy (feat/excelize-parity-round2). Built-in
      fallback is still not a CSPRNG.
- [x] RC4-style standard encryption verifier layout accepted (non-AES
      AlgID -> 20-byte verifier hash, decryption stays SHA-1 + AES-ECB
      exactly like Go) (feat/rc4-standard-layout)
- [ ] Chart `Fill` semantics: Go supports Fill.Type/Pattern/color arrays via
      `drawShapeFill` for chart/plot/series/marker/data-label/data-point/
      up-down bars; MoonBit flattens to fill_color/fill_transparency
- [ ] LEFTB/RIGHTB/REPLACEB byte semantics differ from Go byte slicing for
      non-ASCII text (`xlsx/formula_builtins.mbt:2838,3073`)
- [x] `culture_info` now resolves language builtin numFmt IDs 27-36/50-62/
      67-81 for en-US/ja-JP/ko-KR/zh-CN/zh-TW (feat/culture-num-fmt); era
      codes with [$-404]/[$-411] locale tokens still pass through raw
- [x] Hyperlinks with both `r:id` and `location` now keep the fragment
      (Hyperlink.location field), match both filters, and survive write
      roundtrips (fix/hyperlink-location-fidelity)

Fixed in this pass: `get_hyperlink_cells`, `get_sheet_protection`,
ChartAxis `drop_lines`/`high_low_lines`, public `ChartLineType` with `Solid`
scheme-color emission, public `PivotTableField` options + dataField
`numFmtId`/subtotal normalization/255-unit name truncation, NaN/Inf cell
values written as strings.


## Maintenance / Cleanup

- [x] Remove `moon check` warnings + deprecated slice usage (commit `4a75627`)
- [x] Coverage: raise `zip/` package coverage to ≥95% (now 705/738 ≈ 95.53%)
- [ ] Coverage: raise `xlsx/` package coverage materially (currently 25277/31302 ≈ 80.75%; 95–98% is a large effort)
- [ ] Coverage: decide how to treat `cmd/main` `fn main` (currently un-coverable by tests)
- [ ] Coverage: audit unreachable branches in `zip/` + `crypto/` (some checks appear dead without whitebox access)
- [ ] Package-by-package readability/perf pass (start with `zip/`, then `ooxml/`, then `crypto/`)
- [ ] Target support: confirm `--target wasm` compatibility (currently `moon check --target all` fails due to missing `@async/fs`/`@process` APIs in dependencies)

### Styles / formatting
- [x] Expand `xlsx.Style` beyond number formats (Font/Fill/Border/Alignment/Protection parity with Excelize `Style` in `excelize/xmlStyles.go`)
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
- [x] Expand `xlsx.Shape` to support size/fill/line/rich text paragraphs (Excelize `Shape`/`ShapeLine` in `excelize/xmlDrawing.go`)
  - [x] Size (width/height + scale) and basic rich-text paragraphs
  - [x] Solid fill (color + transparency) and line (color + width)
  - [x] Name/alt text + `xdr:clientData` flags
  - [x] Positioning (oneCell/twoCell/absolute)

### Sparklines
- [x] Add `SparklineOptions` basic parity (style presets, markers/high/low/first/last/negative, axis, reverse, seriesColor) and round-trip via `SparklineGroupOptions`
- [x] Follow-ups: date axis, hidden, weight, manual min/max, empty cell modes (Excelize `SparklineOptions` in `excelize/xmlWorksheet.go`)

### Pivot tables & slicers
- [x] Add `PivotTableOptions` builder (Excelize `PivotTableOptions` in `excelize/pivotTable.go`)
- [x] Add `SlicerOptions` builder (Excelize `SlicerOptions` in `excelize/slicer.go`)

### Cells: formula/hyperlink opts
- [x] Add `FormulaOpts` parity where meaningful (Excelize `FormulaOpts` in `excelize/cell.go`)
- [x] Add `HyperlinkOpts`-like API for richer hyperlinks (Excelize `HyperlinkOpts` in `excelize/cell.go`)

### Conditional formatting
- [x] Add higher-level `ConditionalFormatOptions` parity (Excelize `ConditionalFormatOptions` in `excelize/xmlWorksheet.go`)
- [x] Read x14 conditional formatting from worksheet `extLst` (iconSet + dataBar advanced props) and expose via `get_conditional_formats`
- [x] Write x14 data bar advanced props (direction/solid/border) with deterministic `<x14:id>` linkage
- [x] Match Excelize `SetConditionalFormat` range normalization for reversed/row/col refs (`A2:A1,B:B,2:2` -> `A2:A1 B1:B1048576 A2:XFD2`)

### Tables
- [x] Expand `xlsx.Table` options (row/col stripes, first/last column emphasis, etc.) (Excelize `Table` in `excelize/table.go` / `excelize/xmlTable.go`)

## Follow-ups (known remaining differences)

- [x] Expand `RichTextFont` toward Excelize `Font` parity (strike/shadow/vertAlign/etc.)
- [x] Audit/expand style long-tail options and add round-trip tests
  - [x] Style `Font` long-tail tags (strike/outline/shadow/condense/extend/charset/family/scheme/vertAlign)
  - [x] Style `Border` diagonalUp/diagonalDown (+ optional vertical/horizontal)
  - [x] Style `Fill` transparency (ARGB alpha) + round-trip tests
  - [x] Style theme/indexed colors + tint (Font/Fill)
- [x] Audit/expand chart option coverage (typed model vs raw OOXML fallbacks)
  - [x] Support more basic chart types (stacked col/bar, area, pie, doughnut, radar, scatter, bubble)
  - [x] Emit axis titles/gridlines/numFmt/tickLblPos + dispBlanksAs + bar gapWidth/overlap
  - [x] Add stock chart support (high-low-close, open-high-low-close)
  - [x] Add 3D chart support (pie3D/line3D/area3D/col3D/bar3D/surface, etc.)
  - [x] Add deeper series styling options (fill/line/marker/data labels/data points)

## Next parity audit targets (deeper / long-tail)

### Charts (long-tail)
- [x] Doughnut chart `holeSize` option
- [x] Bubble chart `bubbleScale` option
- [x] Plot-area data label flags (showCatName/showSerName/showPercent/showLeaderLines/showBubbleSize)
- [x] Axis font + alignment parity (ChartAxis)
- [x] Title rich text parity (Chart title/axis title runs)
- [x] Series fill/marker fill+border parity (ChartSeries/ChartMarker/ChartLine)

### Charts (struct parity next)
- [x] Omit legend element when `legend.position == "none"`
- [x] Legend font parity (`ChartLegend.font` -> `<c:txPr>`)
- [x] Plot-area fill parity (`ChartPlotArea.Fill` solid fill at least)
- [x] Plot-area data table parity (`ShowDataTable` / `ShowDataTableKeys`)
- [x] Data label model parity (`ChartDataLabel` alignment/font/fill)
- [x] Chart border/fill parity (chart-level `<c:spPr>`/`<c:txPr>`)
- [x] OfPie split position (`ChartPlotArea.SecondPlotValues` -> `<c:splitPos>`)

### Rich text (long-tail)
- [x] Rich text run color theme/indexed/tint (`RichTextFont.color_theme/color_indexed/color_tint`)

### Shapes (long-tail)
- [x] Shape macro attribute (`Shape.macro_name` -> `xdr:cNvPr macro="..."`)

## Parity audit (field-level, follow-ups)

These are discovered via `python3 scripts/excelize_struct_field_parity.py` and manual review.

### Pivot tables
- [x] Pivot table definition option attrs (grand totals/drill/autofmt/etc.) + rowItems/colItems parity (partial Excelize `PivotTableOptions`)
- [x] Pivot field options parity (compact/outline/showAll/insertBlankRow/defaultSubtotal + proper `<items>`)

### Sparklines
- [x] Sparkline per-color parity on `SparklineOptions` (negative/markers/first/last/high/low colors) or unify via `SparklineGroupOptions`

### Styles
- [x] Number format long-tail parity (Excelize `Style.DecimalPlaces`, `Style.NegRed`, `Style.CustomNumFmt` vs MoonBit `NumberFormat`)

## Deep parity audit (behavior-level)

These are behavior/interop differences not well-captured by API-name parity or
struct-field parity scripts.

### Pictures / images
- [x] Parse image dimensions for more formats (bmp/tiff/ico) for correct EMU sizing
- [x] Parse SVG dimensions (width/height/viewBox) for correct EMU sizing
- [x] Parse metafile dimensions (emf/wmf) for correct EMU sizing
- [x] Compressed metafiles (emz/wmz): gzip-decompress + sizing parity

### Formula evaluation
- [x] Formula function-name parity vs Excelize (`python3 scripts/excelize_formula_parity.py`)

### Form controls (VML)
- [x] Parse + round-trip basic form controls (macro/cellLink/checked) via `xl/drawings/vmlDrawing*.vml`
- [x] FormControl sizing parity (width/height + anchor calculation)
- [x] FormControl option parity (current/min/max/inc/page/horizontally, etc.)
- [x] FormControl rich text paragraphs parity (`Paragraph` -> VML `<font>` runs)
- [x] FormControl VML presets parity (fill/stroke + common `<x:ClientData>` defaults)

## Next parity audit (long-tail)

These are larger-scope items where Excelize exposes many knobs and mbtexcel may
still be a subset. Tackle one item at a time and add focused tests.

### Drawings / anchors
- [x] Two-cell/absolute anchors compute correct `<xdr:to>` cell (not same-cell with huge offsets) for charts/images/shapes (Excelize uses `twoCellAnchor` for charts by default)

### Charts
- [x] Chart options long-tail parity audit (Excelize `Chart`/`Chart*` options vs mbtexcel chart model)
- [x] Combo charts (basic CatAx/ValAx + optional secondary Y axis) (Excelize `AddChart(..., combo ...*Chart)` / `AddChartSheet(..., combo ...*Chart)`)
- [x] Combo charts (axis-model long-tail): scatter/bubble mixes (basic)
- [x] Combo charts (axis-model long-tail): dateAx/stock mixes and other edge cases

### Styles
- [x] Style model long-tail parity audit (rare font/fill/border/alignment/protection tags and edge cases)
  - [x] Gradient cell fills (`Fill::gradient`, `Fill.typ == "gradient"`, `Fill.shading` 0..16)
  - [x] Gradient conditional fills (dxfs `<dxf><fill><gradientFill .../></fill></dxf>`)
  - [x] Round-trip theme/indexed colors (`xl/theme/theme1.xml`, `xl/styles.xml` `<indexedColors>`)
  - [x] Round-trip `<colors><mruColors>` (read + write preserve)
  - [x] Preserve full theme XML on write (round-trip `xl/theme/theme1.xml` beyond just extracted colors)
  - [x] Round-trip `<styleSheet><extLst>` (read + write preserve)
  - [x] Round-trip `<tableStyles>` default styles (defaultTableStyle/defaultPivotStyle attrs)
