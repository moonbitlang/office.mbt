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
test "review round 3 (batch): XML-unrepresentable characters and highlight 'none' fail closed" {
  // A lone surrogate reaches the writer only via parsed input (MoonBit
  // literals cannot spell one), and U+FFFF is a valid scalar but outside
  // XML 1.0's character set.
  guard @json.parse("\"a\\ud800b\"") is String(lone_surrogate)
  expect_unsupported(
    [@docx2html.paragraph([@docx2html.run([@docx2html.text(lone_surrogate)])])],
    "text contains a character XML cannot represent (code 55296",
  )
  expect_unsupported(
    [@docx2html.paragraph([@docx2html.run([@docx2html.text("a\u{FFFF}b")])])],
    "text contains a character XML cannot represent (code 65535",
  )
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.hyperlink(
          [@docx2html.run([@docx2html.text("x")])],
          href=Some("https://a.example/\u{FFFF}"),
        ),
      ]),
    ],
    "a hyperlink href contains a character XML cannot represent",
  )
  // The reader normalizes highlight 'none' to absent, so writing it would
  // break write -> read symmetry.
  expect_unsupported(
    [
      @docx2html.paragraph([
        @docx2html.run(
          [@docx2html.text("x")],
          properties=@docx2html.run_properties(highlight=Some("none")),
        ),
      ]),
    ],
    "omit the highlight property instead of 'none'",
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

///|
fn note_body(text : String) -> Array[@docx2html.DocumentElement] {
  [@docx2html.paragraph([@docx2html.run([@docx2html.text(text)])])]
}

///|
/// Constructor-level and write-level comment failures both surface as
/// `Unsupported` with an agent-readable message.
fn[T] expect_comment_failure(
  action : () -> T raise @docx2html.DocxError,
  expected_prefix : String,
) -> Unit raise {
  try {
    let _ = action()
  } catch {
    Unsupported(message~) =>
      if !message.has_prefix(expected_prefix) {
        fail("unexpected message: \{message}")
      }
    err => fail("expected Unsupported, got \{repr(err)}")
  } noraise {
    _ => fail("expected the comment writer to fail closed")
  }
}

///|
test "K1: written comments round-trip through the annotation index" {
  let body = [
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("Alpha heading")])],
      properties=@docx2html.paragraph_properties(style_id=Some("Heading1")),
    ),
    @docx2html.paragraph([@docx2html.run([@docx2html.text("Bravo body")])]),
    @docx2html.paragraph([@docx2html.run([@docx2html.text("Charlie tail")])]),
  ]
  let bytes = @docx2html.write_docx_with_comments(body, [
    @docx2html.comment_spec(
      author="Reviewer",
      initials="R",
      date="2026-07-11T09:30:00Z",
      from=0,
      to=0,
      note_body("Point note on the heading"),
    ),
    @docx2html.comment_spec(author="Second Reviewer", from=1, to=2, [
      @docx2html.paragraph([@docx2html.run([@docx2html.text("Range note,")])]),
      @docx2html.paragraph([
        @docx2html.run([@docx2html.text("two paragraphs long.")]),
      ]),
    ]),
  ])
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let annotated = @docx2html.read_docx_annotated(bytes)
  // The agent-facing outline inventory: both comments, dense ids, no
  // diagnostics.
  guard @inspect.annotated_outline(annotated, file="c.docx") is Object(outline)
  json_inspect(outline.get("comments"), content=[
    [
      { "id": "0", "author": "Reviewer", "anchored_to": "/body/p[1]" },
      { "id": "1", "author": "Second Reviewer", "anchored_to": "/body/p[2]" },
    ],
  ])
  json_inspect(outline.get("messages"), content=[[]])
  // The point comment's full element payload: metadata and an anchor
  // wholly inside the styled from-paragraph.
  json_inspect(
    @inspect.annotated_element(
      annotated,
      file="c.docx",
      path="/comments/comment[@id=0]",
    ),
    content={
      "schema": "docx.element/1",
      "file": "c.docx",
      "path": "/comments/comment[@id=0]",
      "kind": "comment",
      "id": "0",
      "author": "Reviewer",
      "initials": "R",
      "date": "2026-07-11T09:30:00Z",
      "anchors": [
        {
          "story": "/body",
          "start": "/body/p[1]",
          "start_boundary": "inside_start",
          "end": "/body/p[1]",
          "end_boundary": "inside_end",
          "references": ["/body/p[1]/r[2]"],
        },
      ],
      "anchored_to": "/body/p[1]",
      "children": [{ "kind": "p", "path": "/comments/comment[@id=0]/p[1]" }],
    },
  )
  // The range comment: anchor spanning /body/p[2]../body/p[3], reference
  // attached to the end paragraph.
  json_inspect(
    @inspect.annotated_element(
      annotated,
      file="c.docx",
      path="/comments/comment[@id=1]",
    ),
    content={
      "schema": "docx.element/1",
      "file": "c.docx",
      "path": "/comments/comment[@id=1]",
      "kind": "comment",
      "id": "1",
      "author": "Second Reviewer",
      "anchors": [
        {
          "story": "/body",
          "start": "/body/p[2]",
          "start_boundary": "inside_start",
          "end": "/body/p[3]",
          "end_boundary": "inside_end",
          "references": ["/body/p[3]/r[2]"],
        },
      ],
      "anchored_to": "/body/p[2]",
      "children": [
        { "kind": "p", "path": "/comments/comment[@id=1]/p[1]" },
        { "kind": "p", "path": "/comments/comment[@id=1]/p[2]" },
      ],
    },
  )
  // Reverse link: a covered body paragraph names its covering comment.
  guard @inspect.annotated_element(annotated, file="c.docx", path="/body/p[2]")
    is Object(covered)
  json_inspect(covered.get("comment_ids"), content=[["1"]])
}

///|
test "K1: anchors are emitted in the canonical intra-paragraph shape" {
  let body = [
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("Styled")])],
      properties=@docx2html.paragraph_properties(style_id=Some("Heading2")),
    ),
  ]
  let bytes = @docx2html.write_docx_with_comments(body, [
    @docx2html.comment_spec(author="A", from=0, to=0, note_body("first")),
    @docx2html.comment_spec(
      author="B",
      initials="BB",
      date="2026-07-11T10:00:00Z",
      from=0,
      to=0,
      note_body("second"),
    ),
  ])
  let archive = @mbtzip.read(bytes)
  guard archive.get("word/document.xml") is Some(doc)
  let text = @utf8.decode(doc, ignore_bom=true)
  // Range starts sit right after pPr, in ascending id order.
  inspect(
    text.find(
      "</w:pPr><w:commentRangeStart w:id=\"0\"/><w:commentRangeStart w:id=\"1\"/>",
    )
    is Some(_),
    content="true",
  )
  // Each range end is immediately followed by ITS OWN reference run.
  inspect(
    text.find(
      "<w:commentRangeEnd w:id=\"0\"/><w:r><w:commentReference w:id=\"0\"/></w:r><w:commentRangeEnd w:id=\"1\"/><w:r><w:commentReference w:id=\"1\"/></w:r></w:p>",
    )
    is Some(_),
    content="true",
  )
  // Definitions: dense ids and verbatim metadata in word/comments.xml.
  guard archive.get("word/comments.xml") is Some(part)
  let comments_text = @utf8.decode(part, ignore_bom=true)
  inspect(
    comments_text.find("<w:comment w:id=\"0\" w:author=\"A\">") is Some(_),
    content="true",
  )
  // Attribute ORDER inside a tag is the XML writer's own (insignificant
  // per XML 1.0); pin all four attributes of the metadata-rich comment.
  inspect(
    comments_text.find(
      "<w:comment w:id=\"1\" w:date=\"2026-07-11T10:00:00Z\" w:author=\"B\" w:initials=\"BB\">",
    )
    is Some(_),
    content="true",
  )
  // The comments part hangs off the MAIN document part, found by type.
  guard archive.get("word/_rels/document.xml.rels") is Some(rels)
  inspect(
    @utf8.decode(rels, ignore_bom=true).find(
      "officeDocument/2006/relationships/comments",
    )
    is Some(_),
    content="true",
  )
  // No r: namespace was dragged into an otherwise plain document part
  // (the comments relationship is implicit, found by type not r:id).
  inspect(text.find("xmlns:r=") is Some(_), content="false")
}

///|
test "K1: an empty comment set is byte-identical to write_docx" {
  let body = [
    @docx2html.paragraph([@docx2html.run([@docx2html.text("plain")])]),
  ]
  inspect(
    @docx2html.write_docx(body) == @docx2html.write_docx_with_comments(body, []),
    content="true",
  )
}

///|
test "K1: comment specs and anchors fail closed" {
  let plain = [
    @docx2html.paragraph([@docx2html.run([@docx2html.text("body")])]),
  ]
  expect_comment_failure(
    () => @docx2html.comment_spec(author="", from=0, to=0, note_body("x")),
    "a comment needs a non-empty author",
  )
  expect_comment_failure(
    () => {
      @docx2html.comment_spec(
        author="A",
        initials="",
        from=0,
        to=0,
        note_body("x"),
      )
    },
    "comment initials must not be empty",
  )
  expect_comment_failure(
    () => {
      @docx2html.comment_spec(
        author="A",
        date="2026-02-29T00:00:00",
        from=0,
        to=0,
        note_body("x"),
      )
    },
    "the comment date '2026-02-29T00:00:00' has day 29",
  )
  expect_comment_failure(
    () => @docx2html.comment_spec(author="A", from=2, to=1, note_body("x")),
    "a comment anchor cannot end at block 1, before its start at block 2",
  )
  expect_comment_failure(
    () => @docx2html.comment_spec(author="A", from=0, to=0, []),
    "a comment needs a non-empty body",
  )
  expect_comment_failure(
    () => {
      @docx2html.comment_spec(author="A", from=0, to=0, [
        @docx2html.table([
          @docx2html.table_row([@docx2html.table_cell(note_body("x"))]),
        ]),
      ])
    },
    "comment bodies are paragraph-only in this writer",
  )
  // Write-time: anchors out of bounds or on a non-paragraph block.
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_comments(plain, [
        @docx2html.comment_spec(author="A", from=0, to=5, note_body("x")),
      ])
    },
    "comments[0] anchors blocks 0..5, but the body has 1 block(s)",
  )
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_comments(
        [
          @docx2html.table([
            @docx2html.table_row([@docx2html.table_cell(note_body("cell"))]),
          ]),
        ],
        [@docx2html.comment_spec(author="A", from=0, to=0, note_body("x"))],
      )
    },
    "comments[0] anchors block 0, which is not a paragraph",
  )
  // Write-time: relationship-bearing comment bodies (hyperlinks, images)
  // cannot be serialized into the comments part.
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_comments(plain, [
        @docx2html.comment_spec(author="A", from=0, to=0, [
          @docx2html.paragraph([
            @docx2html.hyperlink(
              [@docx2html.run([@docx2html.text("link")])],
              href=Some("https://example.com"),
            ),
          ]),
        ]),
      ])
    },
    "comment bodies are plain content",
  )
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_comments(plain, [
        @docx2html.comment_spec(author="A", from=0, to=0, [
          @docx2html.paragraph([
            @docx2html.run([@docx2html.image("image/png", tiny_png())]),
          ]),
        ]),
      ])
    },
    "comment bodies are plain content",
  )
}

///|
test "K1: a comment on an empty paragraph round-trips" {
  // The markers become the paragraph's ONLY children (blank target line):
  // still schema-valid, still indexed, reference run still r[1]. With no
  // content between them, BOTH boundaries classify as inside_start — the
  // index's honest reading of a zero-width range.
  let bytes = @docx2html.write_docx_with_comments([@docx2html.paragraph([])], [
    @docx2html.comment_spec(author="A", from=0, to=0, note_body("on blank")),
  ])
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let annotated = @docx2html.read_docx_annotated(bytes)
  guard @inspect.annotated_element(
      annotated,
      file="b.docx",
      path="/comments/comment[@id=0]",
    )
    is Object(payload)
  json_inspect(payload.get("anchors"), content=[
    [
      {
        "story": "/body",
        "start": "/body/p[1]",
        "start_boundary": "inside_start",
        "end": "/body/p[1]",
        "end_boundary": "inside_start",
        "references": ["/body/p[1]/r[1]"],
      },
    ],
  ])
}

///|
test "K1 review round 1: plain-content holes and aliasing fail closed" {
  let plain = [
    @docx2html.paragraph([@docx2html.run([@docx2html.text("body")])]),
  ]
  // An anchor-only hyperlink allocates NO relationship, so the
  // relationship-delta guard alone would let it through — the recursive
  // plain-content check must reject it at construction.
  expect_comment_failure(
    () => {
      @docx2html.comment_spec(author="A", from=0, to=0, [
        @docx2html.paragraph([
          @docx2html.hyperlink(
            [@docx2html.run([@docx2html.text("jump")])],
            anchor=Some("bookmark"),
          ),
        ]),
      ])
    },
    "comment bodies are plain content: hyperlinks",
  )
  // The recursion must see through EVERY child-bearing variant — a
  // hyperlink smuggled under a nested Document wrapper is still caught.
  expect_comment_failure(
    () => {
      @docx2html.comment_spec(author="A", from=0, to=0, [
        @docx2html.paragraph([
          @docx2html.document([
            @docx2html.hyperlink(
              [@docx2html.run([@docx2html.text("smuggled")])],
              anchor=Some("x"),
            ),
          ]),
        ]),
      ])
    },
    "comment bodies are plain content: hyperlinks",
  )
  // The body array stays caller-mutable after construction: emptying it
  // (or swapping a table in) through the alias must fail at WRITE time,
  // not silently emit an empty or non-paragraph comment.
  let aliased = [
    @docx2html.paragraph([@docx2html.run([@docx2html.text("note")])]),
  ]
  let spec = @docx2html.comment_spec(author="A", from=0, to=0, aliased)
  let _ = aliased.pop()
  expect_comment_failure(
    () => @docx2html.write_docx_with_comments(plain, [spec]),
    "comments[0]: a comment needs a non-empty body",
  )
  aliased.push(
    @docx2html.table([
      @docx2html.table_row([@docx2html.table_cell(note_body("cell"))]),
    ]),
  )
  expect_comment_failure(
    () => @docx2html.write_docx_with_comments(plain, [spec]),
    "comments[0]: comment bodies are paragraph-only in this writer",
  )
}

///|
test "K2: a threaded, resolved conversation round-trips through the index" {
  let body = [
    @docx2html.paragraph([@docx2html.run([@docx2html.text("Disputed claim")])]),
    @docx2html.paragraph([@docx2html.run([@docx2html.text("Unrelated tail")])]),
  ]
  let bytes = @docx2html.write_docx_with_comments(body, [
    // A multi-paragraph parent: the commentEx key must be the LAST
    // body paragraph's paraId (the locked, spec-backed choice).
    @docx2html.comment_spec(
      author="Ada",
      initials="A",
      date="2026-07-11T16:00:00Z",
      from=0,
      to=0,
      [
        @docx2html.paragraph([@docx2html.run([@docx2html.text("Check this,")])]),
        @docx2html.paragraph([@docx2html.run([@docx2html.text("please.")])]),
      ],
    ),
    @docx2html.comment_reply(
      author="Bob",
      reply_to=0,
      done=true,
      note_body("Verified and resolved."),
    ),
    // Chains: a reply answering a reply.
    @docx2html.comment_reply(
      author="Cid",
      reply_to=1,
      note_body("Confirming Bob's check."),
    ),
  ])
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let annotated = @docx2html.read_docx_annotated(bytes)
  guard @inspect.annotated_outline(annotated, file="t.docx") is Object(outline)
  json_inspect(outline.get("comments"), content=[
    [
      { "id": "0", "author": "Ada", "done": false, "anchored_to": "/body/p[1]" },
      { "id": "1", "author": "Bob", "done": true, "parent_id": "0" },
      { "id": "2", "author": "Cid", "done": false, "parent_id": "1" },
    ],
  ])
  json_inspect(outline.get("messages"), content=[[]])
  // The reply carries threading metadata but NO anchors of its own.
  json_inspect(
    @inspect.annotated_element(
      annotated,
      file="t.docx",
      path="/comments/comment[@id=1]",
    ),
    content={
      "schema": "docx.element/1",
      "file": "t.docx",
      "path": "/comments/comment[@id=1]",
      "kind": "comment",
      "id": "1",
      "author": "Bob",
      "done": true,
      "parent_id": "0",
      "anchors": [],
      "children": [{ "kind": "p", "path": "/comments/comment[@id=1]/p[1]" }],
    },
  )
  // Byte level: the parent's commentEx key is its SECOND paragraph's
  // paraId; the reply links via paraIdParent; done round-trips.
  let archive = @mbtzip.read(bytes)
  guard archive.get("word/comments.xml") is Some(comments_part)
  let comments_text = @utf8.decode(comments_part, ignore_bom=true)
  inspect(comments_text.find("mc:Ignorable=\"w14\"") is Some(_), content="true")
  // Dense paraIds: parent paragraphs 1+2, reply bodies 3 and 4.
  for
    stamp in [
      "w14:paraId=\"00000001\"", "w14:paraId=\"00000002\"", "w14:paraId=\"00000003\"",
      "w14:paraId=\"00000004\"",
    ] {
    inspect(comments_text.find(stamp) is Some(_), content="true")
  }
  guard archive.get("word/commentsExtended.xml") is Some(extended_part)
  let extended_text = @utf8.decode(extended_part, ignore_bom=true)
  inspect(extended_text.find("mc:Ignorable=\"w15\"") is Some(_), content="true")
  inspect(
    extended_text.find(
      "<w15:commentEx w15:done=\"0\" w15:paraId=\"00000002\"/>",
    )
    is Some(_),
    content="true",
  )
  inspect(
    extended_text.find(
      "<w15:commentEx w15:done=\"1\" w15:paraId=\"00000003\" w15:paraIdParent=\"00000002\"/>",
    )
    is Some(_),
    content="true",
  )
  inspect(
    extended_text.find(
      "<w15:commentEx w15:done=\"0\" w15:paraId=\"00000004\" w15:paraIdParent=\"00000003\"/>",
    )
    is Some(_),
    content="true",
  )
  // Replies are anchorless: only the parent's markers exist in the body.
  guard archive.get("word/document.xml") is Some(doc)
  let text = @utf8.decode(doc, ignore_bom=true)
  inspect(text.find("commentRangeStart w:id=\"1\"") is Some(_), content="false")
  inspect(text.find("commentReference w:id=\"1\"") is Some(_), content="false")
  inspect(text.find("commentReference w:id=\"2\"") is Some(_), content="false")
  inspect(text.find("commentReference w:id=\"0\"") is Some(_), content="true")
}

///|
test "K2: threading-free output stays byte-identical to the K1 writer" {
  // No reply, no done anywhere: no w14 stamps, no commentsExtended part.
  let bytes = @docx2html.write_docx_with_comments(
    [@docx2html.paragraph([@docx2html.run([@docx2html.text("plain")])])],
    [@docx2html.comment_spec(author="A", from=0, to=0, note_body("note"))],
  )
  let archive = @mbtzip.read(bytes)
  inspect(archive.get("word/commentsExtended.xml") is Some(_), content="false")
  guard archive.get("word/comments.xml") is Some(part)
  inspect(
    @utf8.decode(part, ignore_bom=true).find("w14") is Some(_),
    content="false",
  )
}

///|
test "K2: reply targets fail closed" {
  let plain = [
    @docx2html.paragraph([@docx2html.run([@docx2html.text("body")])]),
  ]
  expect_comment_failure(
    () => @docx2html.comment_reply(author="A", reply_to=-1, note_body("x")),
    "a reply cannot answer comment -1; comment indexes are 0-based",
  )
  // Self- and forward references are write-time failures (the array is
  // only known there).
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_comments(plain, [
        @docx2html.comment_spec(author="A", from=0, to=0, note_body("n")),
        @docx2html.comment_reply(author="B", reply_to=1, note_body("r")),
      ])
    },
    "comments[1] replies to comment 1, which is not an EARLIER comment",
  )
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_comments(plain, [
        @docx2html.comment_reply(author="B", reply_to=0, note_body("r")),
      ])
    },
    "comments[0] replies to comment 0, which is not an EARLIER comment",
  )
}

///|
test "K2: resolve-without-reply triggers the extended part on its own" {
  // A single anchored comment with done=true and no replies anywhere:
  // the resolution alone brings in paraId stamping and commentsExtended
  // (with no paraIdParent in the file at all).
  let bytes = @docx2html.write_docx_with_comments(
    [@docx2html.paragraph([@docx2html.run([@docx2html.text("done deal")])])],
    [
      @docx2html.comment_spec(
        author="A",
        from=0,
        to=0,
        done=true,
        note_body("all addressed"),
      ),
    ],
  )
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let archive = @mbtzip.read(bytes)
  guard archive.get("word/commentsExtended.xml") is Some(part)
  let extended_text = @utf8.decode(part, ignore_bom=true)
  inspect(
    extended_text.find(
      "<w15:commentEx w15:done=\"1\" w15:paraId=\"00000001\"/>",
    )
    is Some(_),
    content="true",
  )
  inspect(extended_text.find("paraIdParent") is Some(_), content="false")
  let annotated = @docx2html.read_docx_annotated(bytes)
  let index = annotated.annotations()
  debug_inspect(index.comments()[0].done(), content="Some(true)")
  debug_inspect(index.comments()[0].parent_id(), content="None")
  debug_inspect(index.warnings(), content="[]")
}

///|
test "K3: written footnotes and endnotes round-trip through the index" {
  let body = [
    @docx2html.paragraph([
      @docx2html.run([
        @docx2html.text("Cited claim"),
        @docx2html.note_reference("footnote", "0"),
      ]),
      @docx2html.run([
        @docx2html.text(" and another"),
        @docx2html.note_reference("footnote", "1"),
      ]),
    ]),
    @docx2html.paragraph([
      @docx2html.run([
        @docx2html.text("Closing remark"),
        @docx2html.note_reference("endnote", "0"),
      ]),
    ]),
  ]
  let bytes = @docx2html.write_docx_with_annotations(
    body,
    footnotes=[
      @docx2html.note_spec(note_body("First source.")),
      @docx2html.note_spec([
        @docx2html.paragraph([@docx2html.run([@docx2html.text("Second,")])]),
        @docx2html.paragraph([
          @docx2html.run([@docx2html.text("longer source.")]),
        ]),
      ]),
    ],
    endnotes=[@docx2html.note_spec(note_body("The endnote."))],
  )
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  let annotated = @docx2html.read_docx_annotated(bytes)
  guard @inspect.annotated_outline(annotated, file="n.docx") is Object(outline)
  json_inspect(outline.get("messages"), content=[[]])
  json_inspect(outline.get("counts"), content=[
    {
      "paragraphs": 2,
      "tables": 0,
      "images": 0,
      "hyperlinks": 0,
      "bookmarks": 0,
      "footnotes": 2,
      "endnotes": 1,
      "comments": 0,
      "headers": 0,
      "footers": 0,
      "sections": 1,
    },
  ])
  // The index: ids are index+1, references point at the body runs.
  let index = annotated.annotations()
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(index.footnotes().length(), content="2")
  debug_inspect(index.endnotes().length(), content="1")
  debug_inspect(
    index.footnotes()[0].id(),
    content=(
      #|"1"
    ),
  )
  json_inspect(index.footnotes()[0].references().to_json(), content=[
    "/body/p[1]/r[1]",
  ])
  json_inspect(index.footnotes()[1].references().to_json(), content=[
    "/body/p[1]/r[2]",
  ])
  // Note bodies are readable stories.
  guard @inspect.annotated_element(
      annotated,
      file="n.docx",
      path="/footnotes/note[@id=2]/p[2]",
    )
    is Object(second_para)
  json_inspect(second_para.get("text"), content=["longer source."])
  // Byte level: plumbing ids -1/0, content ids from 1, the in-note mark
  // run heading the first paragraph.
  let archive = @mbtzip.read(bytes)
  guard archive.get("word/footnotes.xml") is Some(part)
  let text = @utf8.decode(part, ignore_bom=true)
  inspect(
    text.find("w:type=\"separator\" w:id=\"-1\"") is Some(_) ||
    text.find("w:id=\"-1\" w:type=\"separator\"") is Some(_),
    content="true",
  )
  inspect(
    text.find("<w:footnote w:id=\"1\"><w:p><w:r><w:footnoteRef/></w:r>")
    is Some(_),
    content="true",
  )
  guard archive.get("word/endnotes.xml") is Some(endnote_part)
  inspect(
    @utf8.decode(endnote_part, ignore_bom=true).find(
      "<w:endnote w:id=\"1\"><w:p><w:r><w:endnoteRef/></w:r>",
    )
    is Some(_),
    content="true",
  )
}

///|
test "K3: note references and bodies fail closed" {
  let plain = [
    @docx2html.paragraph([@docx2html.run([@docx2html.text("body")])]),
  ]
  // Unreferenced and doubly-referenced notes.
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_annotations(plain, footnotes=[
        @docx2html.note_spec(note_body("orphan")),
      ])
    },
    "footnotes[0] is never referenced from the body",
  )
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_annotations(
        [
          @docx2html.paragraph([
            @docx2html.run([
              @docx2html.note_reference("footnote", "0"),
              @docx2html.note_reference("footnote", "0"),
            ]),
          ]),
        ],
        footnotes=[@docx2html.note_spec(note_body("twice"))],
      )
    },
    "footnotes[0] is referenced 2 times",
  )
  // Dangling references (bad index, wrong kind, junk id).
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_annotations(
        [
          @docx2html.paragraph([
            @docx2html.run([@docx2html.note_reference("footnote", "1")]),
          ]),
        ],
        footnotes=[@docx2html.note_spec(note_body("only one"))],
      )
    },
    "the footnote reference '1' does not name a supplied note",
  )
  expect_comment_failure(
    () => {
      @docx2html.write_docx_with_annotations(
        [
          @docx2html.paragraph([
            @docx2html.run([@docx2html.note_reference("endnote", "0")]),
          ]),
        ],
        footnotes=[@docx2html.note_spec(note_body("wrong kind"))],
      )
    },
    "the endnote reference '0' does not name a supplied note",
  )
  // Plain write_docx (no notes supplied) refuses dangling references.
  expect_comment_failure(
    () => {
      @docx2html.write_docx([
        @docx2html.paragraph([
          @docx2html.run([@docx2html.note_reference("footnote", "0")]),
        ]),
      ])
    },
    "the footnote reference '0' does not name a supplied note",
  )
  // Nested notes and notes in comments.
  expect_comment_failure(
    () => {
      @docx2html.note_spec([
        @docx2html.paragraph([
          @docx2html.run([@docx2html.note_reference("footnote", "0")]),
        ]),
      ])
    },
    "note bodies cannot carry note references",
  )
  expect_comment_failure(
    () => {
      @docx2html.comment_spec(author="A", from=0, to=0, [
        @docx2html.paragraph([
          @docx2html.run([@docx2html.note_reference("endnote", "0")]),
        ]),
      ])
    },
    "comment bodies cannot carry note references",
  )
}
