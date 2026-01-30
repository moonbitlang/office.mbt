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
- Streaming API for large files

## Installation

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "bobzhang/mbtexcel": "0.1.1"
  }
}
```

Then add to your package's `moon.pkg.json`:

```json
{
  "import": ["bobzhang/mbtexcel"]
}
```

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
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"hello\")")
  inspect(parsed.get_cell_formula("Sheet1", "B1"), content="Some(\"A1\")")
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
  inspect(
    workbook.get_row("Sheet1", 1),
    content=(
      #|["a", "x", "c"]
    ),
  )
  inspect(workbook.get_col("Sheet1", 2), content="[\"x\", \"y\"]")
}
```

### Cell Reference Utilities

```mbt check
///|
test "cell reference conversion" {
  // Split cell name into column and row
  inspect(split_cell_name("AB123"), content="(\"AB\", 123)")

  // Join column and row into cell name
  inspect(join_cell_name("AB", 123), content="AB123")

  // Convert between cell name and coordinates (1-indexed)
  inspect(cell_name_to_coordinates("B3"), content="(2, 3)")
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
  inspect(
    workbook.get_sheet_list(),
    content="[\"Sales\", \"Expenses\", \"Summary\"]",
  )

  // Access sheet by name
  guard workbook.sheet("Sales") is Some(sales) else { return }
  sales.set_cell("A1", "Revenue")
  inspect(sales.get_cell("A1"), content="Some(\"Revenue\")")
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
  sheet.set_cell_value("B1", @xlsx.CellValue::String("Text"))
  sheet.set_cell_value("B2", @xlsx.CellValue::Numeric(100.5))
  sheet.set_cell_value("B3", @xlsx.CellValue::Bool(true))

  // Read back values
  inspect(sheet.get_cell("A1"), content="Some(\"Hello\")")
  inspect(sheet.get_cell("A2"), content="Some(\"42\")")
  inspect(sheet.get_cell_value_raw("B2"), content="Some(Numeric(100.5))")
  inspect(sheet.get_cell_value_raw("B3"), content="Some(Bool(true))")
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
  inspect(sheet.get_cell_formula("A4"), content="Some(\"SUM(A1:A3)\")")

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
  inspect(sheet.merged_cells(), content="[\"A1:D1\"]")
}
```

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

Use `try?` to convert errors to `Result`:

```mbt nocheck
///|
fn safe_read(bytes : Bytes) -> Result[@xlsx.Workbook, Error] {
  try? @mbtexcel.read(bytes)
}
```

## Package Structure

```
bobzhang/mbtexcel              # Facade package (this package)
  -> bobzhang/mbtexcel/xlsx    # Core implementation
       -> bobzhang/mbtexcel/ooxml  # OOXML metadata helpers
       -> bobzhang/mbtexcel/zip    # ZIP archive handling
       -> bobzhang/mbtexcel/crypto # Cryptographic operations
       -> bobzhang/mbtexcel/base64 # Base64 encoding
```

## License

Apache-2.0
