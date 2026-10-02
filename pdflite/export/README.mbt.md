# moonbitlang/pdflite/export

A PDF writer modelled on [krilla](https://github.com/LaurenzV/krilla): it ports
the parts of krilla that Typst's PDF exporter uses, so that a port of
`typst-pdf` can drive it with the same calls.

## Lifecycle

1. `Document::new_with(settings)` creates a document. `SerializeSettings`
   chooses the PDF version, validators (PDF/A, PDF/UA), tagging,
   compression and whether device color spaces may be used.
2. `Document::start_page_with(PageSettings::from_wh(w, h))` starts a page.
   `Page::surface()` returns its drawing surface: the origin is at the
   top-left corner and the y-axis points down. Every `push_*` (transform,
   clip path, opacity, blend mode, mask, isolated group) must be matched by
   a `pop`.
3. `Surface::finish()` stores the content in the page, `Page::finish()`
   stores the page in the document. Annotations are added to the page
   before it is finished.
4. Document-level data (metadata, outline, named destinations, tag tree,
   embedded files) can be set at any time before `Document::finish()`,
   which writes all objects and returns the file, or raises an
   `ExportError` (validation errors of the chosen standards, unsupported
   fonts, duplicate tag IDs, ...).

```moonbit check
///|
test "a page with a red square" {
  let doc = @export.Document::new_with(@export.SerializeSettings::default())
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(200.0, 100.0).unwrap(),
  )
  let surface = page.surface()
  surface.set_fill(
    Some({
      ..@export.Fill::default(),
      paint: Color(@export.Color::rgb(255, 0, 0)),
    }),
  )
  let path = @export.PathBuilder::new()
  path.push_rect(@export.Rect::from_xywh(10.0, 10.0, 50.0, 50.0).unwrap())
  surface.draw_path(path.finish().unwrap())
  surface.finish()
  page.finish()
  doc.set_metadata(@export.Metadata::new().title("Example"))
  let bytes = doc.finish()
  inspect(bytes[0:8] == b"%PDF-1.7", content="true")
}
```

## Supported features

Paths with fills and strokes (device, ICC-based and separation colors,
linear/radial/sweep gradients, tiling patterns), clip paths, opacity, blend
modes, masks and transforms; glyph runs in TrueType and CFF fonts (CID-keyed
`Type0` fonts with `ToUnicode` maps; color glyphs through Type 3 fonts drawn
by a user hook); raster images (8-bit samples with alpha, JPEG passthrough);
link annotations, outlines, named destinations, page labels, metadata (info
dictionary and XMP), embedded files and tagged PDF.

## Known limitations

- TrueType fonts are subset by emptying unused glyphs (glyph IDs are kept);
  CFF fonts are embedded whole as CID-keyed CFF programs (name-keyed ones are
  converted). CFF2 fonts, which krilla converts to CFF, are embedded as
  OpenType font programs, which PDF doesn't define for CFF2 outlines.
- There is no CMYK output profile: CMYK colors stay in DeviceCMYK, which
  PDF/A reports as `MissingCMYKProfile`.
- No `CIDSet` is written (PDF/A-1 requires one).
