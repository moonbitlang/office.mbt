# Reference: `docx2html/cmd/docx2html`

Run as `moon run --target wasm docx2html/cmd/docx2html -- [options] <input.docx> [output]`
from the repo root. It's a port of Mammoth: DOCX → HTML or Markdown.

```
Usage: docx2html [options] <input> [output]

Arguments:
  input   Input .docx file.
  output  Output file. Defaults to stdout unless --output-dir is set.

Options:
  -h, --help                       Show help information.
  --pretty-print                   Pretty-print generated HTML.
  --style-map <style-map>          Read Mammoth style-map lines from a file.
  --output-format <output-format>  Output format: html or markdown. [default: html]
  --output-dir <output-dir>        Write converted output and extracted images into a directory.
```

## Behavior and quirks

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
- **Diagnostics.** Conversion warnings are printed to stdout only when the
  document output went to a *file* (so they never corrupt output piped to
  stdout — the wasm backend has no stderr). On failure it exits non-zero:
  usage/argument errors keep their parser message (usually `error: …`), while
  a failure to read the input or convert/write it is prefixed `docx2html: …`.

## Examples

```
# to stdout
moon run --target wasm docx2html/cmd/docx2html -- report.docx

# to a Markdown file
moon run --target wasm docx2html/cmd/docx2html -- --output-format=markdown report.docx report.md

# to a directory, extracting images as separate files
moon run --target wasm docx2html/cmd/docx2html -- --output-dir ./out report.docx

# remap Word styles via a style map
moon run --target wasm docx2html/cmd/docx2html -- --style-map styles.txt report.docx report.html
```
