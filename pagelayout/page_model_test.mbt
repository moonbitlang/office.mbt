///|
test "color hex formatting is lowercase and clamped" {
  inspect(@pagelayout.black.to_hex(), content="#000000")
  let c = @pagelayout.Color::{ r: 255, g: 128, b: 11, }
  inspect(c.to_hex(), content="#ff800b")
  let out_of_range = @pagelayout.Color::{ r: 300, g: -5, b: 0, }
  inspect(out_of_range.to_hex(), content="#ff0000")
}

///|
test "glyph run width is the sum of advances" {
  let run = @pagelayout.GlyphRun::{
    font: 0,
    size_pt: 12,
    x_pt: 72,
    baseline_pt: 100,
    text: "abc",
    advances_pt: [5.5, 6, 5.5],
    color: @pagelayout.black,
  }
  inspect(run.width_pt(), content="17")
}

///|
test "add_font interns equal specs" {
  let model = @pagelayout.PageModel::new()
  let body = @pagelayout.FontSpec::{
    family: "Carlito",
    bold: false,
    italic: false,
  }
  let heading = @pagelayout.FontSpec::{
    family: "Carlito",
    bold: true,
    italic: false,
  }
  inspect(model.add_font(body), content="0")
  inspect(model.add_font(heading), content="1")
  inspect(model.add_font(body), content="0")
  inspect(model.fonts.length(), content="2")
}

///|
test "color rgb constructor clamps channels" {
  inspect(@pagelayout.Color::rgb(300, -5, 128).to_hex(), content="#ff0080")
  let c = @pagelayout.Color::rgb(255, 128, 11)
  inspect(c.to_hex(), content="#ff800b")
}

///|
test "page model serializes to canonical json (one-way; no FromJson yet)" {
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
  page.items.push(
    Rect({
      x_pt: 72,
      y_pt: 84,
      w_pt: 13,
      h_pt: 0.6,
      fill: Some(@pagelayout.black),
      stroke: None,
      stroke_w_pt: 0,
    }),
  )
  model.pages.push(page)
  json_inspect(model, content={
    "fonts": [{ "family": "Carlito", "bold": false, "italic": false }],
    "pages": [
      {
        "width_pt": 612,
        "height_pt": 792,
        "items": [
          [
            "Text",
            {
              "font": 0,
              "size_pt": 12,
              "x_pt": 72,
              "baseline_pt": 82.5,
              "text": "Hi",
              "advances_pt": [6.5, 6.5],
              "color": { "r": 0, "g": 0, "b": 0 },
            },
          ],
          [
            "Rect",
            {
              "x_pt": 72,
              "y_pt": 84,
              "w_pt": 13,
              "h_pt": 0.6,
              "fill": { "r": 0, "g": 0, "b": 0 },
              "stroke_w_pt": 0,
            },
          ],
        ],
      },
    ],
  })
}
