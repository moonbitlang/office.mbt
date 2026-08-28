///|
test "image and link variants serialize to json" {
  let page = @pagelayout.Page::{ width_pt: 100, height_pt: 100, items: [], }
  page.items.push(
    Image({
      x_pt: 10,
      y_pt: 20,
      w_pt: 30,
      h_pt: 40,
      data: b"\x89PN",
      mime: "image/png",
    }),
  )
  page.items.push(
    Link({
      x_pt: 10,
      y_pt: 20,
      w_pt: 30,
      h_pt: 12,
      target: "https://a.example",
    }),
  )
  json_inspect(page.items, content=[
    [
      "Image",
      {
        "x_pt": 10,
        "y_pt": 20,
        "w_pt": 30,
        "h_pt": 40,
        "data": "\\x89PN",
        "mime": "image/png",
      },
    ],
    [
      "Link",
      {
        "x_pt": 10,
        "y_pt": 20,
        "w_pt": 30,
        "h_pt": 12,
        "target": "https://a.example",
      },
    ],
  ])
}

///|
test "validate accepts a well-formed model" {
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
  debug_inspect(model.validate(), content="[]")
}

///|
test "validate reports every structural violation" {
  let model = @pagelayout.PageModel::new()
  let page = @pagelayout.Page::{ width_pt: 612, height_pt: 792, items: [], }
  // advances/text mismatch AND dangling font index
  page.items.push(
    Text({
      font: 3,
      size_pt: 12,
      x_pt: 0,
      baseline_pt: 0,
      text: "abc",
      advances_pt: [1.0],
      color: @pagelayout.Color::rgb(999, 0, 0),
    }),
  )
  // stroke width without stroke color
  page.items.push(
    Rect({
      x_pt: 0,
      y_pt: 0,
      w_pt: 10,
      h_pt: 10,
      fill: Some(@pagelayout.black),
      stroke: None,
      stroke_w_pt: 1,
    }),
  )
  // stroke color with zero width, and paints-nothing rect
  page.items.push(
    Rect({
      x_pt: 0,
      y_pt: 0,
      w_pt: 10,
      h_pt: 10,
      fill: None,
      stroke: Some(@pagelayout.black),
      stroke_w_pt: 0,
    }),
  )
  model.pages.push(page)
  json_inspect(model.validate(), content=[
    "page 0 item 0: 1 advances for 3 UTF-16 code units", "page 0 item 0: font index 3 outside fonts[0..0]",
    "page 0 item 1: stroke width without stroke color", "page 0 item 2: stroke color with non-positive stroke width",
  ])
}

///|
test "validate flags raw out-of-range color channels" {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family: "Carlito", bold: false, italic: false, })
  let page = @pagelayout.Page::{ width_pt: 612, height_pt: 792, items: [], }
  page.items.push(
    Text({
      font,
      size_pt: 12,
      x_pt: 0,
      baseline_pt: 0,
      text: "x",
      advances_pt: [5.0],
      color: { r: 300, g: -5, b: 0, },
    }),
  )
  model.pages.push(page)
  inspect(model.validate().length(), content="1")
}
