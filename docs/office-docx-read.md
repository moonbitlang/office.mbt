# Unified Office DOCX reads

The `office` executable exposes four read-only DOCX commands over one bounded,
canonical document projection:

```sh
moon run office/cmd/office -- outline report.docx --json
moon run office/cmd/office -- get report.docx '/docx/body/p[1]' --json
moon run office/cmd/office -- text report.docx --under '/docx/header[1]' --json
moon run office/cmd/office -- query report.docx --kind paragraph --text revenue --ignore-case --json
```

Run `office help docx` for the installed command catalog and
`office help <command> --json` for the declared inputs, outputs, and bounds.
These commands accept DOCX packages only. Passing an XLSX package fails with
`office.unsupported_operation`; XLSX selector resolution remains a later
milestone.

## Output envelope

`--json` always emits one `office.output/1` document. A successful response
has `success: true` and a versioned object in `data`; bounded projection
diagnostics appear in the optional top-level `warnings` array. A failure has
`success: false`, a stable `error.code`, a bounded message, and optional
bounded details. Failures exit non-zero.

The four data schemas are:

| command | data schema | purpose |
| --- | --- | --- |
| `outline` | `office.docx.outline/1` | structural counts, story roots, headings, styles, images, sections, diagnostics |
| `get` | `office.docx.element/1` | one resolved story, annotation item, or addressable element |
| `text` | `office.docx.text/1` | path-tagged paragraph text with pagination |
| `query` | `office.docx.query/1` | deterministic matches for declared predicates |

Human output is intended for terminals. JSON is the automation contract.

## Canonical projection

Projection order is deterministic:

1. body;
2. headers in reader part order;
3. footers in reader part order;
4. footnotes;
5. endnotes; and
6. comments.

Each story is walked in document order. Addressable kinds are `p`, `r`, `tbl`,
`tr`, `tc`, `hyperlink`, and `image`; text nodes, tabs, breaks, bookmarks, and
reference markers are read through their nearest addressable parent. Nested
table content keeps its complete ancestry, for example:

```text
/docx/body/tbl[1]/tr[2]/tc[1]/p[1]
```

The body and annotation collection roots exist even when empty. Header and
footer roots exist only for discovered parts. See
[office-selectors.md](office-selectors.md) for the complete selector grammar.

Unique, non-empty note and comment ids that fit the selector bounds use stable
paths:

```text
/docx/footnotes/note[id="7"]
/docx/comments/comment[id="review/one]=\"ready\""]
```

A missing, duplicated, or unrepresentable annotation id falls back to a
snapshot-relative positional path and produces a warning. Selecting a
duplicated id is an explicit `office.docx.selector_ambiguous_id` failure.
Descendants such as `.../comment[id="7"]/p[1]` are snapshot-relative because
they contain a positional segment.

## `outline`

```text
office outline FILE [--max-elements N] [--max-output-chars N] [--json]
```

`office.docx.outline/1` contains:

- `file`, `format`, and `scanned_elements`;
- `counts` for body stories, headers, footers, note definitions, comments,
  paragraphs, runs, tables, rows, cells, hyperlinks, and images;
- `stories`, each with its canonical path, kind, direct-child count,
  stability, and source information;
- bounded heading previews and first-use-deduplicated styles;
- image metadata without embedded image bytes;
- the effective section header/footer references; and
- bounded reader diagnostics.

It is an orientation command: use `get`, `text`, or `query` for content.

## `get`

```text
office get FILE SELECTOR [--max-elements N] [--max-output-chars N] [--json]
```

`office.docx.element/1` echoes the canonical `path` and reports `kind`, `role`,
`stability`, `source`, optional `parent` and stable `id`, direct `children`,
kind-specific `properties`, annotation `metadata`, and bounded raw `text`.

Paragraph/run formatting, table spans, hyperlink targets, and image metadata
are represented as typed JSON properties. Comment metadata can include author,
initials, lexical date, resolved state, parent id, and canonicalized anchors.
Notes include canonical reference locations.

## `text`

```text
office text FILE [--under SELECTOR] [--offset N] [--limit N]
                 [--max-elements N] [--max-output-chars N] [--json]
```

Only paragraph elements are returned. Each entry has `path`, `stability`, and
raw `text`. `--under` restricts the scan to a resolved selector subtree.
`matched_total` is the exact paragraph count for the completed bounded scan;
`returned`, `offset`, `limit`, and `truncated` make pagination explicit.

## `query`

```text
office query FILE [--under SELECTOR] [--kind KIND] [--text TEXT] [--id ID]
                  [--property NAME=VALUE]... [--ignore-case]
                  [--offset N] [--limit N]
                  [--max-elements N] [--max-output-chars N] [--json]
```

All supplied predicates are ANDed. Matching is literal and deterministic;
regular expressions and arbitrary expressions are never evaluated.

Kinds are the story and element names above. The readable aliases are
`paragraph`, `run`, `table`, `row`, `cell`, `link`, and `picture`.

The declared property set is:

| property | applies to |
| --- | --- |
| `style_id`, `style_name` | paragraphs, runs, tables |
| `alignment` | paragraphs |
| `bold`, `italic`, `underline` | runs; values are `true` or `false` |
| `content_type` | images |
| `href` | hyperlinks |
| `author`, `done` | comments; `done` is `true` or `false` |

Hyphenated aliases (`style-id`, `style-name`, `content-type`) plus `align`,
`url`, and `resolved` normalize to those names. `--ignore-case` applies only
to `--text`. Results carry a bounded text preview, declared properties,
canonical identity, exact `matched_total`, and explicit pagination metadata.

## Limits

The implementation uses `moonbitlang/async` for bounded file I/O and has no C
stub. Default and hard user-facing limits are:

| resource | default | hard limit |
| --- | ---: | ---: |
| projection elements | 50,000 | 200,000 |
| serialized output characters | 1,048,576 | 4,194,304 |
| text rows per page | 2,000 | 10,000 |
| query matches per page | 100 | 1,000 |
| property predicates | — | 16 |

The package reader additionally caps the input file at 64 MiB, ZIP entries at
4,096, one inflated entry at 32 MiB, total inflated bytes at 128 MiB, and uses
cumulative XML source, token, materialization, and token-size budgets during
both structural OPC preflight and document projection. Reader diagnostics are
deduplicated in first-seen order, capped at 128 retained entries, and bounded
to 512 characters each. Query text scanning is capped cumulatively at 16 Mi
characters, and one element's materialized text at 1 Mi characters. Limit
failures use `office.docx.resource_limit` and identify the exhausted resource.

## Correctable failures

Important stable codes include:

| code | meaning |
| --- | --- |
| `office.docx.selector_not_found` | canonical selector does not exist in this snapshot |
| `office.docx.selector_ambiguous_id` | annotation id appears more than once |
| `office.docx.unsupported_stable_id` | `id=` was used on a kind other than note/comment |
| `office.docx.selector_format_mismatch` | an XLSX-shaped selector was passed to a DOCX read |
| `office.selector.*` | selector syntax or shape is invalid |
| `office.docx.invalid_query_kind` | unknown `--kind` value |
| `office.docx.invalid_query_property` | unknown or ill-typed property predicate |
| `office.docx.resource_limit` | an explicit package, scan, text, or output ceiling was reached |
| `office.invalid_package` / `office.docx.read_failed` | the package or DOCX graph cannot be read safely |

After any mutation, rerun `outline` or `query` before reusing a positional
selector. Stable annotation ids can still disappear, but they do not silently
retarget another item.
