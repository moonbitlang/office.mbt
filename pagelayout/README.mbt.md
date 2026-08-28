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
