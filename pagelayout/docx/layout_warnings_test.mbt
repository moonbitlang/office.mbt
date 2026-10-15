///|
test "nested tables and paragraph section breaks report omitted layout" {
  let bytes = docx_bytes(
    "<w:p><w:pPr><w:sectPr><w:pgSz w:w=\"16838\" w:h=\"11906\"/></w:sectPr></w:pPr><w:r><w:t>Body</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:tbl><w:tr><w:tc><w:p><w:r><w:t>Nested</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:tc></w:tr></w:tbl>",
  )
  let document = @docx.read_docx(bytes)
  debug_inspect(
    (
      document.unsupported.contains("nested table"),
      document.unsupported.contains("paragraph section break"),
    ),
    content="(true, true)",
  )
}

///|
test "deleted content and historical paragraph properties do not produce warnings" {
  let document = @docx.read_docx(
    docx_bytes(
      "<w:p><w:pPr><w:pPrChange><w:pPr><w:sectPr/></w:pPr></w:pPrChange></w:pPr><w:del><w:r><w:footnoteReference w:id=\"1\"/></w:r></w:del><w:r><w:t>Current text</w:t></w:r></w:p>",
    ),
  )
  debug_inspect(document.unsupported, content="[]")
}

///|
test "missing inline media does not claim that an image was placed" {
  let bytes = docx_with_image(
    inline_drawing().replace(old="rI", new="missingImage"),
  )
  let document = @docx.read_docx(bytes)
  debug_inspect(
    (
      document.unsupported.contains("inline image placed after paragraph"),
      document.unsupported.is_empty(),
    ),
    content="(false, false)",
  )
}

///|
test "block controls keep visible paragraph content in the page model" {
  let document = @docx.read_docx(
    docx_bytes(
      "<w:sdt><w:sdtContent><w:p><w:r><w:t>Controlled text</w:t></w:r></w:p></w:sdtContent></w:sdt>",
    ),
  )
  let model = @paginate.paginate(document.blocks, section=document.section)
  debug_inspect(
    (
      document.unsupported.contains("content control"),
      model.pages.any(page => {
        page.items.any(item => {
          item is Text(run) && run.text.contains("Controlled text")
        })
      }),
    ),
    content="(true, true)",
  )
}

///|
test "ordinary paragraphs have no unsupported layout diagnostics" {
  let document = @docx.read_docx(
    docx_bytes("<w:p><w:r><w:t>Body</w:t></w:r></w:p>"),
  )
  debug_inspect(document.unsupported, content="[]")
}

///|
test "inline image shares the text baseline between preceding and following text" {
  let document = @docx.read_docx(
    docx_with_image("<w:t>Before</w:t>" + inline_drawing() + "<w:t>After</w:t>"),
  )
  debug_inspect(document.unsupported, content="[]")
  let model = @paginate.paginate(document.blocks, section=document.section)
  debug_inspect(model.validate(), content="[]")
  let text = model.pages[0].items.filter_map(item => {
    match item {
      Text(run) => Some(run)
      _ => None
    }
  })
  let images = model.pages[0].items.filter_map(item => {
    match item {
      Image(image) => Some(image)
      _ => None
    }
  })
  debug_inspect(
    (images.length(), text.map(run => run.text)),
    content="(1, [\"Before\", \"After\"])",
  )
  let image = images[0]
  debug_inspect(
    (
      image.x_pt > text[0].x_pt,
      (text[1].x_pt - image.x_pt - image.w_pt).abs() < 0.001,
      (image.y_pt + image.h_pt - text[0].baseline_pt).abs() < 0.001,
      text[0].baseline_pt == text[1].baseline_pt,
    ),
    content="(true, true, true, true)",
  )
}

///|
test "inline picture wraps atomically and reserves vertical space for following paragraph" {
  let drawing = inline_drawing().replace(old="1828800", new="5500000")
  let bytes = docx_with_image(
    "<w:t>preceding text before a large picture </w:t>" +
    drawing +
    "<w:t> following text</w:t></w:r></w:p><w:p><w:r><w:t>Next paragraph</w:t>",
  )
  let document = @docx.read_docx(bytes)
  let model = @paginate.paginate(document.blocks, section=document.section)
  debug_inspect(model.validate(), content="[]")
  let images = model.pages[0].items.filter_map(item => {
    match item {
      Image(image) => Some(image)
      _ => None
    }
  })
  debug_inspect(images.length(), content="1")
  let image = images[0]
  let next = model.pages[0].items.filter_map(item => {
    match item {
      Text(run) => if run.text == "Next paragraph" { Some(run) } else { None }
      _ => None
    }
  })
  debug_inspect(
    next.map(run => run.baseline_pt > image.y_pt + image.h_pt),
    content="[true]",
  )
  debug_inspect(
    model.pages[0].items.any(item => {
      item is Text(run) && run.text.contains("\uFFFC")
    }),
    content="false",
  )
}
