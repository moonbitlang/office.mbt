---
name: office
description: >-
  Work with Office/OOXML documents — Excel .xlsx spreadsheets and Word .docx
  files — by running this repo's CLIs on the WebAssembly backend, a
  memory-safe sandbox with no native document libraries. Use it to generate a
  spreadsheet, turn CSV/table data into .xlsx, read or dump cells, convert a
  .docx to HTML or Markdown, extract a document's images, or check that a file
  is structurally valid. Reach for this instead of openpyxl / ExcelJS /
  python-docx / pandoc / LibreOffice.
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

- `<tool>` is `cmd/xlsx` (spreadsheets) or `docx2html/cmd/docx2html` (Word docs).
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
| Style a cell/range | `moon run --target wasm cmd/xlsx -- style f.xlsx Sheet1 A1:B1 --bold --fill FFFF00` |
| Merge cells | `moon run --target wasm cmd/xlsx -- merge f.xlsx Sheet1 A1:C1` |
| Read a cell | `moon run --target wasm cmd/xlsx -- get f.xlsx Sheet1 A1` |
| See a sheet as a table | `moon run --target wasm cmd/xlsx -- view f.xlsx` |
| Dump a sheet as CSV | `moon run --target wasm cmd/xlsx -- rows f.xlsx` |
| List sheets | `moon run --target wasm cmd/xlsx -- sheets f.xlsx` |
| Check an .xlsx is well-formed | `moon run --target wasm cmd/xlsx -- validate f.xlsx` |
| Convert a .docx to HTML | `moon run --target wasm docx2html/cmd/docx2html -- in.docx out.html` |
| Convert a .docx to Markdown | `moon run --target wasm docx2html/cmd/docx2html -- --output-format=markdown in.docx out.md` |
| Convert a .docx + extract images | `moon run --target wasm docx2html/cmd/docx2html -- --output-dir ./out in.docx` |

Omit the output path on `docx2html` to write to stdout. Note that each `style`
call sets a cell's **complete** style (it replaces, not merges), so combine all
the formatting for a cell into one command and avoid overlapping styled ranges.

## Going deeper

The table above is the fast path. When you need exact flags, output shapes, or
edge-case behavior, read the matching file (don't guess):

- `reference/xlsx.md` — every `cmd/xlsx` subcommand, its arguments, and quirks.
- `reference/docx.md` — every `docx2html` option, output modes, and image handling.

For end-to-end workflows, follow a recipe:

- `recipes/data-to-spreadsheet.md` — build a spreadsheet from data in the conversation.
- `recipes/doc-to-markdown.md` — convert a Word document to clean Markdown/HTML.
- `recipes/inspect-untrusted.md` — safely dump and validate a file you don't trust.

## Confirm, don't assume

Both tools are self-describing. If you're unsure of a subcommand or flag, ask
the tool rather than guessing — it runs in the same sandbox:

```
moon run --target wasm cmd/xlsx -- --help
moon run --target wasm cmd/xlsx -- csv --help
moon run --target wasm docx2html/cmd/docx2html -- --help
```

A failed run prints a diagnostic and exits non-zero. `cmd/xlsx` errors are
prefixed `error: …`. `docx2html` usage/argument errors keep their parser
message (often `error: …`), while a failure to read the input or convert it is
prefixed `docx2html: …`. Either way, the wasm backend has no stderr, so the
diagnostic and any normal output both arrive on stdout — check the exit code.
