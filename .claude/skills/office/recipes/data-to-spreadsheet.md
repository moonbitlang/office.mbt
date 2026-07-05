# Recipe: data → spreadsheet

Goal: you have tabular data (in the conversation, a query result, a log, etc.)
and want a real `.xlsx` file.

1. **Write the data as CSV** to a file. Use RFC 4180 quoting: wrap any field
   containing a comma, double-quote, or newline in double-quotes, and double
   embedded quotes (`"` → `""`). The first row is treated as the header by
   `view`.

   ```
   cat > report.csv <<'CSV'
   Region,Revenue,Note
   North,120000,
   "West, Coast",98000,"Q3 ""stretch"" target"
   CSV
   ```

2. **Import it** into a workbook:

   ```
   moon run --target wasm cmd/xlsx -- csv report.csv report.xlsx --sheet Revenue
   ```

3. **Verify** the result — read it back and confirm the round-trip:

   ```
   moon run --target wasm cmd/xlsx -- view report.xlsx
   moon run --target wasm cmd/xlsx -- validate report.xlsx     # expect: valid
   ```

Notes:
- Plain numbers (e.g. `120000`, `98000`, `9.99`) are stored as real numeric
  cells, so a `SUM`/`AVERAGE` over them computes and number formats render in
  Excel. Values that aren't plain numbers — including leading-zero ids like
  `007` — stay text; dates are not inferred.
- `csv` preserves empty cells, quoted fields, and text exactly. Two things
  don't round-trip verbatim: a numeric field comes back by value, not spelling
  (`1.0` → `1`, `0.50` → `0.5`), and a cell you later `--number-format` shows its
  formatted display in `rows` (read the raw value with `get`).
- To append or tweak individual cells afterwards, use `set`:
  `moon run --target wasm cmd/xlsx -- set report.xlsx Revenue D1 Delta`.
