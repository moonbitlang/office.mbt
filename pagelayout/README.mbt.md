# pagelayout

Paginated document layout engine. Frontends (DOCX first) produce engine
input; the engine measures, line-breaks, and paginates into a format-neutral
**page-model IR** — pages of positioned glyph runs, rectangles, images, and
link regions; backends (SVG first, then PDF via pdflite) transcribe the IR.
Design record: `docs/page-layout-engine.md` at the repository root.

Coordinates are points, y-down, origin at the page's top-left; text is
positioned by baseline, and glyph runs carry their own advances so backends
never re-measure.

```mbt check
///|
test "build a one-page model" {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family: "Carlito", bold: false, italic: false, })
  let page = @pagelayout.Page::{ width_pt: 612, height_pt: 792, items: [], }
  page.items.push(
    Text({
      font,
      size_pt: 12,
      x_pt: 72,
      baseline_pt: 82.5,
      text: "Hi",
      advances_pt: [6.5, 6.5],
      color: @pagelayout.black,
    }),
  )
  model.pages.push(page)
  inspect(model.pages.length(), content="1")
}
```

OOXML quantities stay in typed units until the layout boundary:

```mbt check
///|
test "unit conversions" {
  inspect(@pagelayout.Twips(1440).to_pt(), content="72")
  inspect(@pagelayout.HalfPoints(24).to_pt(), content="12")
  inspect(@pagelayout.Emu(914400).to_pt(), content="72")
  inspect(@pagelayout.EighthPoints(4).to_pt(), content="0.5")
}
```

## Fonts

Text is measured and drawn with one face per family and style, from one of
three sources:

- the bundled faces (Carlito, Liberation Sans/Serif/Mono, Noto Sans SC as
  the CJK fallback), embedded in a PDF as subsets;
- a caller's own TrueType/OpenType file, `FontRegistry::register` in
  `pagelayout/fonts`, embedded when it has TrueType outlines;
- a PDF standard font, `FontRegistry::register_standard`: one of the twelve
  Latin faces `@fonts.standard_fonts()` lists (Helvetica, Times-Roman and
  Courier, each with its bold, italic/oblique and bold italic face),
  declared by name with `/WinAnsiEncoding` and never embedded. Its metrics
  are the caller's, built with `FaceMetrics::new` from the font's AFM
  (pagelayout ships no AFM data); text outside WinAnsi is dropped, and
  kerning goes into the runs' advances. `Symbol` and `ZapfDingbats` are
  not supported.

Hand the same `FontRegistry` to layout and to `@pdf.RenderOptions`, so that
text is drawn in the face it was measured with.
