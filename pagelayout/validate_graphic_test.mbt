///|
fn stroked(
  segments : Array[@pagelayout.PathSegment],
  style : @pagelayout.StrokeStyle,
) -> @pagelayout.GraphicOp {
  Path({
    segments,
    fill: None,
    fill_rule: NonZero,
    stroke: Some(Solid(@pagelayout.black)),
    stroke_style: style,
  })
}

///|
test "validate rejects zero-width strokes, of paths and of text" {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family: "Sans", bold: false, italic: false, })
  let run = @pagelayout.GlyphRun::{
    font,
    size_pt: 10,
    x_pt: 0,
    baseline_pt: 10,
    text: "A",
    advances_pt: [6],
    color: @pagelayout.black,
  }
  let style = @pagelayout.StrokeStyle::default()
  let zero = { ..style, width: Width(0), }
  let line = [@pagelayout.PathSegment::MoveTo(0, 0), LineTo(1, 1)]
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [], }
  page.items.push(
    Graphic({
      x_pt: 0,
      y_pt: 0,
      ops: [
        stroked(line, zero),
        stroked(line, { ..style, width: Width(-1), }),
        PaintedText(run, {
          fill: false,
          stroke: Some(@pagelayout.black),
          stroke_style: zero,
        }),
        // fine: a hairline, and a width that no stroke uses
        stroked(line, { ..style, width: Hairline, }),
        PaintedText(run, { fill: true, stroke: None, stroke_style: zero, }),
        Path({
          segments: line,
          fill: Some(Solid(@pagelayout.black)),
          fill_rule: NonZero,
          stroke: None,
          stroke_style: zero,
        }),
      ],
    }),
  )
  model.pages.push(page)
  debug_inspect(
    model.validate(),
    content=(
      #|[
      #|  "page 0 item 0 op 0: stroke width not positive and finite",
      #|  "page 0 item 0 op 1: stroke width not positive and finite",
      #|  "page 0 item 0 op 2: stroke width not positive and finite",
      #|]
    ),
  )
}
