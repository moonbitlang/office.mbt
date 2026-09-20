# pdf2md

`moonbitlang/pdf2md` is a small command-line wrapper that extracts readable
Markdown from a PDF. It is a thin CLI over the
[`moonbitlang/pdflite/markdown`](../pdflite/markdown/README.mbt.md) library.

```sh
moon run --target native pdf2md -- input.pdf output.md
```

The library API (`pdf_bytes_to_markdown`, `pdf_document_to_markdown`) lives in
`pdflite`; this module only owns the executable and its argument parsing.
