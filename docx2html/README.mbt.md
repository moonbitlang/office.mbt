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

Use `convert` or `convert_document` with `output_format=Markdown` when the
format is chosen dynamically:

```mbt check
///|
test "choose markdown output" {
  let doc = @docx2html.document([
    @docx2html.paragraph([@docx2html.text("Hello.")]),
  ])
  let result = @docx2html.convert_document(doc, output_format=Markdown)
  inspect(result.value, content="Hello\\.\n\n")
}
```

For DOCX bytes, use `convert`, `convert_to_html`, `convert_to_markdown`, or
`extract_raw_text`. The native API accepts `BytesView`, so callers can decide how
to load files. External linked images stay disabled by default, matching Mammoth;
pass `external_file_access=true` and a `read_external_file` callback when the
source document is allowed to read sibling files. Use `read_docx_with_messages`
when you need the parsed document model together with DOCX reader diagnostics;
`read_docx` is the document-only convenience wrapper.

## Style Maps

Pass explicit style-map lines with `style_map`. If you already have a
Mammoth-style multi-line string, normalize it with `read_style_map_string` so
comments, blank lines, and trimming follow Mammoth's option parser:

```mbt check
///|
test "parse mammoth style map strings" {
  let style_map_text =
    #|# ignored
    #|
    #|p[style-name='Heading 1'] => h2
  let style_map = @docx2html.read_style_map_string(style_map_text)
  let doc = @docx2html.document([
    @docx2html.paragraph(
      [@docx2html.text("Title")],
      properties=@docx2html.paragraph_properties(style_name=Some("Heading 1")),
    ),
  ])
  let result = @docx2html.convert_document_to_html(doc, style_map~)
  inspect(result.value, content="<h2>Title</h2>")
}
```

Use `parse_style_map` or `parse_style_map_string` when you want to validate a
style map before conversion while preserving the valid mappings:

```mbt check
///|
test "preflight style map diagnostics" {
  let parsed = @docx2html.parse_style_map_string(
    "p.SectionTitle => h2\np => span#",
  )
  inspect(parsed.mappings.length(), content="1")
  debug_inspect(
    parsed.messages,
    content=(
      #|[Warning("Did not understand this style mapping, so ignored it: p => span#\nError was at character number 10: Expected end but got unrecognisedCharacter \"#\"")]
    ),
  )
}
```

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
moon run --target native cmd/docx2html -- input.docx
moon run --target native cmd/docx2html -- --output-format=markdown input.docx
moon run --target native cmd/docx2html -- --style-map style-map input.docx output.html
moon run --target native cmd/docx2html -- --output-dir out input.docx
```

The executable examples in `tests/cram/cli.md` are verified by:

```bash
moon cram test tests/cram
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

Image converters return diagnostics explicitly instead of throwing:

```mbt check
///|
test "custom image conversion diagnostics" {
  let image = @docx2html.image("image/png", b"abc", alt_text=Some("chart"))
  let convert_image = fn(_image : @docx2html.Image) {
    @docx2html.image_conversion([], messages=[@docx2html.error("image omitted")])
  }
  let result = @docx2html.convert_document_to_html(image, convert_image~)
  inspect(result.value, content="")
  debug_inspect(result.messages, content="[Error(\"image omitted\")]")
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

This is an active native-first port. The verified scope covers the core
`docx -> html`, `docx -> markdown`, and raw-text paths, plus embedded style
maps, external-image loader callbacks, notes, comments, tables, hyperlinks,
complex fields, XML/ZIP helpers, and the native CLI. See
[MammothParity.md](MammothParity.md) for the current parity ledger,
[StressTesting.md](StressTesting.md) for large-file comparison notes, and the
intentional API differences from Mammoth's JavaScript surface.
