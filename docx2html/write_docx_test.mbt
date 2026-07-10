///|
fn sample_body() -> Array[@docx2html.DocumentElement] {
  [
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("Quarterly Report")])],
      properties=@docx2html.paragraph_properties(style_id=Some("Heading1")),
    ),
    @docx2html.paragraph(
      [
        @docx2html.run(
          [@docx2html.text("Bold lead. ")],
          properties=@docx2html.run_properties(is_bold=true),
        ),
        @docx2html.run(
          [@docx2html.text("Italic tail with size.")],
          properties=@docx2html.run_properties(
            is_italic=true,
            font=Some("Arial"),
            font_size=Some(14),
          ),
        ),
      ],
      properties=@docx2html.paragraph_properties(alignment=Some("center")),
    ),
    @docx2html.paragraph([
      @docx2html.run([
        @docx2html.text("tab:"),
        @docx2html.tab(),
        @docx2html.text(" spaced "),
        @docx2html.line_break(),
        @docx2html.text("after break"),
      ]),
    ]),
  ]
}

///|
test "written documents are structurally valid and round-trip semantically" {
  let bytes = @docx2html.write_docx(sample_body())
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let result = @docx2html.read_docx_package(bytes)
  debug_inspect(result.messages, content="[]")
  // Semantic round trip: the reader reconstructs the written body, ENRICHED
  // with the style names it resolves from the emitted styles part (the one
  // deliberate asymmetry — write takes ids, read resolves names too).
  guard result.document is Document(children~, ..)
  let expected = sample_body()
  expected[0] = @docx2html.paragraph(
    [@docx2html.run([@docx2html.text("Quarterly Report")])],
    properties=@docx2html.paragraph_properties(
      style_id=Some("Heading1"),
      style_name=Some("heading 1"),
    ),
  )
  assert_eq(children, expected)
  // The written heading is recognized by this repo's own heading detection
  // (style id + emitted styles part with the Mammoth-convention name).
  let payload = @inspect.outline(result.document, file="w.docx")
  guard payload is Object(fields) && fields.get("headings") is Some(headings)
  json_inspect(headings, content=[
    {
      "level": 1,
      "text": "Quarterly Report",
      "style_id": "Heading1",
      "style_name": "heading 1",
    },
  ])
}

///|
test "the written document converts to the expected HTML" {
  let bytes = @docx2html.write_docx(sample_body())
  inspect(
    @docx2html.convert_to_html(bytes).value,
    content=(
      #|<h1>Quarterly Report</h1><p><strong>Bold lead. </strong><em>Italic tail with size.</em></p><p>tab:	 spaced <br />after break</p>
    ),
  )
}

///|
test "font size survives the write-read round trip exactly" {
  let bytes = @docx2html.write_docx([
    @docx2html.paragraph([
      @docx2html.run(
        [@docx2html.text("sized")],
        properties=@docx2html.run_properties(font_size=Some(14)),
      ),
    ]),
  ])
  let result = @docx2html.read_docx_package(bytes)
  guard result.document is Document(children~, ..)
  guard children is [Paragraph(children=inner, ..)]
  guard inner is [Run(properties~, ..)]
  debug_inspect(properties.font_size, content="Some(14)")
}

///|
fn expect_unsupported(
  body : Array[@docx2html.DocumentElement],
  expected_prefix : String,
) -> Unit raise {
  try {
    let _ = @docx2html.write_docx(body)
  } catch {
    Unsupported(message~) =>
      if !message.has_prefix(expected_prefix) {
        fail("unexpected message: \{message}")
      }
    err => fail("expected Unsupported, got \{repr(err)}")
  } noraise {
    _ => fail("expected the writer to fail closed")
  }
}

///|
test "the F1 writer fails closed on everything it cannot serialize yet" {
  expect_unsupported(
    [@docx2html.table([])],
    "the paragraph writer cannot serialize this element yet: table",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.hyperlink(
          [@docx2html.run([@docx2html.text("x")])],
          href=Some("https://example.com"),
        ),
      ]),
    ],
    "the paragraph writer cannot serialize this inline element yet: hyperlink",
  )
  expect_unsupported(
    [
      @docx2html.paragraph(
        [@docx2html.run([@docx2html.text("x")])],
        properties=@docx2html.paragraph_properties(
          numbering=Some(@docx2html.numbering(true, 0)),
        ),
      ),
    ],
    "the paragraph writer cannot serialize list numbering yet",
  )
  expect_unsupported(
    [
      @docx2html.paragraph(
        [@docx2html.run([@docx2html.text("x")])],
        properties=@docx2html.paragraph_properties(style_id=Some("Fancy")),
      ),
    ],
    "unsupported paragraph style id for the writer: 'Fancy'",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run([@docx2html.image("image/png", b"\x89PNG")]),
      ]),
    ],
    "the run writer cannot serialize this content yet: image",
  )
}

///|
test "review round 1: fail closed on indent, dangling style name, raw CR" {
  expect_unsupported(
    [
      @docx2html.paragraph(
        [@docx2html.run([@docx2html.text("x")])],
        properties=@docx2html.paragraph_properties(
          indent=@docx2html.indent(start=Some("720"), hanging=Some("360")),
        ),
      ),
    ],
    "the paragraph writer cannot serialize indentation yet",
  )
  expect_unsupported(
    [
      @docx2html.paragraph(
        [@docx2html.run([@docx2html.text("x")])],
        properties=@docx2html.paragraph_properties(style_name=Some("Fancy")),
      ),
    ],
    "the paragraph writer needs a style id",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run([@docx2html.text("line one\r\nline two")]),
      ]),
    ],
    "the run writer cannot serialize raw line-break characters",
  )
  // SDK-valid reader-producible alignments are accepted now.
  let bytes = @docx2html.write_docx([
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("spread")])],
      properties=@docx2html.paragraph_properties(alignment=Some("start")),
    ),
  ])
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  // Legacy 'justify' stays rejected (the SDK rejects it too).
  expect_unsupported(
    [
      @docx2html.paragraph(
        [@docx2html.run([@docx2html.text("x")])],
        properties=@docx2html.paragraph_properties(alignment=Some("justify")),
      ),
    ],
    "unsupported paragraph alignment",
  )
}

///|
test "all-flags formatting round-trips exactly" {
  let body = [
    @docx2html.paragraph([
      @docx2html.run(
        [@docx2html.text("everything")],
        properties=@docx2html.run_properties(
          is_bold=true,
          is_italic=true,
          is_underline=true,
          is_strikethrough=true,
          is_all_caps=true,
          is_small_caps=true,
          vertical_alignment=Subscript,
          font=Some("Courier"),
          font_size=Some(9),
          highlight=Some("green"),
        ),
      ),
    ]),
  ]
  let result = @docx2html.read_docx_package(@docx2html.write_docx(body))
  guard result.document is Document(children~, ..)
  assert_eq(children, body)
}
