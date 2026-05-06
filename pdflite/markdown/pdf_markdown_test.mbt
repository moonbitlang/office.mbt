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
fn markdown_indirect_font_resources_for_test(
  font_number : Int,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      markdown_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (markdown_name_for_test("/F0"), PdfIndirect(font_number)),
      ]),
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
fn markdown_control_font_for_test() -> @pdflite.PdfObject {
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
      PdfNameObject(markdown_name_for_test("/Helvetica")),
    ),
    (
      markdown_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          markdown_name_for_test("/BaseEncoding"),
          PdfNameObject(markdown_name_for_test("/StandardEncoding")),
        ),
        (
          markdown_name_for_test("/Differences"),
          PdfArray([
            PdfInteger(1),
            PdfNameObject(markdown_name_for_test("/controlSTX")),
            PdfNameObject(markdown_name_for_test("/controlDEL")),
            PdfNameObject(markdown_name_for_test("/controlHT")),
            PdfNameObject(markdown_name_for_test("/controlLF")),
            PdfNameObject(markdown_name_for_test("/controlFF")),
            PdfNameObject(markdown_name_for_test("/controlCR")),
          ]),
        ),
      ]),
    ),
  ])
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
fn markdown_control_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let resources = markdown_font_resources_for_test(
    markdown_control_font_for_test(),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tj(markdown_bytes_for_test([65, 3, 1, 2, 3, 66])),
        Op_Tj(markdown_bytes_for_test([4, 66, 5, 65, 6, 66])),
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
fn markdown_form_xobject_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(71, markdown_standard_font_for_test())
  let form_name = markdown_name_for_test("/Fm0")
  let form = @pdflite.pdf_content_stream_of_ops([
      Op_BT,
      Op_Tf(markdown_name_for_test("/F0"), 12.0),
      Op_Tj(markdown_ascii_for_test("Form text")),
      Op_Tf(markdown_name_for_test("/F0"), 10.0),
      Op_Tj(markdown_ascii_for_test(" again")),
      Op_ET,
    ])
    .add_dict_entry(
      markdown_name_for_test("/Subtype"),
      PdfNameObject(markdown_name_for_test("/Form")),
    )
    .add_dict_entry(
      markdown_name_for_test("/Resources"),
      markdown_indirect_font_resources_for_test(71),
    )
  doc.add_object_given_number(70, form)
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [@pdflite.pdf_content_stream_of_ops([Op_Do(form_name)])],
    resources: @pdflite.pdf_dictionary([
      (
        markdown_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([(form_name, PdfIndirect(70))]),
      ),
    ]),
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_inherited_form_xobject_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let form_name = markdown_name_for_test("/FmInherited")
  let form = @pdflite.pdf_content_stream_of_ops([
    Op_BT,
    Op_Tf(markdown_name_for_test("/F0"), 12.0),
    Op_Tj(markdown_ascii_for_test("Inherited form text")),
    Op_ET,
  ]).add_dict_entry(
    markdown_name_for_test("/Subtype"),
    PdfNameObject(markdown_name_for_test("/Form")),
  )
  doc.add_object_given_number(72, form)
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [@pdflite.pdf_content_stream_of_ops([Op_Do(form_name)])],
    resources: @pdflite.pdf_dictionary([
      (
        markdown_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([(form_name, PdfIndirect(72))]),
      ),
      (
        markdown_name_for_test("/Font"),
        @pdflite.pdf_dictionary([
          (markdown_name_for_test("/F0"), markdown_standard_font_for_test()),
        ]),
      ),
    ]),
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_non_text_xobject_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let image_name = markdown_name_for_test("/Im0")
  doc.add_object_given_number(
    73,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (
          markdown_name_for_test("/Subtype"),
          PdfNameObject(markdown_name_for_test("/Image")),
        ),
        (markdown_name_for_test("/Length"), PdfInteger(0)),
      ]),
      StreamGot([]),
    ),
  )
  doc.add_object_given_number(
    74,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (markdown_name_for_test("/Length"), PdfInteger(0)),
      ]),
      StreamGot([]),
    ),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_Do(markdown_name_for_test("/Missing")),
        Op_Do(markdown_name_for_test("/NoSubtype")),
        Op_Do(image_name),
      ]),
    ],
    resources: @pdflite.pdf_dictionary([
      (
        markdown_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([
          (markdown_name_for_test("/NoSubtype"), PdfIndirect(74)),
          (image_name, PdfIndirect(73)),
        ]),
      ),
    ]),
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_missing_xobject_dictionary_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_Do(markdown_name_for_test("/Missing")),
      ]),
    ],
    resources: @pdflite.pdf_dictionary([]),
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
test "pdf_document_to_markdown extracts text inside form XObjects" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_form_xobject_document_for_test(),
    ),
    "# Page 1\n\nForm text again\n",
  )
}

///|
test "pdf_document_to_markdown uses parent resources for form XObjects" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_inherited_form_xobject_document_for_test(),
    ),
    "# Page 1\n\nInherited form text\n",
  )
}

///|
test "pdf_document_to_markdown skips missing and non-form XObjects" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_non_text_xobject_document_for_test(),
    ),
    "# Page 1\n\n\n",
  )
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_missing_xobject_dictionary_document_for_test(),
    ),
    "# Page 1\n\n\n",
  )
}

///|
test "pdf_document_to_markdown sanitizes non-text controls" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_control_text_document_for_test(),
    ),
    "# Page 1\n\nA \u{FFFD} B\nB A\nB\n",
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
