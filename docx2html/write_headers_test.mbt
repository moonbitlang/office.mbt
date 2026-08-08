// #95 write side: header/footer stories and live page-number fields.
//
// What these pin, in order: the emitted package shape (parts, content types,
// relationships, sectPr references), reader/writer SYMMETRY for the header
// story (`read(write(x)) == x`), the complex-field run structure (a live
// field, not static text), the OOXML flags that make `first` and `even`
// actually take effect in Word, the fail-closed refusals, and — the
// regression that matters most — that a story-free write is BYTE-IDENTICAL
// to the pre-#95 writer.

///|
fn story_paragraph(text : String) -> @document.DocumentElement {
  @docx2html.paragraph([@docx2html.run([@docx2html.text(text)])])
}

///|
fn part_text(bytes : Bytes, name : String) -> String raise {
  let archive = @mbtzip.read(bytes)
  guard archive.get(name) is Some(part) else {
    fail("expected the package to hold \{name}")
  }
  @utf8.decode(part, ignore_bom=true)
}

///|
/// The package manifest, sorted: the archive's own entry order is an
/// implementation detail, WHICH parts exist is what these tests are about.
fn part_names(bytes : Bytes) -> String raise {
  let names : Array[String] = []
  for entry in @mbtzip.read(bytes).entries() {
    names.push(entry.name())
  }
  for i in 1..<names.length() {
    let value = names[i]
    let mut j = i - 1
    while j >= 0 && names[j] > value {
      names[j + 1] = names[j]
      j -= 1
    }
    names[j + 1] = value
  }
  names.join("\n")
}

///|
/// The document's `w:sectPr` element, verbatim, so the reference order and
/// the CT_SectPr child sequence can be pinned exactly.
fn section_properties(bytes : Bytes) -> String raise {
  let document = part_text(bytes, "word/document.xml")
  guard document.find("<w:sectPr>") is Some(start) else {
    fail("expected a sectPr in document.xml")
  }
  guard document.find("</w:sectPr>") is Some(end) else {
    fail("expected a sectPr end tag in document.xml")
  }
  document[start:end + "</w:sectPr>".length()].to_owned()
}

///|
test "a header and a footer land in their own parts, wired end to end" {
  let bytes = @docx2html.write_docx_with_annotations(
    [story_paragraph("body")],
    headers=[
      @docx2html.header_footer_spec(variant="default", [
        story_paragraph("Quarterly Report"),
      ]),
    ],
    footers=[
      @docx2html.header_footer_spec(variant="default", [
        story_paragraph("Confidential"),
      ]),
    ],
  )
  inspect(
    part_names(bytes),
    content=(
      #|_rels/.rels
      #|word/styles.xml
      #|word/footer1.xml
      #|word/header1.xml
      #|word/document.xml
      #|[Content_Types].xml
      #|word/_rels/document.xml.rels
    ),
  )
  inspect(
    part_text(bytes, "word/header1.xml"),
    content=(
      #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>Quarterly Report</w:t></w:r></w:p></w:hdr>
    ),
  )
  inspect(
    part_text(bytes, "word/footer1.xml"),
    content=(
      #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>Confidential</w:t></w:r></w:p></w:ftr>
    ),
  )
  // The sectPr references come FIRST (CT_SectPr is an enforced sequence) and
  // name the relationship ids allocated for the parts.
  inspect(
    section_properties(bytes),
    content=(
      #|<w:sectPr><w:headerReference r:id="rId3" w:type="default"/><w:footerReference r:id="rId4" w:type="default"/><w:pgSz w:h="15840" w:w="12240"/><w:pgMar w:top="1440" w:left="1440" w:right="1440" w:bottom="1440" w:footer="720" w:gutter="0" w:header="720"/></w:sectPr>
    ),
  )
  // Content types and relationships agree with the references.
  let content_types = part_text(bytes, "[Content_Types].xml")
  inspect(
    content_types.find(
      "PartName=\"/word/header1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml\"",
    )
    is Some(_),
    content="true",
  )
  inspect(
    content_types.find(
      "PartName=\"/word/footer1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml\"",
    )
    is Some(_),
    content="true",
  )
  let rels = part_text(bytes, "word/_rels/document.xml.rels")
  inspect(
    rels.find(
      "Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"",
    )
    is Some(_),
    content="true",
  )
  inspect(
    rels.find(
      "Id=\"rId4\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"",
    )
    is Some(_),
    content="true",
  )
  // The package passes the structural validity tier.
  inspect(@opc.validate_docx_package(bytes).length(), content="0")
}

///|
test "#95 round-trip symmetry: read(write(x)) == x for the header story" {
  let header_body = [
    story_paragraph("Quarterly Report"),
    @docx2html.paragraph(
      [
        @docx2html.run(
          [@docx2html.text("Q3")],
          properties=@document.run_properties(is_bold=true),
        ),
      ],
      properties=@document.paragraph_properties(alignment=Some("right")),
    ),
  ]
  let footer_body = [story_paragraph("Confidential")]
  let bytes = @docx2html.write_docx_with_annotations(
    [story_paragraph("body")],
    headers=[@docx2html.header_footer_spec(variant="default", header_body)],
    footers=[@docx2html.header_footer_spec(variant="default", footer_body)],
  )
  let read = @docx2html.read_docx_package(bytes)
  debug_inspect(read.messages, content="[]")
  assert_eq(read.headers.length(), 1)
  assert_eq(read.footers.length(), 1)
  // The exact equality #95 asks for: the story the reader gives back IS the
  // story that was authored, node for node.
  assert_eq(read.headers[0].body, header_body)
  assert_eq(read.footers[0].body, footer_body)
  // ...and the section points at them under the variants that were asked for.
  debug_inspect(
    read.sections,
    content=(
      #|[
      #|  {
      #|    ends_after_paragraph: None,
      #|    headers: [{ variant: "default", part: 0 }],
      #|    footers: [{ variant: "default", part: 0 }],
      #|  },
      #|]
    ),
  )
}

///|
test "a footer PAGE field is a live field, not static text" {
  let footer_body = [
    @docx2html.paragraph([
      @docx2html.run([@docx2html.text("Page ")]),
      @document.field("PAGE", result="1"),
      @docx2html.run([@docx2html.text(" of ")]),
      @document.field("NUMPAGES", result="1"),
    ]),
  ]
  let bytes = @docx2html.write_docx_with_annotations(
    [story_paragraph("body")],
    footers=[@docx2html.header_footer_spec(variant="default", footer_body)],
  )
  // The canonical complex-field run sequence: begin, instruction, separate,
  // cached result, end. Nothing here is a static page number.
  inspect(
    part_text(bytes, "word/footer1.xml"),
    content=(
      #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t xml:space="preserve">Page </w:t></w:r><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>1</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r><w:r><w:t xml:space="preserve"> of </w:t></w:r><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> NUMPAGES </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>1</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:ftr>
    ),
  )
  inspect(@opc.validate_docx_package(bytes).length(), content="0")
  // Our own reader survives the field: it projects the CACHED RESULT as
  // ordinary content (it has no Field node of its own), so the field does NOT
  // round-trip node-for-node the way plain story content does.
  let read = @docx2html.read_docx_package(bytes)
  debug_inspect(read.messages, content="[]")
  inspect(read.footers.length(), content="1")
  inspect(
    @document.paragraph(read.footers[0].body).to_raw_text(),
    content=(
      #|Page 1 of 1
      #|
      #|
      #|
      #|
    ),
  )
}

///|
test "a field with no cached result omits the separate/result runs" {
  let bytes = @docx2html.write_docx_with_annotations(
    [story_paragraph("body")],
    footers=[
      @docx2html.header_footer_spec(variant="default", [
        @docx2html.paragraph([@document.field("PAGE")]),
      ]),
    ],
  )
  inspect(
    part_text(bytes, "word/footer1.xml"),
    content=(
      #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:ftr>
    ),
  )
  inspect(@opc.validate_docx_package(bytes).length(), content="0")
}

///|
test "all three variants emit their references, titlePg and evenAndOddHeaders" {
  let bytes = @docx2html.write_docx_with_annotations(
    [story_paragraph("body")],
    headers=[
      // Deliberately out of canonical order: emission normalizes it.
      @docx2html.header_footer_spec(variant="even", [story_paragraph("even")]),
      @docx2html.header_footer_spec(variant="first", [story_paragraph("first")]),
      @docx2html.header_footer_spec(variant="default", [
        story_paragraph("default"),
      ]),
    ],
    footers=[
      @docx2html.header_footer_spec(variant="default", [
        story_paragraph("footer"),
      ]),
    ],
  )
  inspect(
    section_properties(bytes),
    content=(
      #|<w:sectPr><w:headerReference r:id="rId3" w:type="default"/><w:headerReference r:id="rId4" w:type="first"/><w:headerReference r:id="rId5" w:type="even"/><w:footerReference r:id="rId6" w:type="default"/><w:pgSz w:h="15840" w:w="12240"/><w:pgMar w:top="1440" w:left="1440" w:right="1440" w:bottom="1440" w:footer="720" w:gutter="0" w:header="720"/><w:titlePg/></w:sectPr>
    ),
  )
  // The canonical order is default, first, even, so header1 is the DEFAULT
  // story even though the even story was supplied first.
  inspect(
    part_text(bytes, "word/header1.xml").find("<w:t>default</w:t>") is Some(_),
    content="true",
  )
  inspect(
    part_text(bytes, "word/header2.xml").find("<w:t>first</w:t>") is Some(_),
    content="true",
  )
  inspect(
    part_text(bytes, "word/header3.xml").find("<w:t>even</w:t>") is Some(_),
    content="true",
  )
  // An even-page story is inert in Word without this settings flag.
  inspect(
    part_text(bytes, "word/settings.xml"),
    content=(
      #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:evenAndOddHeaders/></w:settings>
    ),
  )
  inspect(@opc.validate_docx_package(bytes).length(), content="0")
  // Every variant reads back, and each maps to its own part.
  let read = @docx2html.read_docx_package(bytes)
  debug_inspect(read.messages, content="[]")
  debug_inspect(
    read.sections,
    content=(
      #|[
      #|  {
      #|    ends_after_paragraph: None,
      #|    headers: [
      #|      { variant: "default", part: 0 },
      #|      { variant: "first", part: 1 },
      #|      { variant: "even", part: 2 },
      #|    ],
      #|    footers: [{ variant: "default", part: 0 }],
      #|  },
      #|]
    ),
  )
}

///|
test "no even story means no settings part; no first story means no titlePg" {
  let bytes = @docx2html.write_docx_with_annotations(
    [story_paragraph("body")],
    headers=[
      @docx2html.header_footer_spec(variant="default", [
        story_paragraph("header"),
      ]),
    ],
  )
  inspect(
    part_names(bytes),
    content=(
      #|_rels/.rels
      #|word/styles.xml
      #|word/header1.xml
      #|word/document.xml
      #|[Content_Types].xml
      #|word/_rels/document.xml.rels
    ),
  )
  inspect(
    part_text(bytes, "word/document.xml").find("<w:titlePg/>") is Some(_),
    content="false",
  )
}

///|
test "a header story may hold a table" {
  let bytes = @docx2html.write_docx_with_annotations(
    [story_paragraph("body")],
    headers=[
      @docx2html.header_footer_spec(variant="default", [
        @docx2html.table([
          @docx2html.table_row([
            @docx2html.table_cell([story_paragraph("left")]),
          ]),
        ]),
      ]),
    ],
  )
  inspect(
    part_text(bytes, "word/header1.xml").find("<w:tbl>") is Some(_),
    content="true",
  )
  inspect(@opc.validate_docx_package(bytes).length(), content="0")
}

///|
fn expect_story_refusal(
  build : () -> Unit raise @docx2html.DocxError,
  expected : String,
) -> Unit raise {
  try build() catch {
    Unsupported(message~) =>
      if message.find(expected) is None {
        fail("expected a refusal mentioning '\{expected}', got: \{message}")
      }
    err => fail("expected Unsupported, got \{repr(err)}")
  } noraise {
    _ => fail("expected the writer to fail closed")
  }
}

///|
test "header/footer stories fail closed on everything they cannot carry" {
  expect_story_refusal(
    () => {
      @docx2html.header_footer_spec(variant="middle", [story_paragraph("x")])
      |> ignore
    },
    "unsupported header/footer variant 'middle'",
  )
  expect_story_refusal(
    () => @docx2html.header_footer_spec(variant="default", []) |> ignore,
    "needs a non-empty body",
  )
  expect_story_refusal(
    () => {
      @docx2html.header_footer_spec(variant="default", [
        @docx2html.paragraph([
          @docx2html.hyperlink(
            [@docx2html.run([@docx2html.text("x")])],
            href=Some("https://example.invalid/"),
          ),
        ]),
      ])
      |> ignore
    },
    "hyperlinks cannot be serialized into a header/footer part",
  )
  expect_story_refusal(
    () => {
      @docx2html.header_footer_spec(variant="default", [
        @docx2html.paragraph([
          @docx2html.run([@docx2html.note_reference("footnote", "0")]),
        ]),
      ])
      |> ignore
    },
    "cannot carry note references",
  )
  // A duplicate variant would produce a package our own reader refuses.
  expect_story_refusal(
    () => {
      @docx2html.write_docx_with_annotations([story_paragraph("body")], headers=[
        @docx2html.header_footer_spec(variant="default", [story_paragraph("a")]),
        @docx2html.header_footer_spec(variant="default", [story_paragraph("b")]),
      ])
      |> ignore
    },
    "repeats the 'default' variant",
  )
  // Fields are page-numbering only.
  expect_story_refusal(
    () => {
      @docx2html.write_docx_with_annotations([
        @docx2html.paragraph([@document.field("TOC")]),
      ])
      |> ignore
    },
    "unsupported field instruction 'TOC'",
  )
  // Annotation parts stay plain content.
  expect_story_refusal(
    () => {
      @docx2html.comment_spec(author="Ada", from=0, to=0, [
        @docx2html.paragraph([@document.field("PAGE")]),
      ])
      |> ignore
    },
    "fields cannot be serialized into annotation parts",
  )
}

///|
test "#95 backward compatibility: a story-free write is unchanged" {
  // The pre-#95 entry points and the new one must produce the SAME BYTES for
  // a script that authors no header, footer or field. This is the regression
  // that matters most: `docx.batch/2` is consumed in the wild.
  let body = [
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("Report")])],
      properties=@document.paragraph_properties(style_id=Some("Heading1")),
    ),
    @docx2html.paragraph([@docx2html.run([@docx2html.text("body text")])]),
    @docx2html.table([
      @docx2html.table_row([@docx2html.table_cell([story_paragraph("cell")])]),
    ]),
  ]
  let comments = [
    @docx2html.comment_spec(author="Ada", from=0, to=1, [
      story_paragraph("revise"),
    ]),
  ]
  let plain = @docx2html.write_docx(body)
  let with_stories_absent = @docx2html.write_docx_with_annotations(
    body,
    headers=[],
    footers=[],
  )
  assert_eq(plain, with_stories_absent)
  let annotated = @docx2html.write_docx_with_comments(body, comments)
  let annotated_again = @docx2html.write_docx_with_annotations(
    body,
    comments~,
    headers=[],
    footers=[],
  )
  assert_eq(annotated, annotated_again)
}
