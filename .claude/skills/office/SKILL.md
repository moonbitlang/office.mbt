---
name: office
description: >-
  Work with non-PowerPoint Office/OOXML documents through this repository's
  unified office CLI: identify, inspect, query, validate, diagnose, preview,
  create, template, comment, batch-edit, dump/replay, or safely inspect raw
  parts in .docx and .xlsx files. Use this for Word and Excel tasks instead of
  python-docx, openpyxl, ExcelJS, pandoc, or LibreOffice. Use the legacy
  format-specific CLIs only for the few workflows the umbrella command does
  not provide: direct CSV import/export, formula calculation, fine-grained
  XLSX formula linting and live batch-capability discovery, fine-grained XLSX
  rendering controls, and DOCX Markdown/style-map/image-extraction conversion.
---

# Office documents through one CLI

Use the unified `office` command for every DOCX/XLSX workflow unless the
legacy-only table below names the exact missing capability.

Run from the repository root:

```
moon run --target wasm office/cmd/office -- help all --json
moon run --target wasm office/cmd/office -- <command> <args...>
```

The WebAssembly target is the default for untrusted documents. It cannot spawn
programs or open network connections, and the unified CLI also applies bounded
package, XML, scan, output, and mutation limits. It can still read or write the
paths supplied to it and consume CPU within those limits. For trusted files,
`--target native` is a faster drop-in.

## Default workflow

1. Discover the unified surface with `office help all --json` or
   `office help <command> --json`. Treat its fingerprinted registry as more
   authoritative than prose. Before authoring an XLSX batch script, also run
   the legacy `xlsx capabilities` fallback below: unified help does not yet
   expose that parser-owned operation and parameter catalog.
2. Run `identify`, then `outline --json` before choosing paths or edits.
3. Inspect only the needed content with `get`, `text`, or `query`. Reuse the
   canonical paths returned by the CLI; do not invent selectors.
4. For mutations, prefer a separate output, run `--dry-run` where supported,
   and inspect the transaction preservation report.
5. Read the result back and run `validate` and `issues`. For any XLSX containing
   formulas, also run the legacy `xlsx lint` fallback below and require its
   `finding_count` to be zero; newly authored formulas have no cached results,
   so unified `issues` and `preview` cannot evaluate them. Lint evaluates
   formula masters but not shared/array slave formulas. Treat those slaves as
   an unresolved residual rather than claiming formula correctness.
6. Generate a `preview` and visually inspect the HTML before delivery.

Every documented command failure exits non-zero, but successful diagnostic
commands can report warnings or formula findings with exit code zero. Inspect
their structured counts and records, not just the exit code.
Ordinary `--json` commands emit one `office.output/1` success/failure envelope.
`dump --json` is the deliberate exception: it emits the replayable
`office.dump/1` document directly.

## Command map

The logical syntax below uses the compiled command name `office`; prepend the
`moon run --target wasm office/cmd/office --` launcher shown above.

| Goal | Command |
| --- | --- |
| Discover formats, commands, fields, limits | `office help [all\|FORMAT\|COMMAND\|FORMAT COMMAND] [--json\|--jsonl]` |
| Verify and identify a package | `office identify FILE [--json]` |
| Map document/workbook structure | `office outline FILE [--max-elements N] [--max-output-chars N] [--json]` |
| Resolve one canonical selector | `office get FILE SELECTOR [limits] [--json]` |
| Extract path-tagged paragraphs/cells | `office text FILE [--under SELECTOR] [--offset N] [--limit N] [limits] [--json]` |
| Search bounded literal predicates | `office query FILE [CELL_SELECTOR] [--under SELECTOR] [DOCX predicates] [pagination/limits] [--json]` |
| Run the exact mutation validation gate | `office validate FILE [--json\|--jsonl]` |
| Report validation plus bounded actionable warnings | `office issues FILE [--json\|--jsonl]` |
| Publish deterministic offline HTML | `office preview FILE --output OUT.html [--overwrite] [--json\|--jsonl]` |
| Create a blank validated file | `office create xlsx OUT.xlsx [--sheet NAME] [--dry-run] [--overwrite] [--json]` or `office create docx OUT.docx [--dry-run] [--overwrite] [--json]` |
| Merge strict placeholders/row regions | `office template FILE DATA.json --out OUT [--dry-run] [--overwrite] [--allow-missing] [--json\|--jsonl]` |
| Add/reply/resolve DOCX comments | `office annotate FILE SCRIPT.json --out OUT.docx [--dry-run] [--overwrite] [--json\|--jsonl]` |
| Mutate an XLSX transactionally | `office batch BOOK.xlsx SCRIPT.json [--out OUT.xlsx] [--dry-run] [--overwrite] [--json]` |
| Author a fresh DOCX from ops | `office batch --format docx OUT.docx SCRIPT.json [--dry-run] [--overwrite] [--json]` |
| Produce a replayable semantic dump | `office dump FILE --json` or streaming `--jsonl` |
| Reconstruct replayable dump content | `office replay DUMP.json --output OUT [--overwrite] [--json\|--jsonl]` |
| Inventory/read OOXML parts | `office raw list FILE [--json]`; `office raw read FILE PART [--json] [--base64\|--output FILE]` |
| Replace one XML part | `office raw replace FILE PART (--xml XML \| --xml-file FILE) [--out FILE] [--dry-run] [--overwrite] [--json]` |
| Edit inside one XML part | `office raw edit FILE PART --path PATH --action ACTION [action arguments] [--namespace PREFIX=URI]... [--all] [--out FILE] [--dry-run] [--overwrite] [--json]` |

`[limits]` abbreviates `--max-elements N --max-output-chars N`. DOCX query
predicates are `--kind`, `--text`, `--id`, repeatable `--property NAME=VALUE`,
and `--ignore-case`. XLSX query uses a quoted cell selector such as
`'cell[type=number][value>0]'`.

## Canonical selectors

Selectors are format-rooted:

```
/docx/body/p[1]
/docx/body/tbl[1]/tr[1]/tc[2]/p[1]
/docx/comments/comment[id="7"]
/xlsx/workbook
/xlsx/sheet[name="Data"]
/xlsx/sheet[name="Data"]/cell[A1]
/xlsx/sheet[name="Data"]/range[A1:C12]
```

Ordinal paths are snapshot-relative. Re-run `outline` or `text` after a
mutation before reusing them.

## Mutation contracts

- `create` is create-new by default; `--overwrite` explicitly replaces an
  existing destination. `--dry-run` validates without publishing.
- XLSX `batch` consumes `xlsx.batch/1`. With no `--out` it rewrites the input
  after all operations pass; prefer `--out` when preserving the source matters.
- DOCX `batch --format docx` consumes `docx.batch/2` (and accepts
  `docx.batch/1`) and only authors a fresh destination. It does not edit an
  existing DOCX and does not accept `--out`.
- `template` never modifies its template. It substitutes non-executable
  `{{key}}` placeholders from flat scalar data and optional marked-row regions
  into a separate output.
- `annotate` is the preservation-safe existing-DOCX mutation surface. It
  consumes `docx.annotation-batch/1` with `comment_add`, `comment_reply`,
  `comment_resolve`, and `comment_unresolve` ops and publishes a separate
  output.
- `raw replace` and `raw edit` are expert fallbacks. Use `--dry-run` and a
  separate `--out`; semantic commands are safer whenever they can express the
  task.
- A preservation report is authoritative. Do not infer preservation from the
  requested operations.
- `dump --json` is the form accepted by `replay`. `dump --jsonl` is a
  streaming inspection form with a terminal digest, not replay input.
- `preview --overwrite` and `replay --overwrite` remove the old destination
  before staging the replacement; a later write failure can leave it absent.
  Use a fresh destination, or make and verify a backup before explicit
  replacement. They do not share the atomic-overwrite guarantee of the
  transaction-backed mutation commands.

Read `docs/agent-json-schemas.md` before authoring any consumed JSON document.
It is normative for `xlsx.batch/1`, `docx.batch/2`,
`office.template.data/1`, `docx.annotation-batch/1`, and `office.dump/1`.

## Further detail

Use `office help all --json` for the live command contract and
`docs/agent-json-schemas.md` for consumed/emitted JSON. The existing
`reference/` and `recipes/` files describe the older format-specific binaries;
consult them only for a legacy-only capability named below. They are not the
command reference for the unified facade.

## Legacy-only fallbacks

Do not start with these. Use them only when the named capability is required:

| Missing from `office` | Legacy command |
| --- | --- |
| Direct CSV import to a new workbook | `moon run --target wasm cmd/xlsx -- csv INPUT.csv OUT.xlsx --sheet Data` |
| Evaluate one formula locally | `moon run --target wasm cmd/xlsx -- calc BOOK.xlsx Sheet1 B4` |
| Recompute and lint formula masters, including formulas with no cached result; shared/array slave formulas are not evaluated | `moon run --target wasm cmd/xlsx -- lint BOOK.xlsx [--sheet Sheet1]` |
| Discover the exact XLSX batch operations, parameters, allowed values, and limits accepted by this build | `moon run --target wasm cmd/xlsx -- capabilities` |
| Export one sheet as generic CSV (LF-delimited records) | `moon run --target wasm cmd/xlsx -- rows BOOK.xlsx --sheet Sheet1` |
| Render a selected or bounded XLSX view, suppress images, or calculate uncached formulas | `moon run --target wasm cmd/xlsx -- html BOOK.xlsx --out OUT.html [--sheet Sheet1] [--max-rows N] [--max-cols N] [--no-images] [--calc]` |
| DOCX to Markdown, custom Mammoth style maps, or extracted-image directories | `moon run --target wasm docx2html/cmd/docx2html -- ...` |

The legacy writers do not share the unified transaction contract. CSV import
truncates an existing output, and XLSX HTML rendering replaces its output.
Use verified-new destination paths unless replacement is explicitly intended.
DOCX conversion truncates output files and writes extracted images
non-transactionally, so use a fresh output directory and publish it only after
the command completes successfully.

The umbrella already covers general HTML preview, read/query, validation,
creation, batch authoring, templating, comments, and raw OOXML access. Do not
route those tasks through the legacy agent CLIs.
