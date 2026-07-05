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
- Values are stored as text (the CLI doesn't infer number/date types).
- `csv` preserves empty cells and quoted fields, so `csv` then `rows` is a
  faithful round-trip.
- To append or tweak individual cells afterwards, use `set`:
  `moon run --target wasm cmd/xlsx -- set report.xlsx Revenue D1 Delta`.
