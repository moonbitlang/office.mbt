///|
fn markdown_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn markdown_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn markdown_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes raise {
  @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn markdown_font_resources_for_test(
  font : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      markdown_name_for_test("/Font"),
      @pdflite.pdf_dictionary([(markdown_name_for_test("/F0"), font)]),
    ),
  ])
}

///|
fn markdown_standard_font_for_test() -> @pdflite.PdfObject raise {
  @pdflite.pdf_make_font(
    markdown_name_for_test("/Helvetica"),
    PdfWinAnsiEncoding,
  )
}

///|
fn markdown_latin_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let resources = markdown_font_resources_for_test(
    markdown_standard_font_for_test(),
  )
  let page1 = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tj(markdown_ascii_for_test("Hello, ")),
        Op_TJ(
          PdfArray([
            PdfReal(-300.0),
            PdfString(markdown_ascii_for_test("World")),
            PdfInteger(-20),
            PdfString(markdown_ascii_for_test("!")),
            PdfInteger(-300),
            PdfReal(-300.0),
            PdfString(markdown_ascii_for_test("Spaced")),
          ]),
        ),
        Op_quote(markdown_ascii_for_test("Second line")),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page2 = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tj(markdown_ascii_for_test("Another page")),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page1, page2])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_tounicode_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      markdown_name_for_test("/Type"),
      PdfNameObject(markdown_name_for_test("/Font")),
    ),
    (
      markdown_name_for_test("/Subtype"),
      PdfNameObject(markdown_name_for_test("/Type1")),
    ),
    (
      markdown_name_for_test("/BaseFont"),
      PdfNameObject(markdown_name_for_test("/Custom")),
    ),
    (markdown_name_for_test("/ToUnicode"), PdfIndirect(60)),
  ])
}

///|
fn markdown_cjk_document_for_test() -> @pdflite.PdfDocument raise {
  let cmap = markdown_ascii_for_test(
    "1 begincodespacerange\n" +
    "<00><FF>\n" +
    "endcodespacerange\n" +
    "3 beginbfchar\n" +
    "<41><4E16>\n" +
    "<42><754C>\n" +
    "<43><0021>\n" +
    "endbfchar\n",
  )
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    60,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (markdown_name_for_test("/Length"), PdfInteger(cmap.length())),
      ]),
      StreamGot(cmap),
    ),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tj(markdown_bytes_for_test([65, 66, 67])),
        Op_ET,
      ]),
    ],
    resources: markdown_font_resources_for_test(
      markdown_tounicode_font_for_test(),
    ),
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_missing_font_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/Missing"), 12.0),
        Op_quote(markdown_ascii_for_test("not extracted")),
        Op_ET,
      ]),
    ],
    resources: @pdflite.pdf_dictionary([]),
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_line_break_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let resources = markdown_font_resources_for_test(
    markdown_standard_font_for_test(),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tj(markdown_ascii_for_test("First   ")),
        Op_Tstar,
        Op_double_quote(0.0, 0.0, markdown_ascii_for_test("Second ")),
        Op_Tstar,
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_blank_password_document_for_test() -> @pdflite.PdfDocument raise {
  markdown_latin_document_for_test().encrypt_40bit(
    @ascii.encode("")[:],
    @ascii.encode("owner")[:],
    [PdfNoCopy],
    file_id=@ascii.encode("markdown-encrypted-id")[:],
  )
}

///|
fn markdown_password_required_document_for_test() -> @pdflite.PdfDocument raise {
  markdown_latin_document_for_test().encrypt_40bit(
    @ascii.encode("user")[:],
    @ascii.encode("owner")[:],
    [PdfNoCopy],
    file_id=@ascii.encode("markdown-password-id")[:],
  )
}

///|
test "pdf_document_to_markdown extracts deterministic Latin page text" {
  let markdown = try! @markdown.pdf_document_to_markdown(
    markdown_latin_document_for_test(),
  )
  @test.assert_eq(
    markdown, "# Page 1\n\nHello, World! Spaced\nSecond line\n\n# Page 2\n\nAnother page\n",
  )
}

///|
test "pdf_bytes_to_markdown reads and extracts deterministic Latin text" {
  let document = markdown_latin_document_for_test()
  let bytes = @pdflite.pdf_write_document(document)
  @test.assert_eq(
    try! @markdown.pdf_bytes_to_markdown(bytes),
    "# Page 1\n\nHello, World! Spaced\nSecond line\n\n# Page 2\n\nAnother page\n",
  )
}

///|
test "pdf_document_to_markdown decrypts blank user password PDFs" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_blank_password_document_for_test(),
    ),
    "# Page 1\n\nHello, World! Spaced\nSecond line\n\n# Page 2\n\nAnother page\n",
  )
}

///|
test "pdf_document_to_markdown raises when encrypted PDF needs a password" {
  let result : Result[String, Error] = try? @markdown.pdf_document_to_markdown(
    markdown_password_required_document_for_test(),
  )
  @test.assert_eq(result is Err(_), true)
}

///|
test "pdf_document_to_markdown preserves ToUnicode CJK output" {
  @test.assert_eq(
    try! @markdown.pdf_document_to_markdown(markdown_cjk_document_for_test()),
    "# Page 1\n\n世界!\n",
  )
}

///|
test "pdf_document_to_markdown skips text without a resolvable font" {
  @test.assert_eq(
    try! @markdown.pdf_document_to_markdown(
      markdown_missing_font_document_for_test(),
    ),
    "# Page 1\n\n\n",
  )
}

///|
test "pdf_document_to_markdown normalizes explicit line breaks" {
  @test.assert_eq(
    try! @markdown.pdf_document_to_markdown(
      markdown_line_break_document_for_test(),
    ),
    "# Page 1\n\nFirst\nSecond\n",
  )
}
