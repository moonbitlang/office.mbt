# Canonical Office selectors

`office.selector/1` is the format-explicit, parseable address model shared by
the unified Office facade. It describes addresses only. Parsing a selector does
not claim that a command can resolve, query, or mutate the addressed content.

## Grammar

```text
selector      = "/" format "/" segment ("/" segment)*
format        = "docx" | "xlsx"
segment       = name [selection]
selection     = "[" positive-index "]"
              | "[" key "=" json-string "]"
name          = lower-alpha (lower-alpha | digit | "-" | "_")*
key           = lower-alpha (lower-alpha | digit | "-" | "_")*
```

JSON strings are used deliberately: quotes, backslashes, control characters,
slashes, brackets, equals signs, and Unicode round-trip through one familiar
escaping rule. Rendered selectors always use the compact canonical JSON string
form.

DOCX selectors begin with a story segment:

```text
/docx/body/p[1]/r[2]
/docx/header[1]/p[1]
/docx/footer[1]/tbl[1]/tr[2]/tc[1]/p[1]
/docx/footnotes/note[id="7"]/p[1]
/docx/comments/comment[id="review/one]=\"ready\""]
```

`body`, `footnotes`, `endnotes`, and `comments` are unselected story roots.
`header` and `footer` require a 1-based positional selector. Descendant segment
names remain visible in the typed AST so format adapters can validate allowed
child kinds without parsing the path again. DOCX named selectors use the `id`
key; arbitrary XPath predicates, regexes, and expressions are not part of this
grammar.

XLSX selectors address a sheet by stable name or snapshot-relative position,
then optionally end in a typed A1 coordinate:

```text
/xlsx/sheet[name="Data"]/cell[A1]
/xlsx/sheet[name="O'Brien / Q1"]/range[A1:C12]
/xlsx/sheet[2]
```

Cell columns are canonical uppercase `A` through `XFD`; rows are `1` through
`1048576`. Range endpoints are normalized to top-left then bottom-right. `$`
absolute markers, whole-row/whole-column references, formulas, unions, and
cross-sheet formula syntax are intentionally outside selector syntax.

## Stability

Every parsed selector reports one of two address classes:

- `Stable`: it contains only format roots and named keys. For example,
  `/docx/comments/comment[id="7"]` and `/xlsx/sheet[name="Data"]`.
- `SnapshotRelative`: it contains any positional selector or A1 coordinate.
  Inserts, deletes, reordering, or sheet edits can move the addressed content.

The classification describes the address, not the lifetime of the underlying
object: a stable key can still disappear or be renamed.

## Resource limits and diagnostics

Parsing is total and bounded:

- input length: 2048 Unicode scalar values;
- depth: 32 segments after the format root;
- selector count: 32;
- segment/key length: 32 characters;
- positional index width: 9 digits;
- named value length: 256 Unicode scalar values.

Failures use a structured error code, a zero-based Unicode-scalar offset, a
bounded input echo, and a bounded message. Cross-format shapes are rejected by
their explicit root and cannot silently fall through to the other format's
rules. Input and decoded JSON values must contain well-formed UTF-16; isolated
surrogates fail before an AST is created or UTF-8 encoding is attempted.

## Adapter and capability boundary

`selector_from_docx_projection_path` converts the existing `/body/...`,
`/header[n]/...`, and annotation paths emitted by the DOCX tools. The
`selector_for_xlsx_cell` and `selector_for_xlsx_range` helpers quote worksheet
names and validate A1 coordinates. These helpers adapt syntax only: they do not
open a package or establish that an addressed object exists.

Format records in `office help --json` expose the selector schema, root,
examples, and a `syntax-only` status. No selector command is registered until
resolution itself is implemented.
