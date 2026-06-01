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

## Document Model

The document model exposes enum constructors for pattern matching and
lower-snake helpers for building nodes and property records:

```mbt check
///|
test "build document model with helpers" {
  let doc = @docx2html.document([
    @docx2html.paragraph(
      [
        @docx2html.hyperlink(
          [@docx2html.text("MoonBit")],
          href=Some("https://www.moonbitlang.com"),
        ),
      ],
      properties=@docx2html.paragraph_properties(style_name=Some("Heading 1")),
    ),
    @docx2html.table([
      @docx2html.table_row([
        @docx2html.table_cell([@docx2html.paragraph([@docx2html.text("Cell")])]),
      ]),
    ]),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map=[
    "p[style-name='Heading 1'] => h2",
  ])
  inspect(
    result.value,
    content="<h2><a href=\"https://www.moonbitlang.com\">MoonBit</a></h2><table><tr><td><p>Cell</p></td></tr></table>",
  )
}
```

Embedded style maps can be inspected or rewritten without a JavaScript-style
mutable ZIP object. Use `read_embedded_style_map(docx[:])` to read the raw
`mammoth/style-map` part, and `embed_style_map(docx[:], "p => h1")` to return a
new DOCX archive with the style map, relationship entry, and content-type
override updated.

## Transforms

Document transforms run before conversion and recurse through child-bearing
nodes. Use the typed helpers instead of Mammoth's JavaScript string type names:

```mbt check
///|
test "transform runs before conversion" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.run([@docx2html.text("Hello.")])]),
  ])
  let transform_document = @docx2html.transform_runs(fn(_run) {
    @docx2html.run([@docx2html.text("Goodbye.")])
  })
  let result = @docx2html.convert_document_to_html(doc, transform_document~)
  inspect(result.value, content="<p>Goodbye.</p>")
  let runs = @docx2html.document_descendants_where(doc, fn(element) {
    element is Run(..)
  })
  inspect(runs.length(), content="1")
}
```

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
that behavior. `data_uri_image` is the default converter, and `inline_image`
is the MoonBit name for Mammoth's
`images.inline`/`images.imgElement` helper:

```mbt check
///|
test "custom image conversion" {
  let image = @docx2html.Image::{
    content_type: "image/png",
    alt_text: Some("chart"),
    data: b"abc",
  }
  let doc = @docx2html.document([@docx2html.paragraph([Image(image)])])
  let convert_image = @docx2html.inline_image(fn(_image) {
    { "src": "/assets/chart.png" }
  })
  let result = @docx2html.convert_document_to_html(doc, convert_image~)
  inspect(
    result.value,
    content="<p><img alt=\"chart\" src=\"/assets/chart.png\" /></p>",
  )
}
```

## Results

Conversion results carry rendered text plus diagnostics. Use `combine_results`
when stitching several conversion fragments together:

```mbt check
///|
test "combine conversion results" {
  let combined = @docx2html.combine_results([
    @docx2html.success("One"),
    { value: "Two", messages: [Warning("same")] },
    { value: "Three", messages: [Warning("same")] },
  ])
  inspect(combined.value, content="OneTwoThree")
  debug_inspect(combined.messages, content="[Warning(\"same\")]")
}
```

## Status

This is an active port. The native core and carried Mammoth parity tests are
green, but the broader Mammoth public surface is still being expanded.
