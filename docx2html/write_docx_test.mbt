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
    "the table writer cannot serialize an empty table",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.hyperlink(
          [@docx2html.run([@docx2html.text("x")])],
          href=Some("https://example.com/page"),
          anchor=Some("frag"),
        ),
      ]),
    ],
    "a hyperlink with both href and anchor cannot round-trip",
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
    "list levels must be 1..9 (got 0)",
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
    "could not read the image's dimensions from its image/png header",
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

///|
test "tables round-trip: header rows, column spans, and row spans" {
  let body = [
    @docx2html.table([
      @docx2html.table_row(
        [
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("Name")])]),
          ]),
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("Value")])]),
          ]),
        ],
        is_header=true,
      ),
      @docx2html.table_row([
        @docx2html.table_cell(
          [@docx2html.paragraph([@docx2html.run([@docx2html.text("wide")])])],
          col_span=2,
        ),
      ]),
      @docx2html.table_row([
        @docx2html.table_cell(
          [@docx2html.paragraph([@docx2html.run([@docx2html.text("tall")])])],
          row_span=2,
        ),
        @docx2html.table_cell([
          @docx2html.paragraph([@docx2html.run([@docx2html.text("b1")])]),
        ]),
      ]),
      @docx2html.table_row([
        @docx2html.table_cell([
          @docx2html.paragraph([@docx2html.run([@docx2html.text("b2")])]),
        ]),
      ]),
    ]),
  ]
  let bytes = @docx2html.write_docx(body)
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let result = @docx2html.read_docx_package(bytes)
  debug_inspect(result.messages, content="[]")
  // The reader strips vMerge continuation cells and reconstructs row_span —
  // exactly the input body.
  guard result.document is Document(children~, ..)
  assert_eq(children, body)
}

///|
test "the table writer fails closed on malformed shapes" {
  expect_unsupported(
    [
      @docx2html.table([
        @docx2html.table_row([
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("a")])]),
          ]),
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("b")])]),
          ]),
        ]),
        @docx2html.table_row([
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("only")])]),
          ]),
        ]),
      ]),
    ],
    "row 2 covers 1 of 2 grid column(s); ragged tables are not serializable",
  )
  expect_unsupported(
    [
      @docx2html.table([
        @docx2html.table_row([
          @docx2html.table_cell(
            [@docx2html.paragraph([@docx2html.run([@docx2html.text("x")])])],
            row_span=3,
          ),
        ]),
      ]),
    ],
    "a row span of 3 starting at row 1 exceeds the table's 1 row(s)",
  )
  expect_unsupported(
    [
      @docx2html.table([
        @docx2html.paragraph([@docx2html.run([@docx2html.text("stray")])]),
      ]),
    ],
    "a table can only contain rows; cannot serialize: paragraph",
  )
  expect_unsupported(
    [
      @docx2html.table(
        [
          @docx2html.table_row([
            @docx2html.table_cell([
              @docx2html.paragraph([@docx2html.run([@docx2html.text("x")])]),
            ]),
          ]),
        ],
        properties=@docx2html.table_properties(style_id=Some("TableGrid")),
      ),
    ],
    "the table writer cannot serialize table styles yet",
  )
}

///|
test "review round 1 (F2): merge-overlap rejection and the empty-cell asymmetry" {
  // A colspan striding over a pending merge column must be rejected —
  // silently writing it misplaces the vMerge continuation into a later row
  // (schema-valid, masked by the reader's reconstruction, wrong in Word).
  expect_unsupported(
    [
      @docx2html.table([
        @docx2html.table_row([
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("A")])]),
          ]),
          @docx2html.table_cell(
            [@docx2html.paragraph([@docx2html.run([@docx2html.text("B")])])],
            row_span=2,
          ),
        ]),
        @docx2html.table_row([
          @docx2html.table_cell(
            [@docx2html.paragraph([@docx2html.run([@docx2html.text("C")])])],
            col_span=2,
          ),
        ]),
        @docx2html.table_row([
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("D")])]),
          ]),
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("E")])]),
          ]),
        ]),
      ]),
    ],
    "row 2: a cell spanning columns 1..2 collides with a vertical merge at column 2",
  )
  // A table with rows but no cells anywhere is degenerate.
  expect_unsupported(
    [@docx2html.table([@docx2html.table_row([])])],
    "the table writer cannot serialize a table with no cells",
  )
  // DELIBERATE ASYMMETRY (like F1's style-name enrichment): an empty cell
  // is written with the schema-required empty paragraph, so it reads back
  // normalized as a cell containing one empty paragraph.
  let body = [
    @docx2html.table([
      @docx2html.table_row([
        @docx2html.table_cell([]),
        @docx2html.table_cell([
          @docx2html.paragraph([@docx2html.run([@docx2html.text("x")])]),
        ]),
      ]),
    ]),
  ]
  let result = @docx2html.read_docx_package(@docx2html.write_docx(body))
  guard result.document is Document(children~, ..)
  guard children is [Table(children=rows, ..)]
  guard rows is [TableRow(children=cells, ..)]
  guard cells is [TableCell(children=first_cell, ..), _]
  debug_inspect(
    first_cell,
    content=(
      #|[
      #|  Paragraph(
      #|    children=[],
      #|    properties={
      #|      style_id: None,
      #|      style_name: None,
      #|      numbering: None,
      #|      alignment: None,
      #|      indent: { start: None, end: None, first_line: None, hanging: None },
      #|    },
      #|  ),
      #|]
    ),
  )
}

///|
test "lists round-trip: ordered and unordered at several levels" {
  let body = [
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("first")])],
      properties=@docx2html.paragraph_properties(
        numbering=Some(@docx2html.numbering(true, 1)),
      ),
    ),
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("nested bullet")])],
      properties=@docx2html.paragraph_properties(
        numbering=Some(@docx2html.numbering(false, 2)),
      ),
    ),
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("deep ordered")])],
      properties=@docx2html.paragraph_properties(
        numbering=Some(@docx2html.numbering(true, 9)),
      ),
    ),
    @docx2html.paragraph([@docx2html.run([@docx2html.text("plain after")])]),
  ]
  let bytes = @docx2html.write_docx(body)
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let result = @docx2html.read_docx_package(bytes)
  debug_inspect(result.messages, content="[]")
  guard result.document is Document(children~, ..)
  assert_eq(children, body)
  // The converter renders the shallow levels as real lists; its deep-level
  // fallback to a plain paragraph for level 9 is pre-existing Mammoth
  // parity, pinned here as documentation.
  inspect(
    @docx2html.convert_to_html(bytes).value,
    content=(
      #|<ol><li>first<ul><li>nested bullet</li></ul></li></ol><p>deep ordered</p><p>plain after</p>
    ),
  )
}

///|
test "list levels outside 1..9 fail closed" {
  expect_unsupported(
    [
      @docx2html.paragraph(
        [@docx2html.run([@docx2html.text("x")])],
        properties=@docx2html.paragraph_properties(
          numbering=Some(@docx2html.numbering(false, 10)),
        ),
      ),
    ],
    "list levels must be 1..9 (got 10)",
  )
}

///|
/// The 10x10 PNG the reader fixtures use (base64 from tiny-picture).
fn tiny_png() -> Bytes {
  try! @base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII=",
    ignore_whitespace=true,
  )
}

///|
test "hyperlinks and images round-trip" {
  let body = [
    @docx2html.paragraph([
      @docx2html.hyperlink(
        [@docx2html.run([@docx2html.text("visit")])],
        href=Some("https://example.com/page"),
      ),
      @docx2html.hyperlink(
        [@docx2html.run([@docx2html.text("jump")])],
        anchor=Some("section2"),
        target_frame=Some("_blank"),
      ),
    ]),
    @docx2html.paragraph([
      @docx2html.run([
        @docx2html.image("image/png", tiny_png(), alt_text=Some("dot grid")),
      ]),
    ]),
  ]
  let bytes = @docx2html.write_docx(body)
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let result = @docx2html.read_docx_package(bytes)
  debug_inspect(result.messages, content="[]")
  guard result.document is Document(children~, ..)
  assert_eq(children, body)
  // The converter emits a data-URI img and a real link.
  inspect(
    @docx2html.convert_to_html(bytes).value,
    content=(
      #|<p><a href="https://example.com/page">visit</a><a href="#section2" target="_blank">jump</a></p><p><img alt="dot grid" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAAXNSR0IArs4c6QAAAAlwSFlzAAAOvgAADr4B6kKxwAAAABNJREFUKFNj/M+ADzDhlWUYqdIAQSwBE8U+X40AAAAASUVORK5CYII=" /></p>
    ),
  )
}

///|
test "image dimensions are parsed from real headers" {
  // tiny_png is 10x10: wp:extent must carry 10 * 9525 EMUs.
  let bytes = @docx2html.write_docx([
    @docx2html.paragraph([
      @docx2html.run([@docx2html.image("image/png", tiny_png())]),
    ]),
  ])
  let archive = @mbtzip.read(bytes)
  guard archive.get("word/document.xml") is Some(doc)
  let text = @utf8.decode(doc, ignore_bom=true)
  inspect(text.find("cx=\"95250\" cy=\"95250\"") is Some(_), content="true")
}

///|
test "F4 review round 1: empty metadata and malformed headers fail closed" {
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.hyperlink(
          [@docx2html.run([@docx2html.text("x")])],
          anchor=Some(""),
        ),
      ]),
    ],
    "a hyperlink anchor must not be empty",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.hyperlink(
          [@docx2html.run([@docx2html.text("x")])],
          href=Some("https://example.com"),
          target_frame=Some(""),
        ),
      ]),
    ],
    "a hyperlink target frame must not be empty",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run([
          @docx2html.image("image/png", tiny_png(), alt_text=Some("  ")),
        ]),
      ]),
    ],
    "image alt text must not be blank",
  )
  // Wrong PNG signature tail (bytes 4..8) and truncated GIF both fail.
  let bad_png = Bytes::from_array(tiny_png().to_array())
  let mutated = bad_png.to_array()
  mutated[5] = b'X'
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run([
          @docx2html.image("image/png", Bytes::from_array(mutated)),
        ]),
      ]),
    ],
    "could not read the image's dimensions",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run([
          @docx2html.image("image/gif", b"GIFxxx\x0a\x00\x0a\x00\x00\x00\x00"),
        ]),
      ]),
    ],
    "could not read the image's dimensions",
  )
  // A JPEG whose SOF segment declares too little length for the dimension
  // bytes is rejected (segment-bounded scan).
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run([
          @docx2html.image(
            "image/jpeg", b"\xff\xd8\xff\xc0\x00\x02\x08\x00\x0a\x00\x14",
          ),
        ]),
      ]),
    ],
    "could not read the image's dimensions",
  )
}

///|
test "multiple images and images inside hyperlinks and cells round-trip" {
  let body = [
    @docx2html.paragraph([
      @docx2html.hyperlink(
        [@docx2html.run([@docx2html.image("image/png", tiny_png())])],
        href=Some("https://example.com/img"),
      ),
      @docx2html.run([
        @docx2html.image("image/png", tiny_png(), alt_text=Some("second")),
      ]),
    ]),
    @docx2html.table([
      @docx2html.table_row([
        @docx2html.table_cell([
          @docx2html.paragraph([
            @docx2html.run([@docx2html.image("image/png", tiny_png())]),
          ]),
        ]),
      ]),
    ]),
  ]
  let bytes = @docx2html.write_docx(body)
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let result = @docx2html.read_docx_package(bytes)
  debug_inspect(result.messages, content="[]")
  guard result.document is Document(children~, ..)
  assert_eq(children, body)
  // Three distinct media parts were emitted.
  let archive = @mbtzip.read(bytes)
  let mut media_count = 0
  for entry in archive.entries() {
    if entry.name().has_prefix("word/media/") {
      media_count += 1
    }
  }
  debug_inspect(media_count, content="3")
}

///|
test "F4 round 2: wide-image extents and direct header truncation pins" {
  // A 300,000 px wide "PNG" (header-only bytes: the writer sizes from the
  // header and stores the part verbatim). 300000 * 9525 = 2,857,500,000 —
  // above the 32-bit Int overflow threshold the Int64 fix removed.
  let wide = b"\x89PNG\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x04\x93\xe0\x00\x00\x00\x01"
  let bytes = @docx2html.write_docx([
    @docx2html.paragraph([@docx2html.run([@docx2html.image("image/png", wide)])]),
  ])
  let archive = @mbtzip.read(bytes)
  guard archive.get("word/document.xml") is Some(doc)
  let text = @utf8.decode(doc, ignore_bom=true)
  inspect(text.find("cx=\"2857500000\"") is Some(_), content="true")
  // PNG whose IHDR length field is not 13 is rejected.
  let bad_ihdr_len = b"\x89PNG\x0d\x0a\x1a\x0a\x00\x00\x00\x0e\x49\x48\x44\x52\x00\x00\x00\x0a\x00\x00\x00\x0a"
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run([@docx2html.image("image/png", bad_ihdr_len)]),
      ]),
    ],
    "could not read the image's dimensions",
  )
  // A GIF cut off mid logical-screen-descriptor (12 bytes < 13) is rejected
  // even with a valid GIF89a signature.
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run([
          @docx2html.image("image/gif", b"GIF89a\x0a\x00\x0a\x00\x00\x00"),
        ]),
      ]),
    ],
    "could not read the image's dimensions",
  )
}

///|
test "review round 2 (batch): writer fails closed on invalid run property values" {
  // w:highlight/@w:val is the closed ST_HighlightColor enum.
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run(
          [@docx2html.text("x")],
          properties=@docx2html.run_properties(highlight=Some("banana")),
        ),
      ]),
    ],
    "unsupported highlight color 'banana'",
  )
  // ST_HpsMeasure is positive and Word caps font size at 1638pt.
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run(
          [@docx2html.text("x")],
          properties=@docx2html.run_properties(font_size=Some(0)),
        ),
      ]),
    ],
    "font size 0pt is outside the supported range",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run(
          [@docx2html.text("x")],
          properties=@docx2html.run_properties(font_size=Some(1639)),
        ),
      ]),
    ],
    "font size 1639pt is outside the supported range",
  )
  // C0 controls (other than tab) are XML-1.0-illegal in text and the
  // escaper would pass them through.
  expect_unsupported(
    [@docx2html.paragraph([@docx2html.run([@docx2html.text("a\u{01}b")])])],
    "text contains an XML-illegal control character (code 1)",
  )
  // Attribute-destined strings reject ALL C0 controls (attribute-value
  // normalization mutates even tab).
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run(
          [@docx2html.text("x")],
          properties=@docx2html.run_properties(font=Some("Arial\tBlack")),
        ),
      ]),
    ],
    "a run font name contains a control character",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.hyperlink(
          [@docx2html.run([@docx2html.text("x")])],
          href=Some(""),
        ),
      ]),
    ],
    "a hyperlink href must not be empty",
  )
}

///|
test "review round 2 (batch): the table writer bounds the grid at Word's 63 columns" {
  fn cell_with(span : Int) -> @docx2html.DocumentElement {
    @docx2html.table_cell(
      [@docx2html.paragraph([@docx2html.run([@docx2html.text("x")])])],
      col_span=span,
    )
  }

  // 63 columns is fine...
  let ok = @docx2html.write_docx([
    @docx2html.table([@docx2html.table_row([cell_with(63)])]),
  ])
  debug_inspect(ok.length() > 0, content="true")
  // ...64 (and astronomically large spans that would loop for hours) fail.
  expect_unsupported(
    [@docx2html.table([@docx2html.table_row([cell_with(64)])])],
    "a table row spans more than 63 grid columns",
  )
  expect_unsupported(
    [
      @docx2html.table([
        @docx2html.table_row([cell_with(2147483647), cell_with(2147483647)]),
      ]),
    ],
    "a table row spans more than 63 grid columns",
  )
}

///|
test "review round 2 (batch): a batch-built document reads back with the scripted semantics" {
  // End-to-end symmetry pin: script -> parse_batch -> build_body ->
  // write_docx -> read_docx_package, asserting the AST (not just SDK
  // validity) matches what the script said.
  let script = @batch.parse_batch(
    @json.parse(
      (
        #|{
        #|  "schema": "docx.batch/1",
        #|  "ops": [
        #|    {"op": "paragraph", "params": {"text": "Title", "style": "Heading2"}},
        #|    {"op": "paragraph", "params": {"align": "center", "runs": [
        #|      {"text": "loud", "bold": true, "all_caps": true, "size": 14, "highlight": "yellow"},
        #|      {"text": "down", "vertical": "subscript"},
        #|      {"link": {"href": "https://example.com/x", "runs": [{"text": "styled", "italic": true}]}}
        #|    ]}},
        #|    {"op": "paragraph", "params": {"text": "third item", "list": {"ordered": true, "level": 3}}},
        #|    {"op": "table", "params": {"header_rows": 1, "rows": [
        #|      [{"text": "A"}, {"text": "B"}],
        #|      [{"text": "wide", "col_span": 2}]
        #|    ]}}
        #|  ]
        #|}
      ),
    ),
  )
  let bytes = @docx2html.write_docx(script.build_body(Map([])))
  let result = @docx2html.read_docx_package(bytes)
  debug_inspect(result.messages.length(), content="0")
  guard result.document is Document(children~, ..)
  guard children
    is [
      Paragraph(properties=title_props, ..),
      Paragraph(children=styled_children, properties=styled_props),
      Paragraph(properties=list_props, ..),
      Table(children=table_rows, ..),
    ]
  debug_inspect(title_props.style_id, content="Some(\"Heading2\")")
  // Style names are enriched from the styles part on read (the one
  // documented write/read asymmetry this test tolerates).
  debug_inspect(title_props.style_name, content="Some(\"heading 2\")")
  debug_inspect(styled_props.alignment, content="Some(\"center\")")
  guard styled_children
    is [
      Run(properties=loud, ..),
      Run(properties=down, ..),
      Hyperlink(children=link_children, href=link_href, ..),
    ]
  debug_inspect(loud.is_bold, content="true")
  debug_inspect(loud.is_all_caps, content="true")
  debug_inspect(loud.font_size, content="Some(14)")
  debug_inspect(loud.highlight, content="Some(\"yellow\")")
  debug_inspect(to_repr(down.vertical_alignment), content="Subscript")
  debug_inspect(link_href, content="Some(\"https://example.com/x\")")
  guard link_children is [Run(properties=link_run, ..)]
  debug_inspect(link_run.is_italic, content="true")
  debug_inspect(
    list_props.numbering,
    content=(
      #|Some({ is_ordered: true, level: 3 })
    ),
  )
  guard table_rows
    is [
      TableRow(children=header_cells, is_header=header_flag),
      TableRow(children=data_cells, ..),
    ]
  debug_inspect(header_flag, content="true")
  debug_inspect(header_cells.length(), content="2")
  guard data_cells is [TableCell(col_span~, ..)]
  debug_inspect(col_span, content="2")
}
