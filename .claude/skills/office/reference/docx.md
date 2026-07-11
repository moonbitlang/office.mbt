# Reference: Word documents — `docx` (read/author) and `docx2html` (convert)

Two binaries share the Word toolchain, both run from the repo root:

- **`docx2html/cmd/docx`** — the agent CLI: inspect structure, extract text,
  read elements as JSON, validate, and **author new documents** from JSON op
  scripts. This is the tool for programmatic reading and writing.
- **`docx2html/cmd/docx2html`** — the converter (a Mammoth port): DOCX → HTML
  or Markdown, with style maps and image extraction.

```
moon run --target wasm docx2html/cmd/docx -- <subcommand> [args...]
moon run --target wasm docx2html/cmd/docx2html -- [options] <input.docx> [output]
```

## `docx` subcommands

| Subcommand | What it does |
| --- | --- |
| `outline <file>` | JSON map of the document (`docx.outline/1`): counts, heading tree, styles in use, image inventory, header/footer/section map, reader diagnostics. Run this first to orient. |
| `text <file>` | One line per paragraph (body, then headers/footers), each prefixed with the stable path `get` accepts: `[/body/p[2]] …`, `[/body/tbl[1]/tr[1]/tc[2]/p[1]] …`, `[/header[1]/p[1]] …`. |
| `get <file> <path> [--json]` | One element by path. Bare: its raw text. `--json`: the structured `docx.element/1` payload (kind, formatting, children). Path errors say what exists (`'/body' has 3 'p' children (wanted index 9)`), so they are self-correcting. |
| `validate <file>` | Portable structural validation (archive + CRCs, content types, relationships, main part). Prints `valid` / one finding per line; **exit code is the gate**. |
| `create <out.docx>` | A minimal blank, schema-valid document. |
| `batch <out.docx> <script.json> [--dry-run]` | **Author a new document** from a `docx.batch/1` op script — headings, styled runs, hyperlinks, images, lists, tables with spans, in one shot. |
| `convert <in.docx> [out]` | Same conversion engine as `docx2html` (HTML/Markdown), agent-CLI flavored. |

The normative spec for every JSON payload (`docx.outline/1`, `docx.element/1`,
`docx.batch/1`) is **`docs/agent-json-schemas.md`** — read it before writing a
batch script. The executable examples live in
`docx2html/tests/cram/docx-agent.md`.

## Authoring with `batch` — the contract

- **Strict input.** Unknown keys, unknown enum values, duplicate JSON keys,
  and wrong value types are errors naming the exact op (`ops[3].params.style
  'Heading7' is unknown`). Numbers must be plain decimal integers — `2.9` and
  `1e2` are rejected, never coerced.
- **Fresh documents only.** The output path must not exist; batch creates
  documents, it does not edit them (the reader is lossy, so in-place editing
  would silently drop unmodeled parts).
- **All-or-nothing.** The whole script builds and validates before anything
  touches disk; the write is atomic (unique temp + no-replace rename).
  `--dry-run` runs the entire pipeline without writing.
- **Ops**: `paragraph` (exactly one of `text`/`runs`; `style`
  `Normal|Heading1..6`; `align`; `list {ordered, level 1–9}`) and `table`
  (`rows[][]` of cells, `col_span` 1–63, `row_span` up to the remaining rows,
  `header_rows`). Run specs carry the writer's full formatting surface;
  `link` is `href` XOR `anchor`; `image` paths resolve relative to the
  current directory (PNG/JPEG/GIF).
- **Write→read key asymmetry** to remember when verifying your own output:
  batch says `strike`/`vertical`, `docx.element/1` reads back
  `strikethrough`/`vertical_alignment`.
- Anything the writer cannot represent faithfully **fails closed** with an
  addressed error rather than emitting a lossy document.

A verify loop that needs no other tools: `batch` → `validate` → `text` (or
`get --json`) and compare against your script's intent.

## `docx2html` (converter) options

```
Usage: docx2html [options] <input> [output]

Options:
  -h, --help                       Show help information.
  --pretty-print                   Pretty-print generated HTML.
  --style-map <style-map>          Read Mammoth style-map lines from a file.
  --output-format <output-format>  Output format: html or markdown. [default: html]
  --output-dir <output-dir>        Write converted output and extracted images into a directory.
```

- **Output destination.** With no `output` and no `--output-dir`, the result
  goes to **stdout**. With an `output` path, it's written there. `--output-dir`
  writes `<input-basename>.html` (or `.md`) *and* the extracted images into that
  directory, creating the directory if it doesn't exist. `output` and
  `--output-dir` are mutually exclusive.
- **Images.** By default images are inlined as base64 `data:` URIs (so a single
  HTML/Markdown file is self-contained). With `--output-dir`, images are
  extracted to files (`1.png`, `2.png`, …) and referenced by name.
- **`--output-format`** is `html` (default) or `markdown`; any other value is an
  error.
- **`--style-map`** points to a file of Mammoth style-map lines (e.g.
  `p[style-name='Heading 1'] => h1:fresh`), letting you remap Word styles to
  HTML/Markdown elements.
- **`--pretty-print`** indents generated HTML (no effect on Markdown).

## Diagnostics (both binaries)

A failed run prints a diagnostic and exits non-zero. Script/usage problems are
prefixed `error: …`; file-level failures are prefixed with the program name
(`docx: …` / `docx2html: …`). The wasm backend has no stderr, so diagnostics
arrive on stdout — always check the exit code. `docx2html` conversion warnings
print only when output went to a file, never into piped output.

## Examples

```
# orient, then read one paragraph as JSON
moon run --target wasm docx2html/cmd/docx -- outline report.docx
moon run --target wasm docx2html/cmd/docx -- get report.docx '/body/p[2]' --json

# author a document from an op script, then prove it round-trips
moon run --target wasm docx2html/cmd/docx -- batch out.docx script.json
moon run --target wasm docx2html/cmd/docx -- validate out.docx
moon run --target wasm docx2html/cmd/docx -- text out.docx

# convert to Markdown (stdout)
moon run --target wasm docx2html/cmd/docx2html -- --output-format=markdown report.docx

# convert to a directory, extracting images as separate files
moon run --target wasm docx2html/cmd/docx2html -- --output-dir ./out report.docx
```
