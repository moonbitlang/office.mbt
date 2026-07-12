---
name: office
description: >-
  Work with Office/OOXML documents — Excel .xlsx spreadsheets and Word .docx
  files — by running this repo's CLIs on the WebAssembly backend, a
  memory-safe sandbox with no native document libraries. Use it to generate a
  spreadsheet or Word document, turn CSV/table data into .xlsx, author a
  .docx (headings, styled text, links, images, lists, tables) from a JSON op
  script, read a document's structure/text/elements as JSON, convert a .docx
  to HTML or Markdown, extract images, or check that a file is structurally
  valid. Reach for this instead of openpyxl / ExcelJS / python-docx / pandoc
  / LibreOffice.
---

# office — documents via the WebAssembly sandbox

This toolkit compiles to **WebAssembly** and runs on MoonBit's own runtime, so
every operation happens inside a memory-safe sandbox: the code cannot execute
other programs or open network connections — its only effects are reading and
writing the files you point it at. That makes it the right place to open a
document you don't fully trust. (It is *not* a resource sandbox: a hostile file
can still burn CPU or memory, and the tool touches whatever paths you pass.)

Run everything from the repository root with this one pattern:

```
moon run --target wasm <tool> -- <args...>
```

- `<tool>` is `cmd/xlsx` (spreadsheets), `docx2html/cmd/docx` (read, inspect,
  validate, and author Word docs), or `docx2html/cmd/docx2html` (convert Word
  docs to HTML/Markdown).
- The first run builds the wasm module (a few seconds); later runs are fast.
- For trusted files where speed matters, swap `--target wasm` for
  `--target native`.

### Run anywhere (no repo, no build toolchain)

`moon run` is just the in-repo convenience — build + run. The compiled `.wasm`
is portable: ship it alongside `moonrun` (MoonBit's WebAssembly runtime, which
supports the async I/O these tools use out of the box) and run it directly on
any platform `moonrun` targets, with no repo and no build step:

```
moon build --target wasm cmd/xlsx                 # once, produces xlsx.wasm
moonrun path/to/xlsx.wasm create book.xlsx --sheet Data   # anywhere
```

So this is genuinely cross-platform: a ~1 MB `.wasm` plus the `moonrun` binary,
not a Python/LibreOffice install.

## I want to… → run this

Every command starts with `moon run --target wasm` (written in full below so each
row is copy-pasteable):

| Goal | Command |
| --- | --- |
| Turn a CSV / table into a spreadsheet | `moon run --target wasm cmd/xlsx -- csv data.csv out.xlsx` |
| Create an empty workbook | `moon run --target wasm cmd/xlsx -- create out.xlsx --sheet Data` |
| Set a cell | `moon run --target wasm cmd/xlsx -- set f.xlsx Sheet1 A1 hi` |
| Set a formula | `moon run --target wasm cmd/xlsx -- formula f.xlsx Sheet1 B4 "=SUM(B1:B3)"` |
| Compute a formula's value | `moon run --target wasm cmd/xlsx -- calc f.xlsx Sheet1 B4` |
| Style a cell/range | `moon run --target wasm cmd/xlsx -- style f.xlsx Sheet1 A1:B1 --bold --fill 4472C4 --font-color FFFFFF` |
| Merge cells | `moon run --target wasm cmd/xlsx -- merge f.xlsx Sheet1 A1:C1` |
| Set column width(s) | `moon run --target wasm cmd/xlsx -- width f.xlsx Sheet1 A:C 16` |
| Freeze the header row | `moon run --target wasm cmd/xlsx -- freeze f.xlsx Sheet1 A2` |
| Add a filter to a range | `moon run --target wasm cmd/xlsx -- filter f.xlsx Sheet1 A1:C10` |
| Add a chart from data | `moon run --target wasm cmd/xlsx -- chart f.xlsx Sheet1 E2 --type col --categories A2:A6 --values B2:B6 --title Sales` |
| Add a sheet | `moon run --target wasm cmd/xlsx -- add-sheet f.xlsx Summary` |
| Read a cell | `moon run --target wasm cmd/xlsx -- get f.xlsx Sheet1 A1` |
| See a sheet as a table | `moon run --target wasm cmd/xlsx -- view f.xlsx` |
| Dump a sheet as CSV | `moon run --target wasm cmd/xlsx -- rows f.xlsx` |
| List sheets | `moon run --target wasm cmd/xlsx -- sheets f.xlsx` |
| Apply many edits in one pass | `moon run --target wasm cmd/xlsx -- batch f.xlsx script.json` |
| See an .xlsx's structure as JSON | `moon run --target wasm cmd/xlsx -- outline f.xlsx` |
| Read a cell/range as JSON | `moon run --target wasm cmd/xlsx -- get f.xlsx Sheet1 A1:B4 --json` |
| **Render sheets to HTML** (to look at) | `moon run --target wasm cmd/xlsx -- html f.xlsx --out f.html` |
| Check an .xlsx is well-formed | `moon run --target wasm cmd/xlsx -- validate f.xlsx` |
| See a .docx's structure as JSON | `moon run --target wasm docx2html/cmd/docx -- outline in.docx` |
| Extract a .docx's text (with paths) | `moon run --target wasm docx2html/cmd/docx -- text in.docx` |
| Read one element as JSON | `moon run --target wasm docx2html/cmd/docx -- get in.docx '/body/p[2]' --json` |
| **Author a Word document** from JSON ops | `moon run --target wasm docx2html/cmd/docx -- batch out.docx script.json` |
| Create a blank .docx | `moon run --target wasm docx2html/cmd/docx -- create out.docx` |
| Check a .docx is well-formed | `moon run --target wasm docx2html/cmd/docx -- validate in.docx` |
| **Comment on an EXISTING .docx** (byte-preserving) | `moon run --target wasm docx2html/cmd/docx -- annotate add in.docx out.docx --at '/body/p[2]' --text 'Cite the source.' --author Reviewer --initials RV` |
| Reply in a comment thread | `moon run --target wasm docx2html/cmd/docx -- annotate reply in.docx out.docx --comment 0 --text 'Source added.' --author Author` |
| Resolve / unresolve a comment | `moon run --target wasm docx2html/cmd/docx -- annotate resolve in.docx out.docx --comment 0` |
| Read one comment as JSON (metadata, anchors, body) | `moon run --target wasm docx2html/cmd/docx -- get in.docx '/comments/comment[@id=0]' --json` |
| See the thread shape (replies link via `parent_id`) | `moon run --target wasm docx2html/cmd/docx -- outline in.docx` |
| Author a .docx WITH comments / foot-endnotes | `moon run --target wasm docx2html/cmd/docx -- batch out.docx script.json` (a `docx.batch/2` script) |
| Convert a .docx to HTML | `moon run --target wasm docx2html/cmd/docx2html -- in.docx out.html` |
| Convert a .docx to Markdown | `moon run --target wasm docx2html/cmd/docx2html -- --output-format=markdown in.docx out.md` |
| Convert a .docx + extract images | `moon run --target wasm docx2html/cmd/docx2html -- --output-dir ./out in.docx` |

Omit the output path on `docx2html` to write to stdout. Note that each `style`
call sets a cell's **complete** style (it replaces, not merges), so combine all
the formatting for a cell into one command and avoid overlapping styled ranges.

The batch script formats — `docx.batch/1` (or `docx.batch/2`, which adds
`comment` ops and inline foot/endnotes) for Word documents, `xlsx.batch/1`
for spreadsheets — are specified normatively in `docs/agent-json-schemas.md`;
read the matching section before writing a script (validation is strict:
unknown keys, duplicate keys, and non-integer numbers are errors, and `docx
batch` only creates NEW files). `recipes/author-docx.md` walks the whole
author→verify loop.

**Commenting on an existing document is different from authoring.** `batch`
only makes NEW files; to add/reply/resolve comments on a document you did not
author, use `docx annotate <add|reply|resolve|unresolve>`. These do
**byte-preserving surgery** — they rewrite only the comment-related parts
(`comments.xml`, `commentsExtended.xml`, the relationships and content-types
entries, and the marker fragments spliced into `document.xml`) and leave every
other *unrelated* existing part — `styles.xml`, other stories, media — byte
for byte identical, so they are safe on documents whose full content the lossy
reader does not model. Each verb writes a NEW
output file (never in place) and reads back before publishing. Read a document
and its existing discussion first (`outline`, then `get '/comments/comment[@id=N]'
--json`), because comment ids are the document's own spelled values.
`recipes/review-docx.md` walks the read→comment→reply→resolve loop.

For spreadsheets the same three verbs close an **inspect → edit → render**
loop: `outline` / `get … --json` show you what a workbook contains (and what
your edit produced) as parseable JSON; `batch` applies a whole set of changes
atomically; `html` renders a sheet to a self-contained document you can open
or screenshot to *see* the result — fonts, fills, merges, widths, images,
chart placeholders. Don't guess the state of a file you are editing; read it
back and look at it. `recipes/render-review-fix.md` walks the loop end to end.

## Going deeper

The table above is the fast path. When you need exact flags, output shapes, or
edge-case behavior, read the matching file (don't guess):

- `reference/xlsx.md` — every `cmd/xlsx` subcommand, its arguments, and quirks.
- `reference/docx.md` — the `docx` agent CLI (outline/text/get/validate/
  create/batch) and the `docx2html` converter: options, output modes, the
  batch authoring contract, and image handling.
- `docs/agent-json-schemas.md` (repo root) — the normative spec of every JSON
  payload the CLIs emit or consume.

For end-to-end workflows, follow a recipe:

- `recipes/data-to-spreadsheet.md` — build a spreadsheet from data in the conversation.
- `recipes/batch-edits.md` — make many spreadsheet edits in one atomic `batch` pass.
- `recipes/render-review-fix.md` — build a spreadsheet, render it to HTML, look, and correct it.
- `recipes/author-docx.md` — author a Word document from a JSON op script and verify it.
- `recipes/review-docx.md` — comment on an existing document: read → `annotate add` → reply → resolve, byte-preserving.
- `recipes/doc-to-markdown.md` — convert a Word document to clean Markdown/HTML.
- `recipes/inspect-untrusted.md` — safely dump and validate a file you don't trust.

## Confirm, don't assume

Both tools are self-describing. If you're unsure of a subcommand or flag, ask
the tool rather than guessing — it runs in the same sandbox:

```
moon run --target wasm cmd/xlsx -- --help
moon run --target wasm cmd/xlsx -- csv --help
moon run --target wasm docx2html/cmd/docx -- --help
moon run --target wasm docx2html/cmd/docx -- batch --help
moon run --target wasm docx2html/cmd/docx -- annotate --help
moon run --target wasm docx2html/cmd/docx -- annotate add --help
moon run --target wasm docx2html/cmd/docx2html -- --help
```

A failed run prints a diagnostic and exits non-zero. Batch-script errors are
always prefixed `error: …` and name the exact op (`error: ops[3].params.style
'Heading7' is unknown`); file-level failures are prefixed with the program
name (`docx: …` / `docx2html: …`); other usage/argument errors keep their
parser message, which is often but not always `error:`-prefixed. Either way, the
wasm backend has no stderr, so the diagnostic and any normal output both
arrive on stdout — check the exit code.
