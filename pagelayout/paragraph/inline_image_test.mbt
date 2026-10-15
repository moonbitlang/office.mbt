///|
fn picture_at(
  offset : Int32,
  width~ : Double = 100,
  height~ : Double = 50,
) -> @paragraph.InlineImage {
  {
    offset_utf16: offset,
    width_pt: width,
    height_pt: height,
    data: b"image",
    mime: "image/png",
  }
}

///|
test "inline images fit the actual line after leading whitespace and hard breaks" {
  for
    (text, offset, expected_line) in [
      (" \uFFFC", 1, 0),
      ("\t\uFFFC", 1, 1),
      ("\n \uFFFC", 2, 1),
    ] {
    let rich = @paragraph.layout_paragraph_with_images(
      para(text, first=20),
      100,
      [picture_at(offset)],
    )
    debug_inspect(
      rich.images.map(image => {
        (
          image.line == expected_line,
          image.x_pt + image.width_pt <= 100.000001,
          (image.width_pt / image.height_pt - 2).abs() < 0.000001,
        )
      }),
      content="[(true, true, true)]",
    )
  }
}

///|
test "wrapped inline images use the continuation line rather than the first line indent" {
  let rich = @paragraph.layout_paragraph_with_images(
    para("Before \uFFFC", first=20),
    100,
    [picture_at(7)],
  )
  debug_inspect(
    rich.images.map(image => {
      (
        image.line > 0,
        image.width_pt,
        image.x_pt + image.width_pt <= 100.000001,
      )
    }),
    content="[(true, 100, true)]",
  )
}

///|
test "hanging first line images can use their actual wider measure" {
  let rich = @paragraph.layout_paragraph_with_images(
    para("\uFFFC", first=-20),
    100,
    [picture_at(0, width=120, height=60)],
  )
  debug_inspect(
    rich.images.map(image => (image.x_pt, image.width_pt, image.height_pt)),
    content="[(-20, 120, 60)]",
  )
}

///|
test "rejected and missing image entries omit their placeholders and advances" {
  for
    (width, height) in [
      (0.0, 50.0),
      (-1.0, 50.0),
      (100.0, 0.0),
      (1.0 / 0.0, 50.0),
      (0.0 / 0.0, 50.0),
    ] {
    let rich = @paragraph.layout_paragraph_with_images(para("\uFFFC"), 100, [
      picture_at(0, width~, height~),
    ])
    debug_inspect(
      (rich.images.length(), rich.layout.lines[0].runs.length()),
      content="(0, 0)",
    )
  }
  let missing = @paragraph.layout_paragraph_with_images(para("\uFFFC"), 100, [])
  debug_inspect(
    (missing.images.length(), missing.layout.lines[0].runs.length()),
    content="(0, 0)",
  )
  let surrounded = @paragraph.layout_paragraph_with_images(
    para("a\uFFFCb"),
    100,
    [picture_at(1, width=0)],
  )
  debug_inspect(
    surrounded.layout.lines[0].runs.map(run => run.text),
    content="[\"a\", \"b\"]",
  )
  let runs = surrounded.layout.lines[0].runs
  debug_inspect(
    (runs[1].x_pt - runs[0].x_pt - runs[0].advances_pt[0]).abs() < 0.000001,
    content="true",
  )
}

///|
test "unusable line measures omit images without leaking object markers" {
  for width in [0.0, -1.0, 0.0 / 0.0, 1.0 / 0.0] {
    let rich = @paragraph.layout_paragraph_with_images(para("\uFFFC"), width, [
      picture_at(0),
    ])
    debug_inspect(
      (rich.images.length(), rich.layout.lines[0].runs.length()),
      content="(0, 0)",
    )
  }
  let rich = @paragraph.layout_paragraph_with_images(
    para("\uFFFC\n\uFFFC", first=120),
    100,
    [picture_at(0), picture_at(2)],
  )
  debug_inspect(
    (rich.images.map(image => image.line), rich.layout.lines[0].runs.length()),
    content="([1], 0)",
  )
}

///|
test "many inline pictures remain ordered across separate lines" {
  let text = [ for _ in 0..<256 => "\uFFFC" ].join("\n")
  let rich = @paragraph.layout_paragraph_with_images(
    para(text),
    100,
    [
      for i in 0..<256 => picture_at(i * 2)
    ],
  )
  debug_inspect(
    (rich.images.length(), rich.layout.lines.length()),
    content="(256, 256)",
  )
  for i, image in rich.images {
    debug_inspect(image.line == i && image.x_pt == 0, content="true")
  }
}
