///|
fn markdown_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn markdown_ascii_for_test(text : String) -> @core.PdfBytes {
  @ascii.encode(text)
}

///|
fn markdown_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes raise {
  @core.pdf_bytes_of_int_array(values)
}

///|
fn markdown_font_resources_for_test(
  font : @syntax.PdfObject,
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (
      markdown_name_for_test("/Font"),
      @syntax.pdf_dictionary([(markdown_name_for_test("/F0"), font)]),
    ),
  ])
}

///|
fn markdown_indirect_font_resources_for_test(
  font_number : Int,
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (
      markdown_name_for_test("/Font"),
      @syntax.pdf_dictionary([
        (markdown_name_for_test("/F0"), PdfIndirect(font_number)),
      ]),
    ),
  ])
}

///|
fn markdown_standard_font_for_test() -> @syntax.PdfObject raise {
  @pdflite.pdf_make_font(
    markdown_name_for_test("/Helvetica"),
    PdfWinAnsiEncoding,
  )
}

///|
fn markdown_control_font_for_test() -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
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
      @syntax.pdf_dictionary([
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
fn markdown_no_tounicode_truetype_font_for_test() -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (
      markdown_name_for_test("/Type"),
      PdfNameObject(markdown_name_for_test("/Font")),
    ),
    (
      markdown_name_for_test("/Subtype"),
      PdfNameObject(markdown_name_for_test("/TrueType")),
    ),
    (
      markdown_name_for_test("/BaseFont"),
      PdfNameObject(markdown_name_for_test("/GNLPNB+UnihanInfo")),
    ),
    (
      markdown_name_for_test("/Encoding"),
      PdfNameObject(markdown_name_for_test("/WinAnsiEncoding")),
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
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
fn markdown_unreliable_notdef_control_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let resources = markdown_font_resources_for_test(
    markdown_no_tounicode_truetype_font_for_test(),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tj(markdown_bytes_for_test([117, 1])),
        Op_Tj(markdown_ascii_for_test("1.0")),
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
fn markdown_control_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let resources = markdown_font_resources_for_test(
    markdown_control_font_for_test(),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
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
fn markdown_positioned_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let resources = markdown_font_resources_for_test(
    markdown_standard_font_for_test(),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tm(@geometry.transform_translate(200.0, 700.0)),
        Op_Tj(markdown_ascii_for_test("Right")),
        Op_Tm(@geometry.transform_translate(50.0, 680.0)),
        Op_Tj(markdown_ascii_for_test("Lower")),
        Op_Tm(@geometry.transform_translate(50.0, 700.0)),
        Op_Tj(markdown_ascii_for_test("Left")),
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
fn markdown_positioned_form_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let resources = markdown_font_resources_for_test(
    markdown_standard_font_for_test(),
  )
  let form = @pdflite.pdf_content_stream_of_ops([
      Op_BT,
      Op_Tf(markdown_name_for_test("/F0"), 12.0),
      Op_Tj(markdown_ascii_for_test("Form")),
      Op_ET,
    ])
    .add_dict_entry(
      markdown_name_for_test("/Subtype"),
      PdfNameObject(markdown_name_for_test("/Form")),
    )
    .add_dict_entry(markdown_name_for_test("/Resources"), resources)
  doc.add_object_given_number(80, form)
  let form_name = markdown_name_for_test("/FmPlaced")
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_q,
        Op_cm(@geometry.transform_translate(200.0, 700.0)),
        Op_Do(form_name),
        Op_Q,
        Op_q,
        Op_cm(@geometry.transform_translate(50.0, 700.0)),
        Op_Do(form_name),
        Op_Q,
      ]),
    ],
    resources: @syntax.pdf_dictionary([
      (
        markdown_name_for_test("/XObject"),
        @syntax.pdf_dictionary([(form_name, PdfIndirect(80))]),
      ),
    ]),
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_positioned_text_state_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let resources = markdown_font_resources_for_test(
    markdown_standard_font_for_test(),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tm(@geometry.transform_translate(50.0, 700.0)),
        Op_TJ(
          PdfArray([
            PdfString(markdown_ascii_for_test("A")),
            PdfInteger(-300),
            PdfString(markdown_ascii_for_test("B")),
          ]),
        ),
        Op_Td(0.0, -20.0),
        Op_Tj(markdown_ascii_for_test("C")),
        Op_TL(20.0),
        Op_Tstar,
        Op_Tj(markdown_ascii_for_test("D")),
        Op_TD(0.0, -20.0),
        Op_Tj(markdown_ascii_for_test("E")),
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
fn markdown_positioned_hyphenated_line_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let resources = markdown_font_resources_for_test(
    markdown_standard_font_for_test(),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tm(@geometry.transform_translate(50.0, 700.0)),
        Op_Tj(markdown_ascii_for_test("soft -")),
        Op_Tm(@geometry.transform_translate(50.0, 680.0)),
        Op_Tj(markdown_ascii_for_test("ware")),
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
fn markdown_positioned_cjk_spacing_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let cmap = markdown_ascii_for_test(
    "1 begincodespacerange\n" +
    "<00><FF>\n" +
    "endcodespacerange\n" +
    "1 beginbfchar\n" +
    "<41><4E16>\n" +
    "endbfchar\n",
  )
  doc.add_object_given_number(
    81,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (markdown_name_for_test("/Length"), PdfInteger(cmap.length())),
      ]),
      StreamGot(cmap),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 10.0),
        Op_Tm(@geometry.transform_translate(50.0, 700.0)),
        Op_Tj(markdown_bytes_for_test([65])),
        Op_Tm(@geometry.transform_translate(66.0, 700.0)),
        Op_Tj(markdown_bytes_for_test([65])),
        Op_Tm(@geometry.transform_translate(88.0, 700.0)),
        Op_Tj(markdown_bytes_for_test([65])),
        Op_ET,
      ]),
    ],
    resources: markdown_font_resources_for_test(
      @syntax.pdf_dictionary([
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
        (markdown_name_for_test("/ToUnicode"), PdfIndirect(81)),
      ]),
    ),
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_tounicode_font_for_test() -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
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
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (markdown_name_for_test("/Length"), PdfInteger(cmap.length())),
      ]),
      StreamGot(cmap),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
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
fn markdown_cjk_tj_spacing_document_for_test() -> @pdflite.PdfDocument raise {
  let cmap = markdown_ascii_for_test(
    "1 begincodespacerange\n" +
    "<00><FF>\n" +
    "endcodespacerange\n" +
    "2 beginbfchar\n" +
    "<41><4E16>\n" +
    "<42><754C>\n" +
    "endbfchar\n",
  )
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    82,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (markdown_name_for_test("/Length"), PdfInteger(cmap.length())),
      ]),
      StreamGot(cmap),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_TJ(
          PdfArray([
            PdfString(markdown_bytes_for_test([65])),
            PdfReal(-300.0),
            PdfString(markdown_bytes_for_test([66])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources: markdown_font_resources_for_test(
      @syntax.pdf_dictionary([
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
        (markdown_name_for_test("/ToUnicode"), PdfIndirect(82)),
      ]),
    ),
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_hangul_tj_spacing_document_for_test() -> @pdflite.PdfDocument raise {
  let cmap = markdown_ascii_for_test(
    "1 begincodespacerange\n" +
    "<00><FF>\n" +
    "endcodespacerange\n" +
    "2 beginbfchar\n" +
    "<41><D55C>\n" +
    "<42><AE00>\n" +
    "endbfchar\n",
  )
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    83,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (markdown_name_for_test("/Length"), PdfInteger(cmap.length())),
      ]),
      StreamGot(cmap),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_TJ(
          PdfArray([
            PdfString(markdown_bytes_for_test([65])),
            PdfReal(-300.0),
            PdfString(markdown_bytes_for_test([66])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources: markdown_font_resources_for_test(
      @syntax.pdf_dictionary([
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
        (markdown_name_for_test("/ToUnicode"), PdfIndirect(83)),
      ]),
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/Missing"), 12.0),
        Op_quote(markdown_ascii_for_test("not extracted")),
        Op_ET,
      ]),
    ],
    resources: @syntax.pdf_dictionary([]),
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(markdown_name_for_test("/F0"), 12.0),
        Op_Tj(markdown_ascii_for_test("First   ")),
        Op_Tstar,
        Op_double_quote(0.0, 0.0, markdown_ascii_for_test("Second ")),
        Op_Tstar,
        Op_Tj(markdown_ascii_for_test("soft -")),
        Op_Tstar,
        Op_Tj(markdown_ascii_for_test("ware")),
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [@pdflite.pdf_content_stream_of_ops([Op_Do(form_name)])],
    resources: @syntax.pdf_dictionary([
      (
        markdown_name_for_test("/XObject"),
        @syntax.pdf_dictionary([(form_name, PdfIndirect(70))]),
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [@pdflite.pdf_content_stream_of_ops([Op_Do(form_name)])],
    resources: @syntax.pdf_dictionary([
      (
        markdown_name_for_test("/XObject"),
        @syntax.pdf_dictionary([(form_name, PdfIndirect(72))]),
      ),
      (
        markdown_name_for_test("/Font"),
        @syntax.pdf_dictionary([
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
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
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
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (markdown_name_for_test("/Length"), PdfInteger(0)),
      ]),
      StreamGot([]),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_Do(markdown_name_for_test("/Missing")),
        Op_Do(markdown_name_for_test("/NoSubtype")),
        Op_Do(image_name),
      ]),
    ],
    resources: @syntax.pdf_dictionary([
      (
        markdown_name_for_test("/XObject"),
        @syntax.pdf_dictionary([
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
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_Do(markdown_name_for_test("/Missing")),
      ]),
    ],
    resources: @syntax.pdf_dictionary([]),
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn markdown_blank_password_document_for_test() -> @pdflite.PdfDocument raise {
  markdown_latin_document_for_test().encrypt_40bit(
    @ascii.encode(""),
    @ascii.encode("owner"),
    [PdfNoCopy],
    file_id=@ascii.encode("markdown-encrypted-id"),
  )
}

///|
fn markdown_password_required_document_for_test() -> @pdflite.PdfDocument raise {
  markdown_latin_document_for_test().encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoCopy],
    file_id=@ascii.encode("markdown-password-id"),
  )
}

///|
test "pdf_document_to_markdown extracts deterministic Latin page text" {
  let markdown = @markdown.pdf_document_to_markdown(
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
    @markdown.pdf_bytes_to_markdown(bytes),
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
test "pdf_document_to_markdown skips unreliable notdef-control glyph runs" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_unreliable_notdef_control_document_for_test(),
    ),
    "# Page 1\n\n1.0\n",
  )
}

///|
test "pdf_document_to_markdown sorts positioned text by row and column" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(markdown_positioned_document_for_test()),
    "# Page 1\n\nLeft Right\nLower\n",
  )
}

///|
test "pdf_document_to_markdown sorts positioned form XObjects" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_positioned_form_document_for_test(),
    ),
    "# Page 1\n\nForm Form\n",
  )
}

///|
test "pdf_document_to_markdown tracks positioned text-state moves" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_positioned_text_state_document_for_test(),
    ),
    "# Page 1\n\nA B\nC\nD\nE\n",
  )
}

///|
test "pdf_document_to_markdown trims space before positioned terminal hyphen" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_positioned_hyphenated_line_document_for_test(),
    ),
    "# Page 1\n\nsoft-\nware\n",
  )
}

///|
test "pdf_document_to_markdown keeps adjacent positioned CJK glyphs together" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_positioned_cjk_spacing_document_for_test(),
    ),
    "# Page 1\n\n世世 世\n",
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
  let result : Result[String, Error] = try
    @markdown.pdf_document_to_markdown(
      markdown_password_required_document_for_test(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  @test.assert_eq(result is Err(_), true)
}

///|
test "pdf_document_to_markdown preserves ToUnicode CJK output" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(markdown_cjk_document_for_test()),
    "# Page 1\n\n世界!\n",
  )
}

///|
test "pdf_document_to_markdown suppresses TJ spaces between CJK glyphs" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_cjk_tj_spacing_document_for_test(),
    ),
    "# Page 1\n\n世界\n",
  )
}

///|
test "pdf_document_to_markdown preserves TJ spaces between Hangul words" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_hangul_tj_spacing_document_for_test(),
    ),
    "# Page 1\n\n한 글\n",
  )
}

///|
test "pdf_document_to_markdown skips text without a resolvable font" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(
      markdown_missing_font_document_for_test(),
    ),
    "# Page 1\n\n\n",
  )
}

///|
test "pdf_document_to_markdown normalizes explicit line breaks" {
  @test.assert_eq(
    @markdown.pdf_document_to_markdown(markdown_line_break_document_for_test()),
    "# Page 1\n\nFirst\nSecond\nsoft-\nware\n",
  )
}
