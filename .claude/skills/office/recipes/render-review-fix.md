# Recipe: build a spreadsheet you can *see* and correct

The agent commands close a loop: **inspect → edit → render → look → fix**. You
never have to guess what a workbook contains or what your edit produced — you
read it back as JSON and look at it as HTML.

All commands below run with `moon run --target wasm cmd/xlsx -- …` (drop
`--target wasm` for `--target native` on trusted files).

## 1. Build in one shot with `batch`

Write the whole sheet as one `xlsx.batch/1` script instead of N separate
commands — it opens, applies every op, and saves once (atomically; a failing
op leaves the file untouched):

```
cat > build.json <<'JSON'
{"schema": "xlsx.batch/1", "ops": [
  {"op": "set",     "params": {"sheet": "Data", "cell": "A1", "value": "Region"}},
  {"op": "set",     "params": {"sheet": "Data", "cell": "B1", "value": "Sales"}},
  {"op": "set",     "params": {"sheet": "Data", "cell": "A2", "value": "East"}},
  {"op": "set",     "params": {"sheet": "Data", "cell": "B2", "value": 1200}},
  {"op": "formula", "params": {"sheet": "Data", "cell": "B4", "formula": "=SUM(B2:B3)"}},
  {"op": "style",   "params": {"sheet": "Data", "range": "A1:B1", "bold": true, "fill": "4472C4", "font_color": "FFFFFF", "align": "center"}},
  {"op": "freeze",  "params": {"sheet": "Data", "cell": "A2"}}
]}
JSON
moon run --target wasm cmd/xlsx -- create report.xlsx --sheet Data
moon run --target wasm cmd/xlsx -- batch report.xlsx build.json
```

Dry-run first (`--dry-run`) if you want to validate the script without writing.

## 2. Look at the result — `html`

Render the workbook to a self-contained HTML file and open it (or screenshot
it). This shows the real formatting: fonts, fills, merges, widths, images,
chart placeholders, frozen panes.

```
moon run --target wasm cmd/xlsx -- html report.xlsx --out report.html
```

A formula with no cached result shows as its text, marked pending — pass
`--calc` to evaluate and render the number instead:

```
moon run --target wasm cmd/xlsx -- html report.xlsx --calc --out report.html
```

## 3. Spot-check the data — `get … --json` and `outline`

`outline` maps the whole workbook (sheets, used ranges, charts, images,
counts) without materializing cells; `get … --json` reads a range with typed
values, formulas, and the styles actually applied:

```
moon run --target wasm cmd/xlsx -- outline report.xlsx
moon run --target wasm cmd/xlsx -- get report.xlsx Data A1:B4 --json
```

`get --json` reports the **effective** style id (cell → row → column), so you
can confirm an inherited number format or fill is really in force.

## 4. Fix and re-render

Found a problem? Apply a small correcting `batch` script and render again —
the same loop, tightened:

```
cat > fix.json <<'JSON'
{"schema": "xlsx.batch/1", "ops": [
  {"op": "style", "params": {"sheet": "Data", "range": "B2:B4", "number_format": "#,##0"}}
]}
JSON
moon run --target wasm cmd/xlsx -- batch report.xlsx fix.json
moon run --target wasm cmd/xlsx -- html report.xlsx --out report.html
moon run --target wasm cmd/xlsx -- validate report.xlsx
```

End every editing session with `validate` — it confirms the file is a
well-formed OOXML package (no "we found a problem" repair dialog).

## Notes

- `html` never modifies its input; `--out` refuses the input path and writes
  atomically. See `reference/xlsx.md` for the full flag set and fidelity
  limits (theme/indexed colors and gradients are omitted, not guessed).
- The JSON schemas are versioned. The payloads the tool *produces*
  (`outline`, `get --json`) evolve additive-only; the scripts it *consumes*
  (`batch`) are validated strictly (unknown keys are errors). The normative
  spec is `docs/agent-json-schemas.md`.
