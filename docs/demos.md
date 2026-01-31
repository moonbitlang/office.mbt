# mbtexcel demos

This repo includes a runnable demo generator that writes real `.xlsx` files.
Open the generated files in Excel / Numbers / LibreOffice to see the results.

## Run

Run all demos (writes `.xlsx` files into `./demos_out/`):

```sh
moon run cmd/demos
```

List available demos:

```sh
moon run cmd/demos -- --list
```

Run a single demo:

```sh
moon run cmd/demos -- dashboard demos_out
moon run cmd/demos -- invoice demos_out
moon run cmd/demos -- pivot_slicer demos_out
moon run cmd/demos -- sparklines demos_out
moon run cmd/demos -- secure demos_out
```

Streaming demo (third arg = row count, default `20000`):

```sh
moon run cmd/demos -- stream_big demos_out 50000
```

Secure demo (third arg = password, default `moonbit`):

```sh
moon run cmd/demos -- secure demos_out mypassword
```

## How the demo runner works

Entry point: `cmd/demos/main.mbt`.

- `main` reads CLI args via `@env.args()` and decides which demo(s) to run.
- Each demo is implemented as a function that returns raw XLSX bytes:
  - `demo_*_bytes() -> Bytes raise @xlsx.XlsxError`
- The runner writes those bytes to disk via `@async/fs.write_file`.

If you want to add your own demo:

1. Create `cmd/demos/demo_mything.mbt` with `pub fn demo_mything_bytes() -> Bytes raise @xlsx.XlsxError`.
2. Add a new match arm in `cmd/demos/main.mbt` to call it and choose the output filename.
3. Optionally extend the smoke test in `cmd/demos/main_test.mbt`.

## Demos (what to look for)

### `dashboard.xlsx`

Source: `cmd/demos/demo_dashboard.mbt`.

Shows a “mini BI dashboard” using:

- **Table** (`Worksheet::add_table`) over `Data!A1:E13`
- **Conditional formatting** (3-color scale) over `Data!E2:E13`
- **Chart** (`Workbook::add_chart_with_options`) on `Dashboard!B5` plotting `Data!E2:E13`
- **Image** (`Workbook::add_image`) + a tiny embedded PNG (`cmd/demos/assets.mbt`)
- **Shape** (`Workbook::add_shape`) for a callout banner
- **Frozen header row** via panes (`Worksheet::set_panes`)

Try tweaking:

- Change the numbers written to `Data!B2:D13` and re-run the demo. The chart ranges will update because they’re formulas/ranges, not hardcoded values.

### `invoice.xlsx`

Source: `cmd/demos/demo_invoice.mbt`.

Shows a template-like sheet:

- **Data validation drop-down** for `F5` (status: Draft/Sent/Paid/Overdue)
- **Formulas** for line totals and subtotal/tax/total
- **Sheet protection** (`Worksheet::protect_sheet`) with a password
- **Header/footer strings** (`Worksheet::set_header_footer`) for printing
- **Basic formatting** (column widths, header row, currency number format)

Try tweaking:

- Open the file and try editing protected cells vs unprotected ones.
- Change quantities/prices and see formulas recalc.

### `pivot_slicer.xlsx`

Source: `cmd/demos/demo_pivot_slicer.mbt`.

Shows higher-level pivot features:

- A data table in `Data`
- A **pivot table** in `Pivot` built from `PivotTableOptions`
- A **slicer** connected to the pivot (`Workbook::add_slicer`)

Try tweaking:

- Add more rows to the `rows` array and expand the pivot source range accordingly.

### `sparklines.xlsx`

Source: `cmd/demos/demo_sparklines.mbt`.

Shows compact “trend” visuals:

- Monthly KPI values in `B:M`
- A **sparkline group** created from `SparklineOptions` into `N2:N5`
- Marker/high/low options + a style preset

Try tweaking:

- Switch between `Line`, `Column`, and `WinLoss` sparklines.

### `stream_big_*.xlsx`

Source: `cmd/demos/demo_stream_big.mbt`.

Shows how to generate large sheets efficiently:

- Uses `Workbook::new_stream_writer("Big")`
- Writes rows with `StreamWriter::set_row` (so you don’t keep all cell data in memory)
- Adds a table at the end and flushes

Notes:

- The smoke test uses only 100 rows; the point is to run it with tens/hundreds of thousands of rows.

### `secure_password.xlsx`

Source: `cmd/demos/demo_secure.mbt`.

Shows workbook encryption:

- Writes an encrypted workbook via `write_with_password`
- Sets core document properties (title/creator/description)

Try tweaking:

- Change the password argument and verify Excel prompts you for it.
