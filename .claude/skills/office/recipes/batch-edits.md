# Recipe: many edits in one pass with `batch`

When you're making more than a couple of changes to a workbook, write them as
one `xlsx.batch/1` script rather than a sequence of `set`/`style`/… commands.
`batch` opens the file once, applies every op in order, and saves once — so it
is faster and, unlike a chain of separate commands, **all-or-nothing**: if any
op fails the file is left exactly as it was.

Run with `moon run --target wasm cmd/xlsx -- batch <file> <script.json>`.

## The script shape

```json
{
  "schema": "xlsx.batch/1",
  "ops": [
    {"op": "<name>", "params": { … }}
  ]
}
```

`op` names mirror the subcommands; `params` are the snake_case arguments:

| op | params |
| --- | --- |
| `set` | `sheet`, `cell`, `value` (string / number / bool / null — JSON types are honored: a number becomes a numeric cell, a string stays text, `null` clears) |
| `formula` | `sheet`, `cell`, `formula` (leading `=` optional) |
| `style` | `sheet`, `range`, `bold?`, `italic?`, `number_format?`, `fill?`, `font_color?`, `align?` |
| `merge` | `sheet`, `range` (a colon range, e.g. `A1:B2`) |
| `width` | `sheet`, `column` (`A` or `A:C`), `width` (number) |
| `freeze` | `sheet`, `cell` |
| `filter` | `sheet`, `range` |
| `add-sheet` | `name` |
| `chart` | `sheet`, `anchor`, `categories`, `values`, `type?`, `name?`, `title?` |

## Habits that pay off

- **Dry-run first.** `--dry-run` parses and applies the whole script in memory
  and writes nothing — it catches a typo'd op, param, or reference before you
  touch the file:

  ```
  moon run --target wasm cmd/xlsx -- batch book.xlsx script.json --dry-run
  # dry-run ok: 8 op(s); book.xlsx not modified
  ```

- **Read the indexed error.** A failure names the 0-based op that failed and
  leaves the file untouched:

  ```
  error: op 3 (style): unknown param 'colour'; book.xlsx not modified
  ```

  Fix that op and re-run — you never end up with a half-applied file.

- **Let JSON types do the typing.** `"value": 42` stores a real numeric cell
  (formulas over it compute, number formats render); `"value": "007"` stays
  text; `"value": null` clears the cell. This is the main reason to prefer
  `batch` `set` over the CLI `set`, which has to guess from a string.

- **Validate at the end.** `validate book.xlsx` confirms the result is a
  well-formed OOXML package.

## Limits

Scripts are capped at 10,000 ops and 1,000,000 aggregate style-expanded cells;
references are validated strictly at parse time; numbers must be finite. The
normative grammar is in `docs/agent-json-schemas.md`.
