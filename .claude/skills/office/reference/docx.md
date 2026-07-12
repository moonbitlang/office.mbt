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
| `outline <file>` | JSON map of the document (`docx.outline/1`): counts, ordered heading list, styles in use, image inventory, header/footer/section map, reader diagnostics. Run this first to orient. |
| `text <file>` | One line per paragraph (body, then headers/footers), each prefixed with the path `get` accepts: `[/body/p[2]] …`, `[/body/tbl[1]/tr[1]/tc[2]/p[1]] …`, `[/header[1]/p[1]] …`. Paths are snapshot-relative — positions shift if the document changes. |
| `get <file> <path> [--json]` | One element by path. Bare: its raw text. `--json`: the structured `docx.element/1` payload (kind, formatting, children). Path errors say what exists (`'/body' has 3 'p' children (wanted index 9)`), so they are self-correcting. |
| `validate <file>` | Portable structural validation (archive + CRCs, content types, relationships, main part). Prints `valid` / one finding per line; **exit code is the gate**. |
| `create <out.docx>` | A minimal blank, schema-valid document. |
| `batch <out.docx> <script.json> [--dry-run]` | **Author a new document** from a `docx.batch/1` op script — headings, styled runs, hyperlinks, images, lists, tables with spans, in one shot. `docx.batch/2` additionally supports `comment` ops and inline foot/endnotes. |
| `annotate <add\|reply\|resolve\|unresolve> <in.docx> <out.docx> …` | **Comment on an EXISTING document** by byte-preserving surgery (see below). |
| `convert <in.docx> [out]` | Same conversion engine as `docx2html` (HTML/Markdown), agent-CLI flavored. |

Read the existing discussion with the same read verbs: `outline` lists each
comment — always `id`, plus `author`/`done`/`parent_id`/`anchored_to` when set
(a comment has no `done` until the document has a `commentsExtended` part).
`parent_id` is the ONLY place the reply→parent link shows. `get <file>
'/comments/comment[@id=0]' --json` returns one comment's metadata, `anchors`,
and `children` — where **`children` are that comment's own body paragraphs**
(`/comments/comment[@id=0]/p[1]`), NOT its replies. A reply is a *separate*
comment: find it in `outline` (it carries `parent_id`) or read it directly
(`get <file> '/comments/comment[@id=1]' --json` → `parent_id`, and empty
`anchors` because replies are anchorless). `get <file> '/body/p[2]' --json`
reports the `comment_ids` covering a paragraph.

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

## Annotating existing documents with `annotate` — the contract

`batch` only creates NEW files. To comment on a document you did **not** author
— one whose full content the lossy reader does not model — use `annotate`.

```
docx annotate add       <in.docx> <out.docx> --at '/body/p[2]' [--to '/body/p[4]'] --text '…' --author NAME [--initials RV] [--date <xsd:dateTime>]
docx annotate add       <in.docx> <out.docx> --at '/body/p[2]' --json envelope.json    # docx.annotate/1 envelope owns ALL metadata; flags rejected
docx annotate reply     <in.docx> <out.docx> --comment 0 --text '…' --author NAME
docx annotate resolve   <in.docx> <out.docx> --comment 0
docx annotate unresolve <in.docx> <out.docx> --comment 0
```

- **Byte-preserving surgery.** Only the comment-related parts change — the
  first comment adds `word/comments.xml` and updates `word/_rels/document.xml.rels`,
  `[Content_Types].xml`, and the marker fragments in `word/document.xml` (later
  replies/resolves also touch `commentsExtended.xml`). Every OTHER pre-existing
  part is left byte-identical (verified: `styles.xml`, other stories, and media
  are untouched). This is what makes it safe on documents the reader cannot
  fully round-trip.
- **Never in place.** Each verb writes a NEW `<out.docx>`; the input is never
  modified. It refuses to overwrite an existing output path.
- **Anchors** (`--at`, `--to`) are BODY-story paragraph paths, ordinal only
  (`/body/p[2]`, or a table-cell paragraph path); `--to` names a range end in
  the same story, not before `--at`.
- **Metadata is branch-exclusive.** Either `--text` + the metadata flags
  (`--author` required, `--initials`/`--date` optional), OR `--json <file>`
  pointing to a `docx.annotate/1` envelope that owns all metadata — mixing the
  two is an error.
- **`--comment <id>`** takes the comment's spelled id (a JSON string in the
  read surface: `"id": "0"` → `--comment 0`). `reply` threads under it
  (anchorless, via `commentsExtended`); `resolve`/`unresolve` flip `w15:done`.
- **Double belt before publishing.** The mutated package is structurally
  validated AND read back (the new comment must reappear anchored where asked)
  before the atomic write; on any failure nothing is written.
- **Fail closed.** Documents carrying annotation sidecars this tool cannot keep
  consistent, or unrepairable annotation state, are refused with an addressed
  error rather than a corrupted result.

The review loop that needs no other tools: `outline` (see the discussion,
including reply→parent `parent_id` links) → `annotate add`/`reply`/`resolve` →
`get '/comments/comment[@id=N]' --json` (read a single comment's metadata,
anchors, and body). Note that reading one comment does NOT show its replies —
use `outline` (or read the reply comment) for thread shape.
`recipes/review-docx.md` walks it end to end.

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

A failed run prints a diagnostic and exits non-zero. Batch-script problems
are always prefixed `error: …` (naming the op); file-level failures are
prefixed with the program name (`docx: …` / `docx2html: …`); other
usage/argument errors keep their parser message (often but not always
`error: …` — e.g. `Unsupported output format: pdf` is bare). The wasm
backend has no stderr, so diagnostics
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
