# bobzhang/docx2html

Native MoonBit DOCX reader and converter, ported from Mammoth. The current
focus is the common `docx -> html`, `docx -> markdown`, and raw-text paths with
Mammoth-compatible diagnostics where the JavaScript library exposes them.

## Install

```bash
moon add bobzhang/docx2html
```

## Usage

```mbt check
///|
test "convert document model to html" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Hello.")]),
  ])
  let result = @docx2html.convert_document_to_html(doc)
  inspect(result.value, content="<p>Hello.</p>")
}
```

For DOCX bytes, use `convert_to_html`, `convert_to_markdown`, or
`extract_raw_text`. The native API accepts `BytesView`, so callers can decide
how to load files. External linked images stay disabled by default, matching
Mammoth; pass `external_file_access=true` and a `read_external_file` callback
when the source document is allowed to read sibling files.

Embedded style maps can be inspected or rewritten without a JavaScript-style
mutable ZIP object. Use `read_embedded_style_map(docx[:])` to read the raw
`mammoth/style-map` part, and `embed_style_map(docx[:], "p => h1")` to return a
new DOCX archive with the style map, relationship entry, and content-type
override updated.

## Native CLI

From this repository checkout, the native executable mirrors the common Mammoth
CLI paths:

```bash
moon run --target native cmd/main -- input.docx
moon run --target native cmd/main -- --output-format=markdown input.docx
moon run --target native cmd/main -- --style-map style-map input.docx output.html
moon run --target native cmd/main -- --output-dir out input.docx
```

## Image Conversion

Images are emitted as data URIs by default. Pass `convert_image` to override
that behavior:

```mbt check
///|
test "custom image conversion" {
  let image = @docx2html.Image::{
    content_type: "image/png",
    alt_text: Some("chart"),
    data: b"abc",
  }
  let doc = @docx2html.document([@docx2html.paragraph([Image(image)])])
  let convert_image = @docx2html.img_element(fn(_image) {
    { "src": "/assets/chart.png" }
  })
  let result = @docx2html.convert_document_to_html(doc, convert_image~)
  inspect(
    result.value,
    content="<p><img alt=\"chart\" src=\"/assets/chart.png\" /></p>",
  )
}
```

## Status

This is an active port. The native core and carried Mammoth parity tests are
green, but the broader Mammoth public surface is still being expanded.
