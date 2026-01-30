# xlsx

The core package for reading and writing Microsoft Excel (XLSX) files. This package contains all the main types and functionality for manipulating Excel workbooks.

## Core Types

### Workbook

`Workbook` is the central container that owns all sheets and global state:

- **Sheets**: `sheets : Array[Worksheet]`, `chart_sheets : Array[ChartSheet]`
- **Styles**: `styles : Array[Style]`, `conditional_styles : Array[Style]`
- **Defined names**: `defined_names : Array[DefinedName]`
- **Document properties**: `core_properties`, `app_properties`, `custom_properties`
- **Protection**: `workbook_protection`

### Worksheet

`Worksheet` represents a single sheet and contains:

- **Cells**: `cells : Array[Cell]` with row/column coordinates
- **Merged cells**: `merged_cells : Array[String]`
- **Features**: tables, charts, images, data validations, conditional formats, etc.
- **Layout**: page margins, page layout, header/footer
- **Protection**: `sheet_protection`

### Cell

`Cell` stores cell data:

- `reference : String` - Cell reference like "A1"
- `row : Int`, `col : Int` - 1-indexed coordinates
- `value : String` - Cell value as string
- `value_type : CellValueType` - String, Number, Bool, or Error
- `formula : String?` - Optional formula
- `style_id : Int` - Index into workbook styles

### Style

`Style` defines cell formatting:

- `font : Font?` - Font styling
- `fill : Fill?` - Background fill
- `border : Array[Border]?` - Cell borders
- `alignment : Alignment?` - Text alignment
- `number_format : NumberFormat?` - Number formatting
- `protection : Protection?` - Cell protection

## Basic Usage

### Creating Workbooks

```mbt check
///|
test "create workbook" {
  // Empty workbook
  let wb = Workbook::new()
  inspect(wb.sheets().length(), content="0")

  // Add a sheet
  let sheet = wb.add_sheet("Data")
  inspect(wb.get_sheet_list(), content="[\"Data\"]")
}
```

### Cell Operations

```mbt check
///|
test "cell operations" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Test")

  // Set cell by reference
  sheet.set_cell("A1", "Hello")
  sheet.set_cell("B1", "World")

  // Set cell by row/column (1-indexed)
  sheet.set_cell_rc(2, 1, "Row 2, Col 1")

  // Read cells
  inspect(sheet.get_cell("A1"), content="Some(\"Hello\")")
  inspect(sheet.get_cell_rc(2, 1), content="Some(\"Row 2, Col 1\")")

  // Set typed values
  sheet.set_cell_value("C1", CellValue::Numeric(42.5))
  sheet.set_cell_value("D1", CellValue::Bool(true))
  inspect(sheet.get_cell_value_raw("C1"), content="Some(Numeric(42.5))")
}
```

### Row and Column Operations

```mbt check
///|
test "row and column operations" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Grid")

  // Set entire row (1-indexed)
  sheet.set_row(1, ["A", "B", "C", "D"])

  // Set entire column (1-indexed)
  sheet.set_col(1, ["1", "2", "3"])

  // Read row/column
  inspect(sheet.get_row(1), content="[\"1\", \"B\", \"C\", \"D\"]")
  inspect(sheet.get_col(1), content="[\"1\", \"2\", \"3\"]")

  // Row/column dimensions
  inspect(sheet.max_row(), content="3")
  inspect(sheet.max_col(), content="4")
}
```

### Formulas

```mbt check
///|
test "formulas" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Calc")

  sheet.set_cell("A1", "10")
  sheet.set_cell("A2", "20")
  sheet.set_cell("A3", "30")

  // Formula with cached value
  sheet.set_cell_formula("A4", "SUM(A1:A3)", value="60")
  inspect(sheet.get_cell_formula("A4"), content="Some(\"SUM(A1:A3)\")")

  // Calculate formula
  inspect(wb.calc_cell_value("Calc", "A4"), content="60")

  // Array formula
  let opts = FormulaOpts::array("B1:B3")
  sheet.set_cell_formula_opts("B1", "{A1:A3*2}", opts~, value="20")
}
```

## Styling

### Creating Styles

```mbt check
///|
test "creating styles" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Styled")

  // Create style with font
  let bold_style = Style::font(Font::with_values(bold=true, size=14.0))
  let bold_id = wb.add_style(bold_style)

  // Create style with fill
  let yellow_fill = Style::fill(Fill::solid("FFFF00"))
  let fill_id = wb.add_style(yellow_fill)

  // Combine multiple style elements
  let combined = Style::new()
    .with_font(Font::with_values(bold=true, color="FF0000"))
    .with_fill(Fill::solid("E0E0E0"))
    .with_alignment(Alignment::with_values(horizontal="center", wrap_text=true))
  let combined_id = wb.add_style(combined)

  // Apply style to cell
  sheet.set_cell("A1", "Bold Text")
  sheet.set_cell_style("A1", bold_id)
}
```

### Font Options

```mbt check
///|
test "font options" {
  let font = Font::with_values(
    bold=true,
    italic=true,
    size=12.0,
    color="0000FF", // Blue
    underline="single",
    strike=true,
  )
  inspect(font.bold, content="Some(true)")
  inspect(font.size, content="Some(12)")
}
```

### Fill Options

```mbt check
///|
test "fill options" {
  // Solid fill
  let solid = Fill::solid("FF0000") // Red
  inspect(solid.typ, content="Some(\"pattern\")")

  // Pattern fill
  let pattern = Fill::pattern(pattern=17, color="00FF00")

  // Gradient fill
  let gradient = Fill::gradient("FF0000", "0000FF", shading=1)
}
```

### Border Options

```mbt check
///|
test "border options" {
  // Create borders for all sides
  let borders = [
    Border::with_values("left", color="000000", style=1),
    Border::with_values("right", color="000000", style=1),
    Border::with_values("top", color="000000", style=1),
    Border::with_values("bottom", color="000000", style=2), // Thicker bottom
  ]
  let style = Style::border(borders)
  inspect(style.border.map(fn(b) { b.length() }), content="Some(4)")
}
```

### Number Formats

```mbt check
///|
test "number formats" {
  // Built-in number format (index 2 = "0.00")
  let decimal_style = Style::builtin_number_format(2)

  // Custom number format
  let currency_style = Style::number_format("$#,##0.00")

  // Percentage
  let pct_style = Style::builtin_number_format(10) // "0.00%"
}
```

## Data Validation

```mbt check
///|
test "data validation" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Validation")

  // Dropdown list validation
  sheet.add_data_validation_list("A1:A10", ["Option 1", "Option 2", "Option 3"])

  // Range validation with DataValidation struct
  let dv = DataValidation::new(true) // allow_blank=true
  dv.set_sqref("B1:B10")
  dv.set_range(
    DataValidationFormula::IntValue(1),
    DataValidationFormula::IntValue(100),
    DataValidationType::Whole,
    DataValidationOperator::Between,
  )
  dv.set_error(DataValidationErrorStyle::Stop, "Invalid", "Enter 1-100")
  dv.set_input("Hint", "Enter a number between 1 and 100")
  sheet.add_data_validation(dv)
}
```

## Conditional Formatting

```mbt check
///|
test "conditional formatting" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("CF")

  // Create a style for conditional formatting
  let red_fill = Style::fill(Fill::solid("FF0000"))
  let cf_style_id = wb.new_conditional_style(red_fill)

  // Cell value condition
  let cf = ConditionalFormatOptions::new("cell")
  cf.set_criteria(">")
  cf.set_value("100")
  cf.set_format(Some(cf_style_id))

  sheet.set_conditional_format("A1:A100", [cf])
}
```

## Charts

```mbt check
///|
test "charts" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("ChartData")

  // Add data
  sheet.set_row(1, ["Category", "Value"])
  sheet.set_row(2, ["A", "10"])
  sheet.set_row(3, ["B", "20"])
  sheet.set_row(4, ["C", "30"])

  // Create chart series
  let series = ChartSeries::new(
    "ChartData!$B$2:$B$4", // values
    "ChartData!$A$2:$A$4", // categories
    name="Sales",
  )

  // Create chart options
  let chart = ChartOptions::new(ChartType::Bar)
  chart.series.push(series)
  chart.set_title("Sales by Category")
  chart.set_dimension(ChartDimension::with_values(480, 300))

  // Add chart to sheet
  sheet.add_chart_with_options("E1", chart)
}
```

## Tables

```mbt check
///|
test "tables" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("TableSheet")

  // Add data for table
  sheet.set_row(1, ["Name", "Age", "City"])
  sheet.set_row(2, ["Alice", "30", "NYC"])
  sheet.set_row(3, ["Bob", "25", "LA"])

  // Add table with range reference and column headers
  let table = sheet.add_table(
    "A1:C3", // range reference
    "Table1", // table name
    ["Name", "Age", "City"], // column headers
    display_name="People",
    style_name="TableStyleMedium2",
    show_row_stripes=true,
  )
  inspect(table.name, content="Table1")
}
```

## Merged Cells

```mbt check
///|
test "merged cells" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Merge")

  // Set value first
  sheet.set_cell("A1", "Merged Header")

  // Merge cells
  sheet.merge_cells("A1:D1")

  // Get merged ranges
  inspect(sheet.merged_cells(), content="[\"A1:D1\"]")

  // Unmerge
  sheet.unmerge_cells("A1:D1")
  inspect(sheet.merged_cells(), content="[]")
}
```

## Hyperlinks

```mbt check
///|
test "hyperlinks" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Links")

  // External hyperlink
  sheet.set_cell("A1", "Visit Example")
  sheet.set_cell_hyperlink(
    "A1",
    "https://example.com",
    HyperlinkType::External,
    display="Example Site",
    tooltip="Click to visit",
  )

  // Internal link to another cell
  sheet.set_cell("A2", "Go to Data")
  sheet.set_cell_hyperlink("A2", "Sheet2!A1", HyperlinkType::Location)
}
```

## Sheet Operations

```mbt check
///|
test "sheet operations" {
  let wb = Workbook::new()
  ignore(wb.add_sheet("Sheet1"))
  ignore(wb.add_sheet("Sheet2"))
  ignore(wb.add_sheet("Sheet3"))

  // Get sheet by name
  guard wb.sheet("Sheet1") is Some(s1) else { return }

  // Rename sheet
  wb.set_sheet_name("Sheet1", "Data")
  inspect(wb.get_sheet_list(), content="[\"Data\", \"Sheet2\", \"Sheet3\"]")

  // Hide sheet
  wb.set_sheet_visible("Sheet3", false)
  inspect(wb.get_sheet_visible("Sheet3"), content="false")

  // Delete sheet
  wb.delete_sheet("Sheet2")
  inspect(wb.get_sheet_list(), content="[\"Data\", \"Sheet3\"]")

  // Set active sheet
  wb.set_active_sheet(1)
  inspect(wb.active_sheet_index(), content="1")
}
```

## Row/Column Visibility and Dimensions

```mbt check
///|
test "row column dimensions" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Dims")

  // Set row height
  sheet.set_row_height(1, 30.0)
  inspect(sheet.get_row_height(1), content="Some(30)")

  // Set column width
  sheet.set_col_width(1, 20.0)
  inspect(sheet.get_col_width(1), content="Some(20)")

  // Hide row
  sheet.set_row_visible(2, false)
  inspect(sheet.row_visible(2), content="false")

  // Hide column
  sheet.set_col_visible(3, false)
  inspect(sheet.col_visible(3), content="false")
}
```

## Sheet Protection

```mbt check
///|
test "sheet protection" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Protected")

  // Protect sheet with options
  let opts = SheetProtectionOptions::with_values(
    password="secret",
    format_cells=false, // Prevent formatting
    insert_rows=false, // Prevent inserting rows
    delete_rows=false, // Prevent deleting rows
  )
  sheet.protect_sheet(opts)

  // Check protection
  inspect(sheet.sheet_protection().map(fn(p) { p.sheet }), content="Some(true)")

  // Unprotect
  sheet.unprotect_sheet(password="secret")
}
```

## Page Layout

```mbt check
///|
test "page layout" {
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Print")

  // Set page margins
  let margins = PageLayoutMarginsOptions::with_values(
    top=1.0,
    bottom=1.0,
    left=0.75,
    right=0.75,
    header=0.5,
    footer=0.5,
  )
  sheet.set_page_margins(Some(margins))

  // Set page layout
  let layout = PageLayoutOptions::with_values(
    orientation="landscape",
    size=9, // A4
    fit_to_width=1,
    fit_to_height=0, // Auto
  )
  sheet.set_page_layout(Some(layout))

  // Set header/footer
  let hf = HeaderFooterOptions::with_values(
    odd_header="&C&\"Arial,Bold\"Report Title",
    odd_footer="&LPage &P of &N&R&D",
  )
  sheet.set_header_footer(Some(hf))
}
```

## Streaming API

For large files, use the streaming API to write rows in order:

```mbt check
///|
test "stream writer" {
  let wb = Workbook::new()
  ignore(wb.add_sheet("BigData"))

  // Create stream writer
  let sw = wb.new_stream_writer("BigData")

  // Set column widths (must be before writing rows)
  sw.set_col_width(1, 3, 15.0)

  // Write rows in order
  sw.set_row("A1", ["Header1", "Header2", "Header3"])
  sw.set_row("A2", ["Data1", "Data2", "Data3"])
  sw.set_row("A3", ["More", "Data", "Here"])

  // Merge cells
  sw.merge_cell("D1", "F1")

  // Must flush when done
  sw.flush()
}
```

## Reading Workbooks

```mbt check
///|
test "read workbook" {
  // Create and write a workbook
  let wb = Workbook::new()
  let sheet = wb.add_sheet("Test")
  sheet.set_cell("A1", "Hello")
  sheet.set_cell("A2", "World")
  let bytes = write(wb)

  // Read it back
  let loaded = read(bytes)
  inspect(loaded.get_sheet_list(), content="[\"Test\"]")
  inspect(loaded.get_cell("Test", "A1"), content="Some(\"Hello\")")
  inspect(loaded.get_cell("Test", "A2"), content="Some(\"World\")")
}
```

## Error Handling

All operations that can fail raise `XlsxError`:

```mbt check
///|
test "error handling" {
  let wb = Workbook::new()

  // Try to get non-existent sheet
  let result : Result[Int, Error] = try? wb.get_sheet_index("Missing")
  inspect(
    result,
    content="Ok(-1)",
  )

  // Invalid cell reference
  let sheet = wb.add_sheet("Test")
  let bad_ref : Result[Unit, Error] = try? sheet.set_cell("123", "value")
  guard bad_ref is Err(_) else { return }
}
```

## Cell Reference Utilities

```mbt check
///|
test "cell reference utilities" {
  // Split cell name
  inspect(split_cell_name("AB123"), content="(\"AB\", 123)")

  // Join cell name
  inspect(join_cell_name("AB", 123), content="AB123")

  // Coordinates (1-indexed)
  inspect(cell_name_to_coordinates("C5"), content="(3, 5)")
  inspect(coordinates_to_cell_name(3, 5), content="C5")

  // Absolute references
  inspect(coordinates_to_cell_name(3, 5, abs=true), content="$C$5")

  // Column conversion
  inspect(column_name_to_number("AA"), content="27")
  inspect(column_number_to_name(27), content="AA")
}
```

## Color Utilities

```mbt check
///|
test "color utilities" {
  // RGB to HSL
  let (h, s, l) = rgb_to_hsl(255, 0, 0) // Red
  inspect(h < 1.0, content="true") // Hue near 0

  // HSL to RGB
  let (r, g, b) = hsl_to_rgb(0.0, 1.0, 0.5) // Red
  inspect(r, content="b'\\xFF'") // 255

  // Theme color with tint
  let tinted = theme_color("FF0000", 0.5)
  inspect(tinted.length(), content="8")
}
```

## Defined Names

```mbt check
///|
test "defined names" {
  let wb = Workbook::new()
  ignore(wb.add_sheet("Data"))

  // Create defined name
  let dn = DefinedName::new("SalesRange", "Data!$A$1:$D$100", scope="Data")
  wb.set_defined_name(dn)

  // Get defined names
  let names = wb.get_defined_names()
  inspect(names.length(), content="1")
  inspect(names[0].name, content="SalesRange")
}
```

## Document Properties

```mbt check
///|
test "document properties" {
  let wb = Workbook::new()

  // Set core properties
  let props = CoreProperties::with_values(
    title="Sales Report",
    creator="Finance Team",
    subject="Q4 2024 Sales",
    keywords="sales, quarterly, report",
    description="Quarterly sales report for Q4 2024",
  )
  wb.set_core_properties(props)

  // Read back
  let p = wb.core_properties()
  inspect(p.title, content="Sales Report")
}
```

## API Summary

### Workbook Methods

| Category | Methods |
|----------|---------|
| **Sheets** | `add_sheet`, `delete_sheet`, `copy_sheet`, `sheet`, `sheets`, `get_sheet_list`, `set_sheet_name`, `set_sheet_visible` |
| **Cells** | `get_cell`, `set_cell`, `get_cell_formula`, `set_cell_formula`, `calc_cell_value` |
| **Rows/Cols** | `get_row`, `set_row`, `get_col`, `set_col`, `insert_rows`, `remove_row`, `insert_cols`, `remove_col` |
| **Styles** | `add_style`, `new_style`, `get_style`, `new_conditional_style` |
| **Features** | `add_chart`, `add_table`, `add_data_validation`, `add_pivot_table`, `add_sparkline`, `add_image` |
| **Protection** | `protect_workbook`, `unprotect_workbook`, `protect_sheet`, `unprotect_sheet` |
| **Properties** | `core_properties`, `app_properties`, `custom_properties`, `set_defined_name` |
| **I/O** | `save`, `save_as`, `write_to_buffer` |

### Worksheet Methods

| Category | Methods |
|----------|---------|
| **Cells** | `get_cell`, `set_cell`, `get_cell_rc`, `set_cell_rc`, `set_cell_value`, `set_cell_formula`, `set_cell_style` |
| **Rows/Cols** | `get_row`, `set_row`, `get_col`, `set_col`, `set_row_height`, `set_col_width`, `set_row_visible`, `set_col_visible` |
| **Merge** | `merge_cells`, `unmerge_cells`, `merged_cells` |
| **Features** | `add_chart`, `add_table`, `add_data_validation`, `add_comment`, `add_hyperlink`, `add_image` |
| **Layout** | `set_page_margins`, `set_page_layout`, `set_header_footer`, `set_panes` |
| **Navigation** | `max_row`, `max_col`, `rows`, `cols`, `cells` |
