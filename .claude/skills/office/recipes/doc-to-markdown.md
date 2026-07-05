# Recipe: Word document → Markdown (or HTML)

Goal: turn a `.docx` into clean Markdown or HTML — e.g. to quote its contents,
diff it, or publish it — without a native converter.

## Quick: to stdout

```
moon run --target wasm docx2html/cmd/docx2html -- --output-format=markdown report.docx
```

The Markdown prints to stdout; capture it or redirect to a file.

## To files, with images extracted

If the document has images and you want them as separate files rather than
inlined base64:

```
moon run --target wasm docx2html/cmd/docx2html -- --output-dir ./report-out report.docx
```

This writes `report-out/report.html` plus `report-out/1.png`, `2.png`, … The
HTML references the images by name.

## Remapping Word styles

Word "Heading 1", callouts, etc. map to generic elements by default. To control
the mapping, write Mammoth style-map lines to a file and pass `--style-map`:

```
cat > styles.txt <<'MAP'
p[style-name='Heading 1'] => h1:fresh
p[style-name='Quote'] => blockquote:fresh
MAP
moon run --target wasm docx2html/cmd/docx2html -- --style-map styles.txt report.docx report.html
```

Notes:
- Default output is HTML; add `--output-format=markdown` for Markdown.
- Add `--pretty-print` to indent HTML output.
- A malformed or non-DOCX file fails with a single `docx2html: …` line and a
  non-zero exit — safe to run on documents you don't trust (see
  `recipes/inspect-untrusted.md`).
