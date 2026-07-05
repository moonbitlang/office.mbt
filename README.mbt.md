# mbtexcel

A pure MoonBit library for reading and writing Microsoft Excel (XLSX) files. This is a port of the popular Go [excelize](https://github.com/xuri/excelize) library.

## Features

- Create, read, and write XLSX spreadsheets
- Cell value manipulation (strings, numbers, booleans, formulas)
- Cell styling (fonts, colors, borders, alignment, number formats)
- Charts and images
- Data validation and conditional formatting
- Pivot tables and slicers
- Sparklines
- Sheet protection and workbook encryption
- Formula evaluation with 300+ built-in functions
- Typed date/time and duration cells with automatic number formats
- Streaming API for large files
- Embedded cell image reading (WPS `DISPIMG`, rich-value "Place in cell", `IMAGE()`)
- OOXML package validation and a command-line tool

## Installation

Add the dependency to your module:

```sh
moon add bobzhang/mbtexcel
```

Then import it in the `moon.pkg` of the package that uses it:

```
import {
  "bobzhang/mbtexcel",
}
```

Call the library through its default alias `@mbtexcel` (e.g. `@mbtexcel.new_workbook()`).

## Quick Start

### Creating and Reading Workbooks

```mbt check
///|
test "workbook roundtrip" {
  let workbook = new_workbook()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "hello")
  sheet.set_cell_formula("B1", "A1", value="hello")
  let bytes = write(workbook)
  let parsed = read(bytes)
  debug_inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"hello\")")
  debug_inspect(parsed.get_cell_formula("Sheet1", "B1"), content="Some(\"A1\")")
}
```

### Row and Column Helpers

```mbt check
///|
test "row and column helpers" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_row("Sheet1", 1, ["a", "b", "c"])
  workbook.set_col("Sheet1", 2, ["x", "y"])
  debug_inspect(
    workbook.get_row("Sheet1", 1),
    content=(
      #|["a", "x", "c"]
    ),
  )
  debug_inspect(workbook.get_col("Sheet1", 2), content="[\"x\", \"y\"]")
}
```

### Cell Reference Utilities

```mbt check
///|
test "cell reference conversion" {
  // Split cell name into column and row
  debug_inspect(split_cell_name("AB123"), content="(\"AB\", 123)")

  // Join column and row into cell name
  inspect(join_cell_name("AB", 123), content="AB123")

  // Convert between cell name and coordinates (1-indexed)
  debug_inspect(cell_name_to_coordinates("B3"), content="(2, 3)")
  inspect(coordinates_to_cell_name(2, 3), content="B3")

  // Absolute references
  inspect(coordinates_to_cell_name(2, 3, abs=true), content="$B$3")

  // Column name/number conversion
  inspect(column_name_to_number("AB"), content="28")
  inspect(column_number_to_name(28), content="AB")
}
```

### Working with Multiple Sheets

```mbt check
///|
test "multiple sheets" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sales"))
  ignore(workbook.add_sheet("Expenses"))
  ignore(workbook.add_sheet("Summary"))

  // Get list of all sheets
  debug_inspect(
    workbook.get_sheet_list(),
    content="[\"Sales\", \"Expenses\", \"Summary\"]",
  )

  // Access sheet by name
  guard workbook.sheet("Sales") is Some(sales) else { return }
  sales.set_cell("A1", "Revenue")
  debug_inspect(sales.get_cell("A1"), content="Some(\"Revenue\")")
}
```

### Cell Types and Values

```mbt check
///|
test "cell value types" {
  let workbook = new_workbook()
  let sheet = workbook.add_sheet("Data")

  // String values
  sheet.set_cell("A1", "Hello")

  // Numeric values (auto-detected from string)
  sheet.set_cell("A2", "42")
  sheet.set_cell("A3", "3.14159")

  // Using typed CellValue enum for explicit types
  sheet.set_cell_value("B1", String("Text"))
  sheet.set_cell_value("B2", Numeric(100.5))
  sheet.set_cell_value("B3", Bool(true))

  // Read back values
  debug_inspect(sheet.get_cell("A1"), content="Some(\"Hello\")")
  debug_inspect(sheet.get_cell("A2"), content="Some(\"42\")")
  debug_inspect(sheet.get_cell_value_raw("B2"), content="Some(Numeric(100.5))")
  debug_inspect(sheet.get_cell_value_raw("B3"), content="Some(Bool(true))")
}
```

### Formulas

```mbt check
///|
test "formulas" {
  let workbook = new_workbook()
  let sheet = workbook.add_sheet("Calc")

  // Set some values
  sheet.set_cell("A1", "10")
  sheet.set_cell("A2", "20")
  sheet.set_cell("A3", "30")

  // Set formula with cached value
  sheet.set_cell_formula("A4", "SUM(A1:A3)", value="60")

  // Read formula back
  debug_inspect(sheet.get_cell_formula("A4"), content="Some(\"SUM(A1:A3)\")")

  // Calculate formula value
  inspect(workbook.calc_cell_value("Calc", "A4"), content="60")
}
```

### Merged Cells

```mbt check
///|
test "merged cells" {
  let workbook = new_workbook()
  let sheet = workbook.add_sheet("Report")

  // Set value before merging
  sheet.set_cell("A1", "Title")

  // Merge cells A1:D1
  sheet.merge_cells("A1:D1")

  // Get merged cell ranges
  debug_inspect(sheet.merged_cells().to_owned(), content="[\"A1:D1\"]")
}
```

### Styling Cells

```mbt check
///|
test "cell styling" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "1234.5")

  // A style combines a number format with a font, fill, border, etc.
  let style = workbook.new_style(
    @xlsx.Style::builtin_number_format(2) // "0.00"
    .with_font(@xlsx.Font::with_values(bold=true, color="#FF0000")),
  )
  workbook.set_cell_style("Sheet1", "A1", style)
  debug_inspect(
    workbook.get_cell_style("Sheet1", "A1"),
    content="Some(\{style})",
  )
}
```

### Dates and Times

```mbt check
///|
test "typed dates" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))

  // Store a datetime; it is written as an Excel date serial with a default
  // date number format (honoring the workbook's 1900/1904 date system).
  workbook.set_cell_time("Sheet1", "A1", @time.date_time(2024, 7, 3))
  debug_inspect(
    workbook.get_cell("Sheet1", "A1"),
    content=(
      #|Some("45476")
    ),
  )

  // The reverse conversion is available directly.
  inspect(
    time_to_excel_date(@time.date_time(2021, 1, 1, hour=12)),
    content="44197.5",
  )
}
```

### Streaming Large Sheets

For workbooks with many rows, the streaming writer avoids holding every
cell in memory at once.

```mbt check
///|
test "streaming writer" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Big"))
  let stream = workbook.new_stream_writer("Big")
  for r in 1..<=1000 {
    stream.set_row_cells("A\{r}", [
      @xlsx.StreamCell::new("row \{r}"),
      @xlsx.StreamCell::new_value(Numeric(r.to_double())),
    ])
  }
  stream.flush()
  let parsed = read(write(workbook))
  debug_inspect(
    parsed.get_cell("Big", "B1000"),
    content=(
      #|Some("1000")
    ),
  )
}
```

### Password Protection

```mbt check
///|
test "password protection" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Secret"))
  workbook.set_cell("Secret", "A1", "classified")

  let encrypted = write_with_password(workbook, "s3cret")
  let reopened = read_with_password(encrypted, "s3cret")
  debug_inspect(
    reopened.get_cell("Secret", "A1"),
    content=(
      #|Some("classified")
    ),
  )
}
```

### Validating the Output Package

`validate_ooxml_package` runs fast structural checks (content-type
coverage, relationship integrity, required parts, well-formed part
names) — the common causes of Excel's "we found a problem" repair
dialog. An empty result means the package is well-formed.

```mbt check
///|
test "validate output" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "hello")
  debug_inspect(@xlsx.validate_ooxml_package(write(workbook)[:]), content="[]")
}
```

## Command-Line Tool

The repo ships a small CLI (`cmd/xlsx`) for common operations without
writing code:

```sh
moon run cmd/xlsx -- create book.xlsx --sheet Data
moon run cmd/xlsx -- set book.xlsx Data A1 Hello
moon run cmd/xlsx -- get book.xlsx Data A1          # -> Hello
moon run cmd/xlsx -- sheets book.xlsx               # -> Data
moon run cmd/xlsx -- rows book.xlsx                 # CSV of the sheet
moon run cmd/xlsx -- view book.xlsx                 # sheet as an ASCII table
moon run cmd/xlsx -- validate book.xlsx             # -> valid
```

`view` renders a sheet as an ASCII table (first row treated as a header):

```
+-------+-------+
| Name  | Score |
+-------+-------+
| Alice | 90    |
| Bob   | 7     |
+-------+-------+
```

The library and CLI build for the **wasm** backend as well as native and
js (the CLI needs the nightly toolchain for wasm filesystem support):

```sh
moon run --target wasm cmd/xlsx -- view book.xlsx
```

## Demos

This repo includes a runnable demo generator that produces real `.xlsx` files you can open in Excel/Numbers/LibreOffice.

```sh
moon run cmd/demos
```

This writes multiple workbooks into `./demos_out/` (by default). You can also run a single demo:

```sh
moon run cmd/demos -- dashboard demos_out
moon run cmd/demos -- stream_big demos_out 50000
```

Run the demo roundtrip regression gate (local/CI):

```sh
scripts/test_demo_roundtrip.sh
```

Run the combined parity + demo regression gate:

```sh
scripts/test_parity_gates.sh
```

## Parity Commands

For semantic parity and CI wrapper usage details, see:

- `docs/excelize-parity.md`
- `docs/parity-commands.md`

Common commands:

```sh
scripts/test_parity_gates.sh
scripts/test_semantic_parity.sh
scripts/test_semantic_parity_fast.sh
scripts/test_semantic_parity_ultrasmoke.sh
```

See `docs/demos.md` for what each demo generates and how the code is structured.

## API Reference

### Workbook Creation

| Function | Description |
|----------|-------------|
| `new_workbook()` | Create an empty workbook (no sheets) |
| `new_file()` | Create a workbook with one sheet named "Sheet1" |
| `read(bytes)` | Parse XLSX bytes into a workbook |
| `read_with_password(bytes, password)` | Parse encrypted XLSX |
| `open_file(path)` | (async) Open XLSX file from path |

### Workbook Output

| Function | Description |
|----------|-------------|
| `write(workbook)` | Serialize workbook to XLSX bytes |
| `write_with_password(workbook, password)` | Serialize with encryption |
| `encrypt(bytes)` | Encrypt raw XLSX bytes |
| `decrypt(bytes)` | Decrypt encrypted XLSX bytes |

### Cell Reference Utilities

| Function | Description |
|----------|-------------|
| `split_cell_name("A1")` | Returns `("A", 1)` |
| `join_cell_name("A", 1)` | Returns `"A1"` |
| `cell_name_to_coordinates("B3")` | Returns `(2, 3)` (col, row) |
| `coordinates_to_cell_name(2, 3)` | Returns `"B3"` |
| `column_name_to_number("AB")` | Returns `28` |
| `column_number_to_name(28)` | Returns `"AB"` |

### Color Utilities

| Function | Description |
|----------|-------------|
| `rgb_to_hsl(r, g, b)` | Convert RGB to HSL |
| `hsl_to_rgb(h, s, l)` | Convert HSL to RGB |
| `theme_color(base, tint)` | Apply tint to theme color |

### Date Utilities

| Function | Description |
|----------|-------------|
| `excel_date_to_time(serial)` | Convert Excel date serial to `ZonedDateTime` |
| `time_to_excel_date(datetime)` | Convert a `ZonedDateTime` to an Excel date serial |

### Validation

| Function | Description |
|----------|-------------|
| `@xlsx.validate_ooxml_package(bytes)` | Return a list of OOXML package structure problems (empty = valid) |

## Core Types

The main types are available from the `@xlsx` package:

- `@xlsx.Workbook` - The main workbook container
- `@xlsx.Worksheet` - A single worksheet
- `@xlsx.Cell` - Cell data with value, type, formula, and style
- `@xlsx.Style` - Cell styling (font, fill, border, alignment, number format)
- `@xlsx.Options` - Read/write options

For detailed documentation on all types and methods, see the [xlsx package documentation](./xlsx/README.mbt.md).

## Error Handling

All functions that can fail raise `@xlsx.XlsxError`. Common error variants:

- `SheetNotFound` - Referenced sheet does not exist
- `InvalidCellRef` - Invalid cell reference format
- `InvalidSheetName` - Sheet name is invalid or too long
- `EncryptedPackage` - File is encrypted but no password provided
- `InvalidPassword` - Decryption failed with given password

Handle errors with `try`/`catch`:

```mbt nocheck
///|
fn describe(bytes : Bytes) -> String {
  try {
    let workbook = @mbtexcel.read(bytes)
    "loaded \{workbook.get_sheet_list().length()} sheets"
  } catch {
    err => "read failed: \{err}"
  }
}
```

## Package Structure

```
bobzhang/mbtexcel              # Facade package (this package)
  -> bobzhang/mbtexcel/xlsx    # Core implementation
       -> bobzhang/mbtexcel/ooxml  # OOXML metadata helpers
       -> bobzhang/mbtexcel/zip    # ZIP archive handling
       -> bobzhang/mbtexcel/crypto # Cryptographic operations
```

## License

Apache-2.0
