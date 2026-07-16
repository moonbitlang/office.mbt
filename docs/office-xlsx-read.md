# Unified Office XLSX reads

The `office` executable exposes four read-only XLSX commands over one bounded
workbook projection:

```sh
moon run office/cmd/office -- outline book.xlsx --json
moon run office/cmd/office -- get book.xlsx '/xlsx/sheet[name="Data"]/range[A1:C12]' --json
moon run office/cmd/office -- text book.xlsx --under '/xlsx/sheet[name="Data"]' --json
moon run office/cmd/office -- query book.xlsx 'cell[type=formula]' --under '/xlsx/sheet[name="Data"]' --json
```

The command reads the file once with `moonbitlang/async`, validates the package
format from its OOXML relationships, and passes the same provenance-checked,
bounded archive to the XLSX parser. It does not use C stubs. A `.docx` package
selects the DOCX result contract instead; an extension/content mismatch fails
before either projection is opened.

Run `office help xlsx` for the installed command catalog and
`office help <command> --json` for the declared format variants, inputs,
outputs, and limits.

## Output envelope

`--json` emits exactly one `office.output/1` document. Successful XLSX reads
carry one of these data schemas:

| command | data schema | purpose |
| --- | --- | --- |
| `outline` | `office.xlsx.outline/1` | workbook, worksheet, chart-sheet, used-range, feature-count, and defined-name metadata |
| `get` | `office.xlsx.element/1` | one workbook, sheet, cell, or populated-cell range projection |
| `text` | `office.xlsx.text/1` | path-tagged displayed cell text with pagination |
| `query` | `office.xlsx.query/1` | row-major cell matches for bounded declared predicates |

Human output is terminal-safe and intended for inspection. JSON is the
automation contract.

## Canonical selectors and ordering

The resolver accepts the canonical `office.selector/1` XLSX shapes:

```text
/xlsx/workbook
/xlsx/sheet[name="Data"]
/xlsx/sheet[2]
/xlsx/sheet[name="Data"]/cell[B2]
/xlsx/sheet[name="Data"]/range[A1:C12]
```

Positional sheet input resolves to a stable, name-keyed output path. Cell and
range endpoints are normalized and emitted in uppercase A1 form. Workbook and
named-sheet selectors are reported as stable; cell/range selectors are
snapshot-relative because row or column edits can move their content. A cell
or range cannot descend from a chart sheet.

Whole-workbook scans visit sheets in tab order, then cells in row-major order.
`--under` accepts a workbook, worksheet, cell, or range selector. Chart sheets
remain visible in metadata but contribute no cells to text or query scans.

## `outline`

```text
office outline FILE [--max-elements N] [--max-output-chars N] [--json]
```

The outline includes `/xlsx/workbook`, the active sheet when present, tab-order
sheet summaries, defined names, and the effective limits. Worksheet summaries
report state (`visible`, `hidden`, or `very_hidden`), maximum parsed row and
column, a canonical used-range selector, and counts for merges, tables, charts,
images, pivots, comments, hyperlinks, validations, conditional-format ranges,
and slicers. Chart sheets report their kind, state, and chart count.

## `get`

```text
office get FILE SELECTOR [--max-elements N] [--max-output-chars N] [--json]
```

Workbook and sheet reads return bounded orientation metadata. Cell records can
contain:

- canonical `path`, A1 `reference`, and 1-based `row` and `column`;
- displayed `value`;
- typed `raw` value (`string`, `number`, `bool`, or `error`);
- formula text without a leading `=`; and
- nonzero effective `style_id`.

Cell and range results include a `styles` object keyed by the referenced style
ids. Range reads omit completely blank, unstyled cells while preserving
row-major order. Selecting one blank, unstyled coordinate fails with
`office.xlsx.selector_not_found`; it does not fabricate a cell record.

## `text`

```text
office text FILE [--under SELECTOR] [--offset N] [--limit N]
                 [--max-elements N] [--max-output-chars N] [--json]
```

Each entry contains `{path, stability, text}`. Text is the workbook's displayed
cell value. If a formula has no cached displayed value, text falls back to the
formula prefixed with `=` so an uncached formula is not silently omitted.
`matched_total`, `returned`, `offset`, `limit`, `truncated`, and
`scanned_cells` describe the completed bounded scan exactly.

## `query`

```text
office query FILE [CELL_SELECTOR] [--under SELECTOR]
                  [--offset N] [--limit N]
                  [--max-elements N] [--max-output-chars N] [--json]
```

`CELL_SELECTOR` defaults to `cell`. It is `cell` followed by zero or more
bracketed predicates; all predicates are ANDed:

| predicate | meaning |
| --- | --- |
| `type=formula` | cell has a formula |
| `type=number|string|bool|error` | typed raw value has that kind |
| `formula` | cell has a formula |
| `formula~=TEXT` | formula contains the literal text |
| `text=TEXT` | raw string value equals the literal text |
| `text~=TEXT` | raw string value contains the literal text |
| `value>NUMBER` | numeric raw value comparison; also supports `>=`, `<`, `<=`, `=`, and `!=` |

Examples:

```text
cell[type=formula][formula~=SUM]
cell[type=number][value>=0]
cell[text~=revenue]
```

Regular expressions, arbitrary expressions, locale-sensitive matching, and
the DOCX-only `--kind`, `--text`, `--id`, `--property`, and `--ignore-case`
options are rejected. Literal substring predicates are compiled once and use
guaranteed-linear KMP matching under a command-wide work budget.

## Limits

The principal read limits are:

| resource | default | hard limit |
| --- | ---: | ---: |
| scanned cells (`--max-elements`) | 50,000 | 100,000 effective XLSX ceiling |
| successful stdout characters | 1,048,576 | 4,194,304 |
| text rows per page | 2,000 | 10,000 |
| query matches per page | 100 | 1,000 |
| one cell string/formula | — | 1,048,576 characters |
| aggregate scanned cell strings | — | 16,777,216 characters |
| metadata items | — | 10,000 |
| aggregate metadata strings | — | 8,388,608 characters |
| query selector | — | 4,096 characters |
| query predicates | — | 16 |
| one query predicate value | — | 1,024 characters |
| query predicate work | — | 134,217,728 units |

The shared package boundary additionally caps the input file at 64 MiB, ZIP
entries at 4,096, one inflated entry at 32 MiB, total inflation at 128 MiB,
preserved source bytes at 64 MiB plus the maximum ZIP comment (65,535 bytes),
and one XML part at 16 MiB. Scan rectangles
are preflighted before iteration, and every visited coordinate is charged
again while its snapshot is produced. `--max-output-chars` includes the
successful command's trailing line feed; a failure envelope is independent so
resource exhaustion remains machine-readable.

## Correctable failures

Important stable codes include:

| code | meaning |
| --- | --- |
| `office.xlsx.selector_not_found` | sheet or cell selector does not exist in this snapshot |
| `office.xlsx.selector_format_mismatch` | a `/docx/...` selector was passed to an XLSX read |
| `office.xlsx.unsupported_sheet_kind` | a cell/range selector targeted a chart sheet |
| `office.xlsx.invalid_query` | the cell selector or predicate is invalid |
| `office.xlsx.query_predicate_limit` | more than 16 predicates were supplied |
| `office.xlsx.unsupported_query_options` | DOCX-only query options were supplied for XLSX |
| `office.xlsx.resource_limit` | an explicit package, scan, string, query-work, metadata, or output ceiling was reached |
| `office.xlsx.read_failed` | workbook structure could not be projected consistently |
| `office.selector.*` | canonical selector syntax or shape is invalid |

Package corruption and extension/content mismatch use the shared
`office.invalid_package` and `office.format_mismatch` families.
