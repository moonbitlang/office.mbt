# Architecture (as-is)

This document describes the current (Jan 2026) architecture of `bobzhang/mbtexcel`,
with pointers to the concrete code that implements each piece. It is written as a
“how it works today” reference before larger refactors.

If you are looking for proposed refactors, see `docs/architecture-improvements.md`.

## Repository layout

- `mbtexcel.mbt`
  - Thin “facade” package: exports convenience functions that delegate to `@xlsx`.
- `xlsx/`
  - The core implementation: workbook model + feature APIs + OOXML read/write +
    formula evaluation + encryption helpers (largest package).
- `ooxml/`
  - Small OOXML *package metadata* helpers for writing:
    `[Content_Types].xml` and `.rels` generation.
- `zip/`
  - ZIP container implementation (read/write/deflate/crc32/etc).
- `excelize/`
  - Vendored Go Excelize snapshot used as reference (not a MoonBit package).
- `cmd/main/`
  - Small example CLI.
- `docs/`
  - Porting / parity documents and analysis notes.

## Package dependency graph

At build time, the MoonBit packages relate like this:

```
bobzhang/mbtexcel        (facade)
  -> bobzhang/mbtexcel/xlsx
       -> bobzhang/mbtexcel/ooxml
       -> bobzhang/mbtexcel/zip
```

(`excelize/` is a reference only; it is not part of the MoonBit build.)

## Public entrypoints

There are two layers of “user-facing” API:

1. Root facade package (`bobzhang/mbtexcel`)
   - `new_workbook`, `new_file`, `read`, `write`, `open_file`, etc.
   - Implemented in `mbtexcel.mbt` as thin wrappers around `@xlsx`.

2. Core package (`bobzhang/mbtexcel/xlsx`)
   - Full workbook/worksheet API surface.
   - The generated public interface is in `xlsx/pkg.generated.mbti`.

## Core in-memory model

### `xlsx.Workbook`

Defined in `xlsx/workbook.mbt`.

`Workbook` is the central mutable object; it owns all sheets and global state:

- Sheet inventory
  - `sheets : Array[Worksheet]`
  - `chart_sheets : Array[ChartSheet]`
  - `sheet_order : Array[SheetEntry]`
    - Preserves user-visible ordering across worksheets and chartsheets.
    - `SheetEntry` is an enum of indices into the `sheets` / `chart_sheets`
      arrays (`xlsx/workbook.mbt`).
- Global style and names
  - `styles : Array[Style]` (index is the `style_id` stored on cells)
  - `conditional_styles : Array[Style]`
  - `defined_names : Array[DefinedName]`
- Global document state
  - `core_properties`, `app_properties`, `custom_properties`
  - `workbook_props`, `calc_props`, `workbook_protection`, `active_sheet_index`
  - Theme/color preservation:
    - `theme_xml`, `theme_colors`, `indexed_colors`, `mru_colors_xml`,
      `styles_ext_lst_xml`
- “I/O-ish” state currently stored on `Workbook`
  - `file_path : String?` (used by the writer to select workbook content type)
  - `zip_writer : ((@zip.Archive) -> Bytes raise)?` (override ZIP serialization)
  - `charset_transcoder : ((String, Bytes) -> String raise XlsxError)?`
  - `options : Options` (defaults for IO + formatting)

Important invariants (implicit in the current design):

- `sheet_order` entries must point at valid indices inside `sheets` /
  `chart_sheets`.
- `style_id` values stored on cells must be within `0..styles.length()-1`.
- `active_sheet_index` is an index into `sheet_order` (not an OOXML `sheetId`).

### `xlsx.Worksheet`

Defined in `xlsx/worksheet.mbt`.

`Worksheet` is a “kitchen sink” mutable record that aggregates many Excel
features. Key groups:

- Identity / view
  - `name`, `state : SheetState`
  - `sheet_views : Array[SheetView]`
  - `dimension_ref : String?` (cached dimension if present on read)
- Cell grid
  - `cells : Array[Cell]`
    - Each `Cell` stores both the `row`/`col` coordinates and the canonical `A1`
      reference string.
    - Cells are not globally indexed; many operations scan this array.
  - `row_dimensions : Map[Int, RowDimension]`
  - `col_dimensions : Map[Int, ColDimension]`
  - `merged_cells : Array[String]`
- Feature collections
  - `hyperlinks : Array[Hyperlink]`
  - `tables : Array[Table]`
  - `pivot_tables : Array[PivotTable]`
  - `sparkline_groups : Array[SparklineGroup]`
  - Drawings: `images`, `charts`, `shapes`, `form_controls`, `slicers`,
    plus header/footer images.
- Sheet-level options
  - `auto_filter : AutoFilter?`
  - `page_margins`, `page_layout`, `header_footer`
  - `sheet_protection`, `sheet_props`, `sheet_background`
  - `row_breaks`, `col_breaks`
- Stream-writer coordination
  - `stream_state : StreamState` (see “Stream writer” below)
- OOXML “lossless-ish” preservation points
  - `vml_drawing_xml : String?`, `vml_drawing_hf_xml : String?`
  - `data_validations : Array[String]` (raw `<dataValidation ...>` fragments)
  - `conditional_formats : Array[String]` (raw `<conditionalFormatting ...>` fragments)
  - `x14_data_bars : Map[String, X14DataBarProps]` + `x14_cf_rule_id_counter`

### Typed model vs raw OOXML fragments (hybrid strategy)

The design is intentionally hybrid:

- Many features have *typed APIs* (`DataValidation`, `SparklineGroup`, `Table`,
  `Style`, etc.).
- But some worksheet collections are stored as raw OOXML fragments (`String`),
  then parsed/updated “on demand”.

Example (data validations):

- Storage: `Worksheet.data_validations : Array[String]`
- Typed API:
  - `Worksheet::add_data_validation(dv : DataValidation)` converts to XML and
    stores the fragment (`xlsx/worksheet.mbt`).
  - `Worksheet::get_data_validations()` parses stored XML fragments back to
    `Array[DataValidation]` (`xlsx/worksheet.mbt`).
  - Range edits (delete/duplicate) modify attributes inside the stored XML
    fragments via string rewriting (`xlsx/worksheet.mbt`, helpers like
    `replace_attr_value_in_open_tag`).

This approach is used in a few places to:

- Preserve non-modeled attributes/tags (or at least keep the original fragment).
- Avoid fully modeling a very large OOXML surface area up-front.
- Keep write paths simple: the writer can emit fragments directly.

The same “preserve raw XML when practical” idea exists at workbook scope too:

- `Workbook.theme_xml` preserves the full theme XML on read and re-emits it on
  write (falling back to generated/default theme XML when missing).
- `Workbook.mru_colors_xml` and `Workbook.styles_ext_lst_xml` preserve parts of
  `xl/styles.xml` that are easy to lose in a typed-only model.

## Read pipeline (XLSX -> Workbook)

The primary sync entrypoint is `@xlsx.read` (implemented in `xlsx/read.mbt`),
and the async IO wrappers live in `xlsx/io.mbt` (`open_file`, `open_reader`,
`read_zip_reader`).

The reader is internally split into focused files:

- `xlsx/read_workbook_xml.mbt`: `xl/workbook.xml` parsing
- `xlsx/read_worksheet_xml.mbt`: `xl/worksheets/sheetN.xml` parsing
- `xlsx/read_styles_xfs.mbt`: style/xfs parsing helpers
- `xlsx/read_shared_strings.mbt`: shared strings parsing

High-level steps inside `read_zip_bytes` (`xlsx/read.mbt`):

1. Options and unzip limits
   - `normalize_unzip_limits` (`xlsx/options.mbt`)
   - `@zip.read(bytes)` to get an in-memory `@zip.Archive`
   - `enforce_unzip_limits(archive, options)` to prevent zip bombs

2. XML decoding and optional transcoding
   - `decode_utf8(bytes, transcoder?)`:
     - Detects `<?xml ... encoding="...">` in a small prefix
     - Requires a `charset_transcoder` callback for non-UTF8 encodings

3. Parse workbook-global parts by fixed paths
   - `xl/workbook.xml`:
     - sheets list (`parse_workbook_sheets`)
     - defined names (`parse_defined_names`)
     - active tab (`parse_active_sheet_index`)
     - workbook properties (`parse_workbook_props`)
     - calc properties (`parse_calc_props`)
   - `xl/sharedStrings.xml` (optional)
   - `xl/styles.xml` (optional):
     - styles + conditional styles
     - default font, table style defaults
     - indexed colors, `<mruColors>`, `<extLst>` preservation
   - `xl/theme/theme1.xml` (optional): preserve full XML + parse theme colors
   - `docProps/core.xml`, `docProps/app.xml`, `docProps/custom.xml` (optional)

4. Resolve OOXML relationships
   - Load `xl/_rels/workbook.xml.rels`.
   - Parse relationship targets with helpers from `xlsx/ooxml_rels.mbt` and then
     map `rId..` to actual part paths.
   - For each sheet from `workbook.xml`:
     - Determine whether it is a worksheet or chartsheet by checking which rel
       type contains its `r:id`.
     - Resolve the sheet part path and parse it.

5. Parse each worksheet part
   - `parse_worksheet(sheet_xml, shared_strings, style_count)` extracts:
     - cells, merges, row/col dimensions, views, page layout, protection, etc.
   - Additional parsing stages discover child-part relationship IDs:
     - tables, pivots, drawings, VML, slicers, hyperlinks, pictures, etc.
   - When required, load the per-sheet rels file:
     - `xl/worksheets/_rels/sheetN.xml.rels` (computed by `rels_path_for`)
   - OOXML fragments are preserved in `Worksheet` for several feature areas:
     - data validations (including x14 variants)
     - conditional formats (including x14 variants)
     - VML drawings (where present)

6. Parse chartsheets and other workbook-scoped feature parts similarly.

Encryption note:

- `@xlsx.read_with_password` handles encrypted packages by decrypting first and
  then routing back into the same `read_zip_bytes` pipeline (`xlsx/read.mbt` and
  `xlsx/encryption.mbt`).

## Write pipeline (Workbook -> XLSX)

The primary entrypoint is `@xlsx.write` (`xlsx/write.mbt`).
Async “save to path / writer” helpers are in `xlsx/io.mbt`.

The writer is internally split into focused files:

- `xlsx/write_workbook_xml.mbt`: `xl/workbook.xml` / workbook rels emission
- `xlsx/write_shared_strings.mbt`: shared strings collection + `xl/sharedStrings.xml`

High-level steps inside `write(workbook)` (`xlsx/write.mbt`):

1. Precompute shared structures
   - Shared strings: `collect_shared_strings` scans all sheets and builds:
     - a shared string table
     - a map for plain strings + a map for rich text references
   - Formula cells: `collect_formula_cells` decides whether to write calc chain

2. Build OOXML package metadata
   - Construct `@ooxml.WorkbookManifest` (content types + `.rels`) based on:
     - sheet count
     - presence of shared strings
     - presence of calc chain
   - Choose workbook content type based on:
     - `Workbook.file_path` extension (xlsx/xlsm/xltx/...) when available
     - or `Workbook.vba_project` presence

3. Create an in-memory ZIP `@zip.Archive`
   - Add fixed root parts:
     - `_rels/.rels`
     - `[Content_Types].xml`
     - `xl/_rels/workbook.xml.rels`
   - Add workbook parts:
     - `xl/workbook.xml`
     - per-sheet worksheet XML (and rels)
     - styles/theme/sharedStrings/calcChain as needed
     - doc props
   - Add feature parts and update relationships:
     - tables, pivots, drawings, charts, images, VML, slicers, etc.

4. Lossless-ish preservation during write
   - If `Workbook.theme_xml` is present, emit it directly; otherwise generate a
     theme from `Workbook.theme_colors` or fall back to a built-in default.
   - Emit stored XML fragments from worksheets for some features (e.g.
     data validations and conditional formats).

5. Serialize ZIP archive to bytes
   - Default: `@zip.write(archive)`
   - Optional override: `Workbook.zip_writer(archive)` if configured via
     `Workbook::set_zip_writer`.

6. Optional encryption
   - `@xlsx.write_with_password` wraps the output with `encrypt_package`.

## Stream writer (ordering and “no resort” writes)

The stream writer API exists to support a write pattern where rows are provided
in order, avoiding extra sorting work and preventing incompatible worksheet
mutations while streaming.

- Entry: `Workbook::new_stream_writer(sheet_name)` (`xlsx/workbook.mbt`)
  - Requires the worksheet to be empty and not already in stream mode.
  - Sets `Worksheet.stream_state = Writing`.
- Usage: `StreamWriter::set_row_cells` (`xlsx/stream.mbt`)
  - Appends cells in increasing row order (and increasing col order within a row).
  - Validates `style_id` ranges against the workbook’s `styles`.
- Close: `StreamWriter::flush`
  - Sets `Worksheet.stream_state = Flushed` and closes the writer.
- Guardrails:
  - Many worksheet APIs call `Worksheet::ensure_stream_idle` and will error if a
    stream writer is active (`xlsx/worksheet.mbt`).

Note: this “stream writer” still stores cells in memory (it is not a true
stream-to-disk writer); its main architectural role is ordering + API safety.

## Where cross-cutting utilities live today

Several “generic-ish” helpers are currently spread across large files:

- XML escaping and attribute parsing:
  - `xlsx/xml.mbt` (`escape_xml_text`, `escape_xml_attr`, `attr_value`, ...)
  - `xlsx/ooxml_utils.mbt` (`tag_attributes_in`, `extract_tag_body_from`, ...)
  - `ooxml/xml.mbt` (a second `escape_xml_attr`)
- Relationship parsing and target resolution:
  - `xlsx/ooxml_rels.mbt` (`parse_relationship_targets`, `rels_path_for`, ...)
- OOXML fragment rewriting helpers used by worksheet edits:
  - `xlsx/ooxml_utils.mbt` (`replace_attr_value_in_open_tag`, ...)

One motivation for refactoring is to centralize these so that “OOXML string
plumbing” is consistent and testable in one place.

## Subsystem map (xlsx package)

The `xlsx/` package is organized by feature files rather than subpackages. A
few files act as “hubs”:

- Core model and user-facing APIs
  - `xlsx/workbook_types.mbt`: `Workbook` struct + small shared helpers
  - `xlsx/workbook.mbt`: most workbook-level operations
  - `xlsx/worksheet_types.mbt`: `Worksheet`/`Cell`/drawing structs + accessors
  - `xlsx/worksheet.mbt`: most worksheet-level operations
- OOXML IO
  - `xlsx/read.mbt`: parse ZIP+OOXML into a `Workbook`
  - `xlsx/read_workbook_xml.mbt`: workbook.xml parsing
  - `xlsx/read_worksheet_xml.mbt`: worksheet xml parsing
  - `xlsx/write.mbt`: emit OOXML parts + ZIP from a `Workbook`
  - `xlsx/write_workbook_xml.mbt`: workbook.xml emission
  - `xlsx/write_shared_strings.mbt`: shared strings collection + emission
  - `xlsx/io.mbt`: async IO glue (`open_file`, `save_as`, `write_to`, ...)
- Heavy feature subsystems (large, relatively self-contained)
  - `xlsx/formula_eval_types.mbt`: formula constants + core value/AST types
  - `xlsx/formula_parse.mbt`: formula parsing
  - `xlsx/formula_eval.mbt`: formula evaluation core (expression + range eval)
  - `xlsx/formula_builtins.mbt`: built-in function implementations
  - `xlsx/style.mbt`: style model, style XML read/write, and formatting helpers
  - `xlsx/chart_options.mbt`: typed chart options -> chart OOXML
  - `xlsx/conditional_format.mbt`: conditional formatting model + XML helpers
  - `xlsx/sparkline.mbt`: sparklines model + XML helpers
  - `xlsx/form_control.mbt`: form controls (VML) model + XML helpers
- Container/security helpers
  - `xlsx/encryption.mbt`: OOXML package encryption/decryption orchestration
  - `crypto/`: cryptographic primitives (AES + hashes)
  - `xlsx/base64.mbt`: thin wrappers over `moonbitlang/core/encoding/base64`
    (mapping errors to `XlsxError`)

Because MoonBit allows `Type::method` blocks to live in any file in a package,
methods for `Workbook` / `Worksheet` are distributed across many feature files.
When navigating, file name is usually the best hint for where a specific method
is implemented.
