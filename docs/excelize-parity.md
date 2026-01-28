# Excelize parity (mbtexcel)

This repo vendors a snapshot of Excelize in `excelize/` and ports the workbook
logic to MoonBit in `xlsx/`.

## Scope of comparison

- Excelize snapshot: `excelize@37b730a` (see `git -C excelize rev-parse HEAD`)
- mbtexcel snapshot: `mbtexcel@7487cfe` (see `git rev-parse HEAD`)

When I say “parity” below, I mean **end-user features and ergonomics**, not just
“there exists an API method with the same name”.

## TL;DR

- **Method-name parity is very high**: by normalized name, every exported
  Excelize function / `(*File)` method has a corresponding exported MoonBit API
  name (often on `Workbook` / `Worksheet` / `StreamWriter`).
- **Feature parity is not complete**: several Excelize features rely on rich
  option structs (`Style`, `Chart`, `Shape`, `PivotTableOptions`,
  `SparklineOptions`, `SlicerOptions`, …). The current MoonBit port generally
  supports only a **minimal subset** of those options or requires **raw OOXML
  XML strings**.

## Major parity gaps / differences

### 1) Styles are currently “number-format only”

- Excelize exposes a rich cell style model via `Style` / `Font` / `Fill` /
  `Border` / `Alignment` / `Protection` (`excelize/xmlStyles.go`).
- mbtexcel exposes `xlsx.Style` with only `number_format` plus `default_font`
  (`xlsx/style.mbt`).

Impact:
- You can’t programmatically create most rich formatting (borders, fills,
  alignment, font variations, protection flags, …) using the MoonBit API yet.
- Writing a workbook will emit a minimal `xl/styles.xml`, so **round-tripping**
  complex styles from existing workbooks is not guaranteed to preserve details.

### 2) Charts are XML-driven (no high-level chart builder yet)

- Excelize chart creation is driven by the structured `Chart` object and many
  subtypes (`excelize/xmlChart.go`, `excelize/chart.go`).
- mbtexcel currently exposes charts as “raw XML payloads”:
  - `Workbook::add_chart(sheet, cell, xml)` (`xlsx/workbook.mbt`)
  - `Workbook::add_chart_sheet(name, chart_xml)` (`xlsx/workbook.mbt`)
  - `Chart` / `ChartSheet` in MoonBit are essentially wrappers around XML
    strings (`xlsx/pkg.generated.mbti`).

Impact:
- You can still write charts, but you must supply correct XML (or build your own
  higher-level chart builder on top).
- Excelize’s “typed options + validation” is not ported yet.

### 3) Shapes are minimal (no sizing/format/paragraph model)

- Excelize `Shape` includes dimensions, fill/line, rich text paragraph runs,
  and other formatting (`excelize/xmlDrawing.go`).
- mbtexcel `xlsx.Shape` currently includes only:
  `reference`, `shape_type`, `text` (`xlsx/shape.mbt`).

Impact:
- Feature coverage is enough for basic “put a simple shape with text” cases,
  but not the richer formatting supported by Excelize.

### 4) Sparklines: only type + (location, range)

- Excelize supports rich sparkline options like style presets, markers, axis,
  series color, reverse direction, etc via `SparklineOptions`
  (`excelize/sparkline.go`).
- mbtexcel supports only:
  - `SparklineType` (Line/Column/WinLoss)
  - `Sparkline` `(range_ref, location)`
  - grouping via `SparklineGroup` (`xlsx/pkg.generated.mbti`)

Impact:
- You can create sparklines, but not configure the full set of formatting knobs
  Excelize provides.

### 5) Pivot tables: XML-driven (no `PivotTableOptions` builder)

- Excelize can generate pivot table XML from `PivotTableOptions`
  (`excelize/pivotTable.go`).
- mbtexcel exposes pivot tables primarily as XML strings:
  `Workbook::add_pivot_table(_xml)` takes `table_xml`, `cache_definition_xml`,
  and optional `cache_records_xml` (`xlsx/pkg.generated.mbti`).

Impact:
- You can add pivot tables if you already have the XML (or you build a higher
  level pivot generator), but you don’t have Excelize’s option struct parity.

### 6) Slicers: XML-driven / minimal options

- Excelize exposes `SlicerOptions` and builds slicer cache/list parts
  (`excelize/slicer.go`).
- mbtexcel currently exposes a minimal `Slicer` type (`xlsx/pkg.generated.mbti`)
  and sheet-level insertion APIs.

Impact:
- Basic slicer attachment is possible, but Excelize’s slicer option model is
  not ported.

### 7) Tables: subset of Excelize’s `Table` fields

- Excelize `Table` includes many flags like first/last column emphasis, row/col
  stripes, and additional behaviors (`excelize/xmlTable.go`, `excelize/table.go`).
- mbtexcel `xlsx.Table` currently captures core identity and layout only:
  `name`, `display_name`, `range_ref`, `columns`, `style_name`
  (`xlsx/pkg.generated.mbti`).

Impact:
- Creating tables works for core cases, but advanced formatting/flags are not
  fully configurable.

### 8) Pictures: subset of `GraphicOptions`

- Excelize picture insertion uses `GraphicOptions` (alt text, name, lock aspect
  ratio, positioning modes, print/locked, etc.) (`excelize/xmlDrawing.go`).
- mbtexcel picture APIs currently focus on: offset/scale + hyperlink
  (`xlsx/worksheet.mbt`).

Impact:
- Image insertion is in good shape for “place over cells” flows, but advanced
  drawing properties are not as configurable as Excelize.

### 9) Rich text font model is smaller than Excelize’s `Font`

- Excelize rich text runs reference the full `Font` type with many attributes
  (strike, shadow, vertAlign, etc.) (`excelize/xmlSharedStrings.go`).
- mbtexcel rich text uses `RichTextFont` with a smaller subset
  (`xlsx/pkg.generated.mbti`).

Impact:
- Basic rich text works; not all font decorations map 1:1 yet.

## Notes / intentional differences

- **Async I/O**: some APIs are `async` in MoonBit (e.g. file I/O, writing to a
  writer). Excelize is synchronous.
- **Formula evaluation**: both projects have formula evaluation APIs, but exact
  supported function coverage and edge-case behavior may differ (this hasn’t
  been exhaustively parity-audited here).

## How to keep this doc up to date

1. Identify Excelize features that are “option-struct driven” (usually the
   biggest parity gaps early in a port).
2. For each feature, decide whether mbtexcel should:
   - port the same option model, or
   - expose “raw OOXML XML” and keep the API thin.

For a mechanically-generated, “names-only” view, see
`docs/excelize-parity-generated.md` (regenerate with
`python3 scripts/excelize_parity_report.py --out docs/excelize-parity-generated.md`).
