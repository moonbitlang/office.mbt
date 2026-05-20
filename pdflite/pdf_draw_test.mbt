///|
fn draw_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn draw_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for value in values {
    output.push(try! @pdflite.pdf_byte_of_int(value))
  }
  Bytes::from_array(output)
}

///|
fn draw_append_bytes_for_test(output : Array[Byte], bytes : BytesView) -> Unit {
  for byte in bytes {
    output.push(byte)
  }
}

///|
fn draw_push_u32_for_test(output : Array[Byte], value : Int) -> Unit {
  output.push(try! @pdflite.pdf_byte_of_int((value >> 24) & 0xFF))
  output.push(try! @pdflite.pdf_byte_of_int((value >> 16) & 0xFF))
  output.push(try! @pdflite.pdf_byte_of_int((value >> 8) & 0xFF))
  output.push(try! @pdflite.pdf_byte_of_int(value & 0xFF))
}

///|
fn draw_png_chunk_for_test(
  chunk_type : ArrayView[Int],
  data : BytesView,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  draw_push_u32_for_test(output, data.length())
  for value in chunk_type {
    output.push(try! @pdflite.pdf_byte_of_int(value))
  }
  draw_append_bytes_for_test(output, data)
  draw_push_u32_for_test(output, 0)
  Bytes::from_array(output)
}

///|
fn draw_png_rgb_for_test() -> (@pdflite.PdfBytes, @pdflite.PdfBytes) {
  let header = draw_bytes_for_test([0, 0, 0, 2, 0, 0, 0, 1, 8, 2, 0, 0, 0])
  let idat = @pdflite.pdf_flate_encode(
    draw_bytes_for_test([0, 10, 20, 30, 40, 50, 60]),
  )
  let output : Array[Byte] = []
  for value in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
    output.push(try! @pdflite.pdf_byte_of_int(value))
  }
  draw_append_bytes_for_test(
    output,
    draw_png_chunk_for_test([0x49, 0x48, 0x44, 0x52], header),
  )
  draw_append_bytes_for_test(
    output,
    draw_png_chunk_for_test([0x49, 0x44, 0x41, 0x54], idat),
  )
  draw_append_bytes_for_test(
    output,
    draw_png_chunk_for_test([0x49, 0x45, 0x4E, 0x44], []),
  )
  (Bytes::from_array(output), idat)
}

///|
fn draw_jpeg_for_test() -> @pdflite.PdfBytes {
  draw_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x01, 0x2C, 0x01, 0x90, 0x03, 0x01, 0xFF, 0xD9,
  ])
}

///|
fn draw_jpeg2000_for_test() -> @pdflite.PdfBytes {
  draw_bytes_for_test([
    0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20, 0x0D, 0x0A, 0x87, 0x0A, 0x69,
    0x68, 0x64, 0x72, 0x00, 0x00, 0x01, 0x2C, 0x00, 0x00, 0x01, 0x90,
  ])
}

///|
fn draw_standard_font_for_test(
  font : @pdflite.PdfStandardFont,
) -> @pdflite.PdfFont {
  PdfFontStandard({ font, encoding: PdfWinAnsiEncoding })
}

///|
fn draw_time_for_test() -> @pdflite.PdfStrftimeTime {
  {
    tm_sec: 5,
    tm_min: 4,
    tm_hour: 13,
    tm_mday: 3,
    tm_mon: 8,
    tm_year: 123,
    tm_wday: 0,
    tm_yday: 6,
    tm_isdst: false,
  }
}

///|
fn draw_fresh_structure_document_for_test() -> @pdflite.PdfDocument {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let key_root = draw_name_for_test("/Root")
  let key_struct_tree_root = draw_name_for_test("/StructTreeRoot")
  let key_type = draw_name_for_test("/Type")
  try! document.replace_chain(
    [key_root, key_struct_tree_root, key_type],
    PdfNameObject(key_struct_tree_root),
  )
  document
}

///|
fn draw_page_ops_for_test(
  document : @pdflite.PdfDocument,
  page_number : Int,
) -> Array[@pdflite.PdfContentOp] raise Error {
  let pages = try! document.pages_of_pagetree()
  let page = pages[page_number - 1]
  document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "pdf draw debug strings match cpdf spelling" {
  @test.assert_eq(
    @pdflite.pdf_string_of_drawop(PdfDrawRect(0.0, 0.0, 1.0, 2.0)),
    "Rect",
  )
  @test.assert_eq(
    @pdflite.pdf_string_of_drawops([
      PdfDrawRect(0.0, 0.0, 1.0, 2.0),
      PdfDrawMatrix(@pdflite.transform_translate(1.0, 2.0)),
      PdfDrawFontPack("F0", { fonts: [], entries: [] }, []),
      PdfDrawTag("Span"),
      PdfDrawSTag("P"),
    ]),
    " Rect SetMatrix FontPack F0  Tag Span Tag P",
  )
}

///|
test "pdf draw debug strings preserve nested leading spaces" {
  let ops : Array[@pdflite.PdfDrawOp] = [
    PdfDrawQq([PdfDrawRect(0.0, 0.0, 10.0, 20.0)]),
    PdfDrawTextSection([PdfDrawText("hello"), PdfDrawNewline]),
    PdfDrawFormXObject(0.0, 0.0, 20.0, 30.0, "X0", [PdfDrawLine(2.0, 3.0)]),
  ]
  @test.assert_eq(
    @pdflite.pdf_string_of_drawops(ops),
    " Qq ( Rect) TextSection ( Text Newline) FormXObject ( Line)",
  )
}

///|
test "pdf draw core ops convert to PDF content ops" {
  let matrix = @pdflite.transform_translate(7.0, 8.0)
  let ops : Array[@pdflite.PdfDrawOp] = [
    PdfDrawSetLineThickness(2.0),
    PdfDrawSetLineCap(1),
    PdfDrawSetLineJoin(2),
    PdfDrawSetMiterLimit(10.0),
    PdfDrawSetDashPattern([3.0, 2.0], 1.0),
    PdfDrawMatrix(matrix),
    PdfDrawSetFill(PdfDrawRGB(0.1, 0.2, 0.3)),
    PdfDrawSetStroke(PdfDrawGrey(0.4)),
    PdfDrawSetFill(PdfDrawCYMK(0.0, 0.1, 0.2, 0.3)),
    PdfDrawSetStroke(PdfDrawNoCol),
    PdfDrawRect(1.0, 2.0, 3.0, 4.0),
    PdfDrawTo(5.0, 6.0),
    PdfDrawLine(7.0, 8.0),
    PdfDrawBezier(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    PdfDrawBezier23(2.0, 3.0, 4.0, 5.0),
    PdfDrawBezier13(6.0, 7.0, 8.0, 9.0),
    PdfDrawClosePath,
    PdfDrawFill,
    PdfDrawFillEvenOdd,
    PdfDrawStroke,
    PdfDrawFillStroke,
    PdfDrawFillStrokeEvenOdd,
    PdfDrawClip,
    PdfDrawClipEvenOdd,
  ]
  let expected : Array[@pdflite.PdfContentOp] = [
    Op_w(2.0),
    Op_J(1),
    Op_j(2),
    Op_M(10.0),
    Op_d([3.0, 2.0], 1.0),
    Op_cm(matrix),
    Op_rg(0.1, 0.2, 0.3),
    Op_G(0.4),
    Op_k(0.0, 0.1, 0.2, 0.3),
    Op_re(1.0, 2.0, 3.0, 4.0),
    Op_m(5.0, 6.0),
    Op_l(7.0, 8.0),
    Op_c(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    Op_v(2.0, 3.0, 4.0, 5.0),
    Op_y(6.0, 7.0, 8.0, 9.0),
    Op_h,
    Op_f,
    Op_fstar,
    Op_S,
    Op_B,
    Op_Bstar,
    Op_W,
    Op_n,
    Op_Wstar,
    Op_n,
  ]
  @test.assert_eq(try! @pdflite.pdf_drawops_to_content_ops(ops), expected)
}

///|
test "pdf draw colour parser maps cpdf colours and malformed input" {
  @test.assert_eq(
    try! @pdflite.pdf_parse_draw_colour("red"),
    PdfDrawRGB(1.0, 0.0, 0.0),
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_draw_colour("0.25"),
    PdfDrawGrey(0.25),
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_draw_colour("0 0.1 0.2 0.3"),
    PdfDrawCYMK(0.0, 0.1, 0.2, 0.3),
  )
  @test.assert_eq(
    @pdflite.pdf_draw_colour_of_string("not-a-colour"),
    PdfDrawNoCol,
  )
}

///|
test "pdf draw parsed no-colour emits no fill or stroke operator" {
  @test.assert_eq(
    try! @pdflite.pdf_drawop_to_content_ops(
      PdfDrawSetFill(@pdflite.pdf_draw_colour_of_string("bad")),
    ),
    [],
  )
  @test.assert_eq(
    try! @pdflite.pdf_drawop_to_content_ops(
      PdfDrawSetStroke(@pdflite.pdf_draw_colour_of_string("bad")),
    ),
    [],
  )
}

///|
test "pdf draw grouped ops emit q and Q" {
  let ops : Array[@pdflite.PdfDrawOp] = [
    PdfDrawQq([
      PdfDrawSetStroke(PdfDrawRGB(1.0, 0.0, 0.0)),
      PdfDrawLine(4.0, 5.0),
    ]),
  ]
  let expected : Array[@pdflite.PdfContentOp] = [
    Op_q,
    Op_RG(1.0, 0.0, 0.0),
    Op_l(4.0, 5.0),
    Op_Q,
  ]
  @test.assert_eq(try! @pdflite.pdf_drawops_to_content_ops(ops), expected)
}

///|
test "pdf draw text section and text state ops convert to PDF content ops" {
  let ops : Array[@pdflite.PdfDrawOp] = [
    PdfDrawTextSection([
      PdfDrawLeading(14.0),
      PdfDrawCharSpace(1.25),
      PdfDrawWordSpace(2.5),
      PdfDrawTextScale(90.0),
      PdfDrawRenderMode(3),
      PdfDrawRise(4.0),
      PdfDrawNewline,
      PdfDrawQq([PdfDrawMatrix(@pdflite.transform_translate(1.0, 2.0))]),
    ]),
  ]
  let expected : Array[@pdflite.PdfContentOp] = [
    Op_BT,
    Op_TL(14.0),
    Op_Tc(1.25),
    Op_Tw(2.5),
    Op_Tz(90.0),
    Op_Tr(3),
    Op_Ts(4.0),
    Op_Tstar,
    Op_q,
    Op_cm(@pdflite.transform_translate(1.0, 2.0)),
    Op_Q,
    Op_ET,
  ]
  @test.assert_eq(try! @pdflite.pdf_drawops_to_content_ops(ops), expected)
}

///|
test "pdf draw document-aware fontpacks render text runs and resources" {
  let document = @pdflite.pdf_document_empty()
  let state = @pdflite.pdf_draw_render_state_new()
  let regular = draw_standard_font_for_test(PdfHelvetica)
  let bold = draw_standard_font_for_test(PdfHelveticaBold)
  let pack : @pdflite.PdfFontPack = {
    fonts: [regular, bold],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 1 },
      { codepoint: 66, font_index: 1, charcode: 2 },
      { codepoint: 67, font_index: 1, charcode: 3 },
      { codepoint: 68, font_index: 0, charcode: 4 },
      { codepoint: 90, font_index: 9, charcode: 5 },
    ],
  }
  let f1 = draw_name_for_test("/F1")
  let f2 = draw_name_for_test("/F2")
  let font_key = draw_name_for_test("/Font")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_document(
    state,
    document,
    [
      PdfDrawTextSection([
        PdfDrawFontPack("Body", pack, []),
        PdfDrawFont("Body", 10.0),
        PdfDrawText("ABCDZ"),
      ]),
    ],
  )
  @test.assert_eq(ops, [
    Op_BT,
    Op_Tf(f1, 10.0),
    Op_Tj(draw_bytes_for_test([1])),
    Op_Tf(f2, 10.0),
    Op_Tj(draw_bytes_for_test([2, 3])),
    Op_Tf(f1, 10.0),
    Op_Tj(draw_bytes_for_test([4])),
    Op_ET,
  ])

  guard document.lookup_object_or_null(1) is PdfDictionary(_) else {
    fail("expected first written font object")
  }
  guard document.lookup_object_or_null(2) is PdfDictionary(_) else {
    fail("expected second written font object")
  }
  guard state.resources().lookup_immediate(font_key) is Some(fonts) else {
    fail("expected Font resources")
  }
  @test.assert_eq(fonts.lookup_immediate(f1), Some(PdfIndirect(1)))
  @test.assert_eq(fonts.lookup_immediate(f2), Some(PdfIndirect(2)))
}

///|
test "pdf draw special text expands page-local replacements" {
  let document = @pdflite.pdf_document_empty()
  let state = @pdflite.pdf_draw_render_state_new()
  let font = draw_standard_font_for_test(PdfHelvetica)
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  let context = @pdflite.pdf_draw_special_text_context(draw_time_for_test(), {
    page_number: 3,
    end_page: 5,
    filename: "input.pdf",
    page_label: "p.3",
    end_label: "p.5",
    bates: 98,
    bates_pad: Some(4),
    bookmarks: ["Chapter", "Section", "", "", ""],
  })
  let f1 = draw_name_for_test("/F1")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_document_context(
    state,
    document,
    context,
    [
      PdfDrawTextSection([
        PdfDrawFontPack("Body", pack, []),
        PdfDrawFont("Body", 10.0),
        PdfDrawSpecialText(
          "%Page|%EndPage|%Label|%EndLabel|%Bookmark0|%Bates|%Y",
        ),
      ]),
    ],
  )
  @test.assert_eq(ops, [
    Op_BT,
    Op_Tf(f1, 10.0),
    Op_Tj(@ascii.encode("3|5|p.3|p.5|Chapter|0100|2023")),
    Op_ET,
  ])
}

///|
test "PdfDocument draw_special_text_context derives add-text replacements" {
  let document = try! @pdflite.pdf_blank_document(10.0, 10.0, 3)
  let labelled = try! document.write_page_labels([
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: Some(@ascii.encode("p.")),
      start_page: 1,
      start_value: 10,
    },
  ])
  let context = try! labelled.draw_special_text_context(
    2,
    filename="input.pdf",
    bates=7,
    bates_pad=Some(3),
    time=Some(draw_time_for_test()),
  )
  let values = context.replacement_values
  @test.assert_eq(values.page_number, 2)
  @test.assert_eq(values.end_page, 3)
  @test.assert_eq(values.filename, "input.pdf")
  @test.assert_eq(values.page_label, "p.11")
  @test.assert_eq(values.end_label, "p.12")
  @test.assert_eq(values.bates, 7)
  @test.assert_eq(values.bates_pad, Some(3))
}

///|
test "pdf draw paragraph renders selected fontpack text" {
  let document = @pdflite.pdf_document_empty()
  let state = @pdflite.pdf_draw_render_state_new()
  let font = draw_standard_font_for_test(PdfHelvetica)
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  let f1 = draw_name_for_test("/F1")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_document(
    state,
    document,
    [
      PdfDrawTextSection([
        PdfDrawFontPack("Body", pack, []),
        PdfDrawFont("Body", 10.0),
        PdfDrawPara(None, PdfDrawLeft, 200.0, ["AB"]),
      ]),
    ],
  )
  @test.assert_eq(ops, [
    Op_BT,
    Op_Tstar,
    Op_Td(-0.0, 0.0),
    Op_Tf(f1, 10.0),
    Op_Tj(draw_bytes_for_test([65, 66])),
    Op_Td(0.0, 0.0),
    Op_ET,
  ])
}

///|
test "pdf draw paragraph wraps lines and cleans duplicate text ops" {
  let document = @pdflite.pdf_document_empty()
  let state = @pdflite.pdf_draw_render_state_new()
  let font = draw_standard_font_for_test(PdfHelvetica)
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  let widths = try! @pdflite.pdf_type_font_widths(font, 10.0)
  let line_width = widths[65] + widths[32] + widths[65] - 0.01
  let f1 = draw_name_for_test("/F1")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_document(
    state,
    document,
    [
      PdfDrawTextSection([
        PdfDrawFontPack("Body", pack, []),
        PdfDrawFont("Body", 10.0),
        PdfDrawPara(None, PdfDrawLeft, line_width, ["A A"]),
      ]),
    ],
  )
  @test.assert_eq(ops, [
    Op_BT,
    Op_Tstar,
    Op_Td(-0.0, 0.0),
    Op_Tf(f1, 10.0),
    Op_Tj(draw_bytes_for_test([65])),
    Op_Td(0.0, 0.0),
    Op_Tstar,
    Op_Tj(draw_bytes_for_test([65])),
    Op_ET,
  ])
}

///|
test "pdf draw paragraph preserves cpdf multi paragraph breaks" {
  let document = @pdflite.pdf_document_empty()
  let state = @pdflite.pdf_draw_render_state_new()
  let font = draw_standard_font_for_test(PdfHelvetica)
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  let f1 = draw_name_for_test("/F1")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_document(
    state,
    document,
    [
      PdfDrawTextSection([
        PdfDrawFontPack("Body", pack, []),
        PdfDrawFont("Body", 10.0),
        PdfDrawPara(None, PdfDrawLeft, 200.0, ["A", "B"]),
      ]),
    ],
  )
  @test.assert_eq(ops, [
    Op_BT,
    Op_Tstar,
    Op_Td(-0.0, 0.0),
    Op_Tf(f1, 10.0),
    Op_Tj(draw_bytes_for_test([65])),
    Op_Td(0.0, 0.0),
    Op_Tstar,
    Op_Tstar,
    Op_Td(-0.0, 0.0),
    Op_Tf(f1, 10.0),
    Op_Tj(draw_bytes_for_test([66])),
    Op_Td(0.0, 0.0),
    Op_ET,
  ])
}

///|
test "pdf draw tagged content emits sequential MCIDs" {
  let state = @pdflite.pdf_draw_render_state_new()
  let span = draw_name_for_test("/Span")
  let p = draw_name_for_test("/P")
  let mcid = draw_name_for_test("/MCID")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_state(state, [
    PdfDrawTag("Span"),
    PdfDrawEndTag,
    PdfDrawTag("P"),
    PdfDrawEndTag,
  ])
  @test.assert_eq(ops, [
    Op_BDC(span, PdfDictionary([(mcid, PdfInteger(0))])),
    Op_EMC,
    Op_BDC(p, PdfDictionary([(mcid, PdfInteger(1))])),
    Op_EMC,
  ])
}

///|
test "pdf draw manual artifacts use cpdf back-channel markers" {
  let begin_artifact = draw_name_for_test("/BeginArtifact")
  let end_artifact = draw_name_for_test("/EndArtifact")
  let artifact = draw_name_for_test("/Artifact")
  let raw = try! @pdflite.pdf_drawops_to_content_ops([
    PdfDrawBeginArtifact,
    PdfDrawEndArtifact,
  ])
  @test.assert_eq(raw, [Op_BMC(begin_artifact), Op_BMC(end_artifact)])
  @test.assert_eq(@pdflite.pdf_content_add_artifacts(raw), [
    Op_BMC(artifact),
    Op_EMC,
  ])
}

///|
test "pdf draw structure metadata ops are content-empty" {
  let ops = try! @pdflite.pdf_drawops_to_content_ops([
    PdfDrawSTag("P"),
    PdfDrawEndSTag,
    PdfDrawNamespace("http://iso.org/pdf/ssn"),
    PdfDrawEltInfo("Lang", PdfString(@ascii.encode("en-US"))),
    PdfDrawEndEltInfo("Lang"),
    PdfDrawAutoTag(false),
  ])
  @test.assert_eq(ops, [])
}

///|
test "pdf draw font selection reports missing fontpack" {
  let state = @pdflite.pdf_draw_render_state_new()
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_drawop_to_content_ops_with_state(
    state,
    PdfDrawFont("Missing", 12.0),
  )
  guard result is Err(@pdflite.PdfError::SoftError(message)) else {
    fail("expected SoftError for missing fontpack")
  }
  @test.assert_eq(message, "FontPack not found: Missing")
}

///|
test "pdf draw text reports missing selected fontpack" {
  let state = @pdflite.pdf_draw_render_state_new()
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_drawop_to_content_ops_with_state(
    state,
    PdfDrawText("hello"),
  )
  guard result is Err(@pdflite.PdfError::SoftError(message)) else {
    fail("expected SoftError for unselected fontpack")
  }
  @test.assert_eq(message, "FontPack not selected")
}

///|
test "pdf draw special text requires replacement context" {
  let state = @pdflite.pdf_draw_render_state_new()
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_drawop_to_content_ops_with_state(
    state,
    PdfDrawSpecialText("%Page"),
  )
  guard result is Err(@pdflite.PdfError::SoftError(message)) else {
    fail("expected SoftError for missing special-text context")
  }
  @test.assert_eq(message, "Cpdfdraw: unsupported draw operation SpecialText")
}

///|
test "pdf draw render state caches opacity ExtGState resources" {
  let state = @pdflite.pdf_draw_render_state_new()
  let g1 = draw_name_for_test("/G1")
  let g2 = draw_name_for_test("/G2")
  let extgstate = draw_name_for_test("/ExtGState")
  let ca = draw_name_for_test("/ca")
  let ca_stroke = draw_name_for_test("/CA")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_state(state, [
    PdfDrawOpacity(0.5),
    PdfDrawSOpacity(0.25),
    PdfDrawQq([PdfDrawOpacity(0.5)]),
    PdfDrawTextSection([PdfDrawSOpacity(0.25)]),
  ])
  @test.assert_eq(ops, [
    Op_gs(g1),
    Op_gs(g2),
    Op_q,
    Op_gs(g1),
    Op_Q,
    Op_BT,
    Op_gs(g2),
    Op_ET,
  ])

  guard state.resources().lookup_immediate(extgstate) is Some(resources) else {
    fail("expected ExtGState resources")
  }
  @test.assert_eq(
    resources.lookup_immediate(g1),
    Some(PdfDictionary([(ca, PdfReal(0.5))])),
  )
  @test.assert_eq(
    resources.lookup_immediate(g2),
    Some(PdfDictionary([(ca_stroke, PdfReal(0.25))])),
  )
}

///|
test "pdf draw document-aware image XObjects register resources and emit Do" {
  let document = @pdflite.pdf_document_empty()
  let state = @pdflite.pdf_draw_render_state_new()
  let image_object : @pdflite.PdfObject = PdfDictionary([
    (
      draw_name_for_test("/Subtype"),
      PdfNameObject(draw_name_for_test("/Image")),
    ),
  ])
  let im1 = draw_name_for_test("/I1")
  let xobject = draw_name_for_test("/XObject")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_document(
    state,
    document,
    [
      PdfDrawImageXObject("logo", image_object),
      PdfDrawImage("logo"),
      PdfDrawQq([PdfDrawImage("logo")]),
    ],
  )
  @test.assert_eq(ops, [Op_Do(im1), Op_q, Op_Do(im1), Op_Q])
  @test.assert_eq(document.lookup_object_or_null(1), image_object)

  guard state.resources().lookup_immediate(xobject) is Some(xobjects) else {
    fail("expected XObject resources")
  }
  @test.assert_eq(xobjects.lookup_immediate(im1), Some(PdfIndirect(1)))
}

///|
test "pdf draw image XObject replacement follows latest source mapping" {
  let document = @pdflite.pdf_document_empty()
  let state = @pdflite.pdf_draw_render_state_new()
  let first : @pdflite.PdfObject = PdfDictionary([
    (draw_name_for_test("/Name"), PdfNameObject(draw_name_for_test("/First"))),
  ])
  let second : @pdflite.PdfObject = PdfDictionary([
    (draw_name_for_test("/Name"), PdfNameObject(draw_name_for_test("/Second"))),
  ])
  let im2 = draw_name_for_test("/I2")
  let xobject = draw_name_for_test("/XObject")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_document(
    state,
    document,
    [
      PdfDrawImageXObject("logo", first),
      PdfDrawImageXObject("logo", second),
      PdfDrawImage("logo"),
    ],
  )
  @test.assert_eq(ops, [Op_Do(im2)])
  @test.assert_eq(document.lookup_object_or_null(1), first)
  @test.assert_eq(document.lookup_object_or_null(2), second)

  guard state.resources().lookup_immediate(xobject) is Some(xobjects) else {
    fail("expected XObject resources")
  }
  @test.assert_eq(xobjects.lookup_immediate(draw_name_for_test("/I1")), None)
  @test.assert_eq(xobjects.lookup_immediate(im2), Some(PdfIndirect(2)))
}

///|
test "pdf draw image use reports missing image name" {
  let state = @pdflite.pdf_draw_render_state_new()
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_drawop_to_content_ops_with_state(
    state,
    PdfDrawImage("missing"),
  )
  guard result is Err(@pdflite.PdfError::SoftError(message)) else {
    fail("expected SoftError for missing image")
  }
  @test.assert_eq(message, "Image not found: missing")
}

///|
test "pdf draw document-aware form XObjects register streams and emit Do" {
  let document = @pdflite.pdf_document_empty()
  let state = @pdflite.pdf_draw_render_state_new()
  let x1 = draw_name_for_test("/X1")
  let xobject = draw_name_for_test("/XObject")
  let subtype = draw_name_for_test("/Subtype")
  let form = draw_name_for_test("/Form")
  let resources = draw_name_for_test("/Resources")
  let bbox = draw_name_for_test("/BBox")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_document(
    state,
    document,
    [
      PdfDrawFormXObject(0.0, 0.0, 20.0, 30.0, "stamp", [
        PdfDrawRect(1.0, 2.0, 3.0, 4.0),
        PdfDrawStroke,
      ]),
      PdfDrawUse("stamp"),
    ],
  )
  @test.assert_eq(ops, [Op_Do(x1)])

  let form_object = document.lookup_object_or_null(1)
  guard form_object is PdfStreamObject(stream) else {
    fail("expected form XObject stream")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(subtype),
    Some(PdfNameObject(form)),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(resources),
    Some(PdfDictionary([])),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(bbox),
    Some(PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(20.0), PdfReal(30.0)])),
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(
      try! form_object.stream_bytes(),
    ),
    [Op_re(1.0, 2.0, 3.0, 4.0), Op_S],
  )

  guard state.resources().lookup_immediate(xobject) is Some(xobjects) else {
    fail("expected XObject resources")
  }
  @test.assert_eq(xobjects.lookup_immediate(x1), Some(PdfIndirect(1)))
}

///|
test "pdf draw form XObjects carry nested image resources" {
  let document = @pdflite.pdf_document_empty()
  let state = @pdflite.pdf_draw_render_state_new()
  let image_object : @pdflite.PdfObject = PdfDictionary([
    (
      draw_name_for_test("/Subtype"),
      PdfNameObject(draw_name_for_test("/Image")),
    ),
  ])
  let im1 = draw_name_for_test("/I1")
  let x2 = draw_name_for_test("/X2")
  let xobject = draw_name_for_test("/XObject")
  let resources = draw_name_for_test("/Resources")
  let ops = try! @pdflite.pdf_drawops_to_content_ops_with_document(
    state,
    document,
    [
      PdfDrawImageXObject("logo", image_object),
      PdfDrawFormXObject(0.0, 0.0, 10.0, 10.0, "stamp", [PdfDrawImage("logo")]),
      PdfDrawUse("stamp"),
    ],
  )
  @test.assert_eq(ops, [Op_Do(x2)])
  @test.assert_eq(document.lookup_object_or_null(1), image_object)

  let form_object = document.lookup_object_or_null(2)
  guard form_object is PdfStreamObject(stream) else {
    fail("expected form XObject stream")
  }
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_ops_from_bytes(
      try! form_object.stream_bytes(),
    ),
    [Op_Do(im1)],
  )
  guard stream.dictionary.lookup_immediate(resources) is Some(form_resources) else {
    fail("expected form resources")
  }
  guard form_resources.lookup_immediate(xobject) is Some(form_xobjects) else {
    fail("expected nested XObject resources")
  }
  @test.assert_eq(form_xobjects.lookup_immediate(im1), Some(PdfIndirect(1)))

  guard state.resources().lookup_immediate(xobject) is Some(page_xobjects) else {
    fail("expected page XObject resources")
  }
  @test.assert_eq(page_xobjects.lookup_immediate(im1), None)
  @test.assert_eq(page_xobjects.lookup_immediate(x2), Some(PdfIndirect(2)))
}

///|
test "pdf draw form use reports missing form name" {
  let state = @pdflite.pdf_draw_render_state_new()
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_drawop_to_content_ops_with_state(
    state,
    PdfDrawUse("missing"),
  )
  guard result is Err(@pdflite.PdfError::SoftError(message)) else {
    fail("expected SoftError for missing form XObject")
  }
  @test.assert_eq(message, "Form XObject not found: missing")
}

///|
test "PdfDocument draw appends operators to selected pages" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 2)
  let drawn = try! document.draw([2], [
    PdfDrawRect(1.0, 2.0, 3.0, 4.0),
    PdfDrawStroke,
  ])
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 1), [])
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 2), [
    Op_re(1.0, 2.0, 3.0, 4.0),
    Op_S,
  ])
}

///|
test "PdfDocument draw can prepend underneath existing content" {
  let base = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let pages = try! base.pages_of_pagetree()
  let page = {
    ..pages[0],
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_re(10.0, 20.0, 30.0, 40.0),
        Op_S,
      ]),
    ],
  }
  let document = try! base.change_pages([page])
  let drawn = try! document.draw(
    [1],
    [PdfDrawRect(1.0, 2.0, 3.0, 4.0), PdfDrawFill],
    underneath=true,
  )
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 1), [
    Op_re(1.0, 2.0, 3.0, 4.0),
    Op_f,
    Op_re(10.0, 20.0, 30.0, 40.0),
    Op_S,
  ])
}

///|
test "PdfDocument draw expands special text per selected page" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 2)
  let font = draw_standard_font_for_test(PdfHelvetica)
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  let f1 = draw_name_for_test("/F1")
  let drawn = try! document.draw(
    [1, 2],
    [
      PdfDrawTextSection([
        PdfDrawFontPack("Body", pack, []),
        PdfDrawFont("Body", 10.0),
        PdfDrawSpecialText("%Page"),
      ]),
    ],
    time=Some(draw_time_for_test()),
  )
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 1), [
    Op_BT,
    Op_Tf(f1, 10.0),
    Op_Tj(@ascii.encode("1")),
    Op_ET,
  ])
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 2), [
    Op_BT,
    Op_Tf(f1, 10.0),
    Op_Tj(@ascii.encode("2")),
    Op_ET,
  ])
}

///|
test "PdfDocument draw starts resource names above selected page resources" {
  let base = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let pages = try! base.pages_of_pagetree()
  let font_key = draw_name_for_test("/Font")
  let old_font = draw_name_for_test("/F1")
  let new_font = draw_name_for_test("/F3")
  let page = {
    ..pages[0],
    resources: PdfDictionary([
      (font_key, PdfDictionary([(old_font, PdfIndirect(99))])),
    ]),
  }
  let document = try! base.change_pages([page])
  let font = draw_standard_font_for_test(PdfHelvetica)
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  let drawn = try! document.draw([1], [
    PdfDrawTextSection([
      PdfDrawFontPack("Body", pack, []),
      PdfDrawFont("Body", 10.0),
      PdfDrawText("A"),
    ]),
  ])
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 1), [
    Op_BT,
    Op_Tf(new_font, 10.0),
    Op_Tj(@ascii.encode("A")),
    Op_ET,
  ])
  let drawn_page = (try! drawn.pages_of_pagetree())[0]
  guard drawn_page.resources.lookup_immediate(font_key) is Some(fonts) else {
    fail("expected Font resources")
  }
  @test.assert_eq(fonts.lookup_immediate(old_font), Some(PdfIndirect(99)))
  guard fonts.lookup_immediate(new_font) is Some(PdfIndirect(_)) else {
    fail("expected new indirect font resource")
  }
}

///|
test "PdfDocument draw splits chunks around NewPage and pads at document end" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let drawn = try! document.draw([1], [
    PdfDrawRect(1.0, 2.0, 3.0, 4.0),
    PdfDrawStroke,
    PdfDrawNewPage,
    PdfDrawRect(5.0, 6.0, 7.0, 8.0),
    PdfDrawFill,
  ])
  @test.assert_eq(try! drawn.endpage(), 2)
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 1), [
    Op_re(1.0, 2.0, 3.0, 4.0),
    Op_S,
  ])
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 2), [
    Op_re(5.0, 6.0, 7.0, 8.0),
    Op_f,
  ])
}

///|
test "PdfDocument draw trailing NewPage adds one blank page" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let drawn = try! document.draw([1], [
    PdfDrawRect(1.0, 2.0, 3.0, 4.0),
    PdfDrawStroke,
    PdfDrawNewPage,
  ])
  @test.assert_eq(try! drawn.endpage(), 2)
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 1), [
    Op_re(1.0, 2.0, 3.0, 4.0),
    Op_S,
  ])
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 2), [])
}

///|
test "PdfDocument draw structure-tree mode writes MCID parent tree" {
  let document = draw_fresh_structure_document_for_test()
  let drawn = try! document.draw(
    [1],
    [PdfDrawTag("Span"), PdfDrawEndTag],
    struct_tree=true,
  )
  let page_refs = try! drawn.page_reference_numbers()
  let key_k = draw_name_for_test("/K")
  let key_s = draw_name_for_test("/S")
  let key_pg = draw_name_for_test("/Pg")
  let key_parent_tree = draw_name_for_test("/ParentTree")
  let key_struct_tree_root = draw_name_for_test("/StructTreeRoot")
  let key_struct_parents = draw_name_for_test("/StructParents")
  let catalog = try! drawn.catalog()
  guard catalog.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(root_number)) else {
    fail("expected StructTreeRoot reference")
  }
  let root = drawn.lookup_object_or_null(root_number)
  guard root.lookup_immediate(key_k)
    is Some(PdfArray([PdfIndirect(span_number)])) else {
    fail("expected one structure child")
  }
  let span = drawn.lookup_object_or_null(span_number)
  @test.assert_eq(
    span.lookup_immediate(key_s),
    Some(PdfNameObject(draw_name_for_test("/Span"))),
  )
  @test.assert_eq(
    span.lookup_immediate(key_pg),
    Some(PdfIndirect(page_refs[0])),
  )
  @test.assert_eq(span.lookup_immediate(key_k), Some(PdfArray([PdfInteger(0)])))
  let pages = try! drawn.pages_of_pagetree()
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_struct_parents),
    Some(PdfInteger(page_refs[0])),
  )
  guard root.lookup_immediate(key_parent_tree)
    is Some(PdfIndirect(parent_tree_number)) else {
    fail("expected ParentTree")
  }
  @test.assert_eq(
    drawn.read_number_tree(drawn.lookup_object_or_null(parent_tree_number)),
    [(page_refs[0], PdfArray([PdfIndirect(span_number)]))],
  )
}

///|
test "PdfDocument draw structure-tree mode preserves nesting and namespaces" {
  let document = draw_fresh_structure_document_for_test()
  let drawn = try! document.draw(
    [1],
    [
      PdfDrawNamespace("http://iso.org/pdf2/ssn"),
      PdfDrawEltInfo("Lang", PdfString(@ascii.encode("en-US"))),
      PdfDrawSTag("Document"),
      PdfDrawTag("Span"),
      PdfDrawEndTag,
      PdfDrawEndSTag,
      PdfDrawEndEltInfo("Lang"),
    ],
    struct_tree=true,
  )
  let key_k = draw_name_for_test("/K")
  let key_s = draw_name_for_test("/S")
  let key_ns = draw_name_for_test("/NS")
  let key_namespaces = draw_name_for_test("/Namespaces")
  let key_lang = draw_name_for_test("/Lang")
  let key_struct_tree_root = draw_name_for_test("/StructTreeRoot")
  let catalog = try! drawn.catalog()
  guard catalog.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(root_number)) else {
    fail("expected StructTreeRoot reference")
  }
  let root = drawn.lookup_object_or_null(root_number)
  guard root.lookup_immediate(key_namespaces)
    is Some(PdfArray([PdfIndirect(namespace_number)])) else {
    fail("expected namespace array")
  }
  @test.assert_eq(
    drawn.lookup_object_or_null(namespace_number).lookup_immediate(key_ns),
    Some(PdfString(@ascii.encode("http://iso.org/pdf2/ssn"))),
  )
  guard root.lookup_immediate(key_k)
    is Some(PdfArray([PdfIndirect(document_number)])) else {
    fail("expected top-level document node")
  }
  let document_node = drawn.lookup_object_or_null(document_number)
  @test.assert_eq(
    document_node.lookup_immediate(key_s),
    Some(PdfNameObject(draw_name_for_test("/Document"))),
  )
  @test.assert_eq(
    document_node.lookup_immediate(key_ns),
    Some(PdfIndirect(namespace_number)),
  )
  @test.assert_eq(
    document_node.lookup_immediate(key_lang),
    Some(PdfString(@ascii.encode("en-US"))),
  )
  guard document_node.lookup_immediate(key_k)
    is Some(PdfArray([PdfIndirect(span_number)])) else {
    fail("expected nested span")
  }
  let span = drawn.lookup_object_or_null(span_number)
  @test.assert_eq(
    span.lookup_immediate(key_s),
    Some(PdfNameObject(draw_name_for_test("/Span"))),
  )
}

///|
test "PdfDocument draw structure-tree mode auto-tags text" {
  let document = draw_fresh_structure_document_for_test()
  let font = draw_standard_font_for_test(PdfHelvetica)
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  let drawn = try! document.draw(
    [1],
    [
      PdfDrawTextSection([
        PdfDrawFontPack("Body", pack, []),
        PdfDrawFont("Body", 10.0),
        PdfDrawText("A"),
      ]),
    ],
    struct_tree=true,
  )
  let key_k = draw_name_for_test("/K")
  let key_s = draw_name_for_test("/S")
  let key_struct_tree_root = draw_name_for_test("/StructTreeRoot")
  let catalog = try! drawn.catalog()
  guard catalog.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(root_number)) else {
    fail("expected StructTreeRoot reference")
  }
  let root = drawn.lookup_object_or_null(root_number)
  guard root.lookup_immediate(key_k)
    is Some(PdfArray([PdfIndirect(paragraph_number)])) else {
    fail("expected auto-tagged paragraph")
  }
  let paragraph = drawn.lookup_object_or_null(paragraph_number)
  @test.assert_eq(
    paragraph.lookup_immediate(key_s),
    Some(PdfNameObject(draw_name_for_test("/P"))),
  )
  @test.assert_eq(
    paragraph.lookup_immediate(key_k),
    Some(PdfArray([PdfInteger(0)])),
  )
}

///|
test "PdfDocument draw structure-tree mode honors AutoTag false" {
  let document = draw_fresh_structure_document_for_test()
  let font = draw_standard_font_for_test(PdfHelvetica)
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  let drawn = try! document.draw(
    [1],
    [
      PdfDrawTextSection([
        PdfDrawFontPack("Body", pack, []),
        PdfDrawFont("Body", 10.0),
        PdfDrawAutoTag(false),
        PdfDrawText("A"),
      ]),
    ],
    struct_tree=true,
  )
  let key_k = draw_name_for_test("/K")
  let key_parent_tree = draw_name_for_test("/ParentTree")
  let key_struct_tree_root = draw_name_for_test("/StructTreeRoot")
  let key_struct_parents = draw_name_for_test("/StructParents")
  let catalog = try! drawn.catalog()
  guard catalog.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(root_number)) else {
    fail("expected StructTreeRoot reference")
  }
  let root = drawn.lookup_object_or_null(root_number)
  @test.assert_eq(root.lookup_immediate(key_k), Some(PdfArray([])))
  guard root.lookup_immediate(key_parent_tree)
    is Some(PdfIndirect(parent_tree_number)) else {
    fail("expected ParentTree")
  }
  @test.assert_eq(
    drawn.read_number_tree(drawn.lookup_object_or_null(parent_tree_number)),
    [],
  )
  let pages = try! drawn.pages_of_pagetree()
  @test.assert_eq(pages[0].rest.lookup_immediate(key_struct_parents), None)
}

///|
test "PdfDocument draw structure-tree mode writes role map" {
  let document = draw_fresh_structure_document_for_test()
  let drawn = try! document.draw(
    [1],
    [PdfDrawSTag("H1"), PdfDrawEndSTag],
    struct_tree=true,
    role_map="/H1 /H /Aside /Div",
  )
  let key_role_map = draw_name_for_test("/RoleMap")
  let key_struct_tree_root = draw_name_for_test("/StructTreeRoot")
  let key_h1 = draw_name_for_test("/H1")
  let key_h = draw_name_for_test("/H")
  let key_aside = draw_name_for_test("/Aside")
  let key_div = draw_name_for_test("/Div")
  let catalog = try! drawn.catalog()
  guard catalog.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(root_number)) else {
    fail("expected StructTreeRoot reference")
  }
  let root = drawn.lookup_object_or_null(root_number)
  guard root.lookup_immediate(key_role_map) is Some(role_map) else {
    fail("expected RoleMap")
  }
  @test.assert_eq(role_map.lookup_immediate(key_h1), Some(PdfNameObject(key_h)))
  @test.assert_eq(
    role_map.lookup_immediate(key_aside),
    Some(PdfNameObject(key_div)),
  )
}

///|
test "PdfDocument draw structure-tree mode preserves existing structure tree" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let key_root = draw_name_for_test("/Root")
  let key_struct_tree_root = draw_name_for_test("/StructTreeRoot")
  let key_type = draw_name_for_test("/Type")
  let key_k = draw_name_for_test("/K")
  let key_role_map = draw_name_for_test("/RoleMap")
  let key_artifact = draw_name_for_test("/Artifact")
  let existing_tree : @pdflite.PdfObject = PdfDictionary([
    (key_type, PdfNameObject(key_struct_tree_root)),
    (key_k, PdfInteger(99)),
  ])
  try! document.replace_chain([key_root, key_struct_tree_root], existing_tree)
  let drawn = try! document.draw(
    [1],
    [PdfDrawRect(1.0, 2.0, 3.0, 4.0), PdfDrawStroke],
    struct_tree=true,
    role_map="/H1 /H",
  )
  let catalog = try! drawn.catalog()
  guard catalog.lookup_immediate(key_struct_tree_root) is Some(tree) else {
    fail("expected existing StructTreeRoot")
  }
  @test.assert_eq(tree, existing_tree)
  @test.assert_eq(tree.lookup_immediate(key_role_map), None)
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 1), [
    Op_BMC(key_artifact),
    Op_re(1.0, 2.0, 3.0, 4.0),
    Op_S,
    Op_EMC,
  ])
}

///|
test "PdfDocument draw structure-tree mode without placeholder artifacts content" {
  let document = try! @pdflite.pdf_blank_document(100.0, 50.0, 1)
  let key_struct_tree_root = draw_name_for_test("/StructTreeRoot")
  let key_artifact = draw_name_for_test("/Artifact")
  let drawn = try! document.draw(
    [1],
    [PdfDrawRect(5.0, 6.0, 7.0, 8.0), PdfDrawFill],
    struct_tree=true,
  )
  let catalog = try! drawn.catalog()
  @test.assert_eq(catalog.lookup_immediate(key_struct_tree_root), None)
  @test.assert_eq(try! draw_page_ops_for_test(drawn, 1), [
    Op_BMC(key_artifact),
    Op_re(5.0, 6.0, 7.0, 8.0),
    Op_f,
    Op_EMC,
  ])
}

///|
test "pdf draw unsupported content op returns cpdf-style soft error" {
  let result : Result[Array[@pdflite.PdfContentOp], Error] = try? @pdflite.pdf_drawop_to_content_ops(
    PdfDrawText("hello"),
  )
  guard result is Err(@pdflite.PdfError::SoftError(message)) else {
    fail("expected SoftError for unsupported draw text rendering")
  }
  @test.assert_eq(message, "Cpdfdraw: unsupported draw operation Text")
}

///|
test "pdf draw control collects main text push and xobject frames in order" {
  let control = @pdflite.pdf_draw_control_new()
  @test.assert_eq(try! control.current_frame_name(), "_MAIN")
  @test.assert_eq(control.depth(), 1)
  try! control.add_op(PdfDrawRect(0.0, 0.0, 10.0, 20.0))

  control.begin_text_section()
  @test.assert_eq(try! control.current_frame_name(), "_TEXT")
  try! control.add_op(PdfDrawFont("F0", 12.0))
  try! control.add_op(PdfDrawText("hello"))
  try! control.end_text_section()

  control.push_group()
  @test.assert_eq(try! control.current_frame_name(), "_PUSH")
  try! control.add_op(PdfDrawSetFill(PdfDrawRGB(1.0, 0.0, 0.0)))
  try! control.add_op(PdfDrawFill)
  try! control.pop_group()

  control.set_xobject_bbox({ x: 1.0, y: 2.0, width: 30.0, height: 40.0 })
  control.start_xobject("XO")
  @test.assert_eq(try! control.current_frame_name(), "XO")
  try! control.add_op(PdfDrawLine(3.0, 4.0))
  try! control.end_xobject()

  let expected : Array[@pdflite.PdfDrawOp] = [
    PdfDrawRect(0.0, 0.0, 10.0, 20.0),
    PdfDrawTextSection([PdfDrawFont("F0", 12.0), PdfDrawText("hello")]),
    PdfDrawQq([PdfDrawSetFill(PdfDrawRGB(1.0, 0.0, 0.0)), PdfDrawFill]),
    PdfDrawFormXObject(1.0, 2.0, 30.0, 40.0, "XO", [PdfDrawLine(3.0, 4.0)]),
  ]
  @test.assert_eq(control.ops(), expected)
  @test.assert_eq(
    @pdflite.pdf_string_of_drawops(control.ops()),
    " Rect TextSection ( Font F0  Text) Qq ( SetFill Fill) FormXObject ( Line)",
  )
  @test.assert_eq(control.depth(), 1)
}

///|
test "pdf draw control reports mismatched section closures" {
  let text = @pdflite.pdf_draw_control_new()
  let text_result : Result[Unit, Error] = try? text.end_text_section()
  guard text_result
    is Err(@pdflite.PdfError::SoftError("not in a text section at -et")) else {
    fail("expected text-section close error")
  }
  @test.assert_eq(text.depth(), 1)

  let group = @pdflite.pdf_draw_control_new()
  let group_result : Result[Unit, Error] = try? group.pop_group()
  guard group_result
    is Err(@pdflite.PdfError::SoftError("not in a pushed section at -pop")) else {
    fail("expected pushed-section close error")
  }
  @test.assert_eq(group.depth(), 1)
}

///|
test "pdf draw control command helpers append cpdf draw ops" {
  let control = @pdflite.pdf_draw_control_new()
  @test.assert_eq(control.auto_artifacts(), true)
  control.set_auto_artifacts(false)
  @test.assert_eq(control.auto_artifacts(), false)
  control.set_role_map("/H1 /H")
  @test.assert_eq(control.role_map(), "/H1 /H")
  try! control.set_stroke("red")
  try! control.set_fill("not-a-colour")
  try! control.add_tag("Span")
  try! control.add_structure_tag("P")
  try! control.end_tag()
  try! control.end_structure_tag()
  try! control.set_auto_tag(false)
  try! control.begin_artifact()
  try! control.end_artifact()
  try! control.add_namespace("NS")
  try! control.add_element_info("K", PdfNull)
  try! control.end_element_info("K")
  try! control.set_line_thickness("2.5")
  try! control.set_line_cap("square")
  try! control.set_line_join("bevel")
  try! control.set_miter_limit("4.5")
  try! control.set_dash_pattern("1 2 3")
  try! control.set_matrix("1 2 3 4 5 6")
  try! control.matrix_translate("7 8")
  try! control.matrix_rotate("0 0 0.5")
  try! control.matrix_scale("1 2 3 4")
  try! control.matrix_shear_x("1 2 0.25")
  try! control.matrix_shear_y("1 2 0.75")
  try! control.use_xobject("XO")

  let expected : Array[@pdflite.PdfDrawOp] = [
    PdfDrawSetStroke(PdfDrawRGB(1.0, 0.0, 0.0)),
    PdfDrawSetFill(PdfDrawNoCol),
    PdfDrawTag("Span"),
    PdfDrawSTag("P"),
    PdfDrawEndTag,
    PdfDrawEndSTag,
    PdfDrawAutoTag(false),
    PdfDrawBeginArtifact,
    PdfDrawEndArtifact,
    PdfDrawNamespace("NS"),
    PdfDrawEltInfo("K", PdfNull),
    PdfDrawEndEltInfo("K"),
    PdfDrawSetLineThickness(2.5),
    PdfDrawSetLineCap(2),
    PdfDrawSetLineJoin(2),
    PdfDrawSetMiterLimit(4.5),
    PdfDrawSetDashPattern([1.0, 2.0], 3.0),
    PdfDrawMatrix({ a: 1.0, b: 2.0, c: 3.0, d: 4.0, e: 5.0, f: 6.0 }),
    PdfDrawMatrix(@pdflite.transform_translate(7.0, 8.0)),
    PdfDrawMatrix(@pdflite.transform_rotate(@pdflite.point2(0.0, 0.0), 0.5)),
    PdfDrawMatrix(@pdflite.transform_scale(@pdflite.point2(1.0, 2.0), 3.0, 4.0)),
    PdfDrawMatrix(@pdflite.transform_shear_x(@pdflite.point2(1.0, 2.0), 0.25)),
    PdfDrawMatrix(@pdflite.transform_shear_y(@pdflite.point2(1.0, 2.0), 0.75)),
    PdfDrawUse("XO"),
  ]
  @test.assert_eq(control.ops(), expected)
}

///|
test "pdf draw control media and text-state helpers append cpdf draw ops" {
  let control = @pdflite.pdf_draw_control_new()
  try! control.add_image("Im0")
  try! control.add_new_page()
  try! control.add_opacity(0.5)
  try! control.add_stroke_opacity(0.25)
  try! control.add_leading(12.0)
  try! control.add_char_space(1.0)
  try! control.add_word_space(2.0)
  try! control.add_text_scale(90.0)
  try! control.add_render_mode(3)
  try! control.add_rise(4.0)
  try! control.add_newline()

  let expected : Array[@pdflite.PdfDrawOp] = [
    PdfDrawImage("Im0"),
    PdfDrawNewPage,
    PdfDrawOpacity(0.5),
    PdfDrawSOpacity(0.25),
    PdfDrawLeading(12.0),
    PdfDrawCharSpace(1.0),
    PdfDrawWordSpace(2.0),
    PdfDrawTextScale(90.0),
    PdfDrawRenderMode(3),
    PdfDrawRise(4.0),
    PdfDrawNewline,
  ]
  @test.assert_eq(control.ops(), expected)
}

///|
test "pdf draw control image data helpers append image XObjects" {
  let document = @pdflite.pdf_document_empty()
  let control = @pdflite.pdf_draw_control_new()
  let jpeg = draw_jpeg_for_test()
  let (png, png_idat) = draw_png_rgb_for_test()
  let jpeg2000 = draw_jpeg2000_for_test()
  try! control.add_jpeg_data("J0", jpeg)
  try! control.add_png_data(document, "P0", png)
  try! control.add_jpeg2000_data("JP0", jpeg2000)

  let ops = control.ops()
  @test.assert_eq(ops.length(), 3)
  guard ops[0] is PdfDrawImageXObject("J0", PdfStreamObject(jpeg_stream)) else {
    fail("expected JPEG image XObject op")
  }
  @test.assert_eq(
    jpeg_stream.dictionary.lookup_immediate(draw_name_for_test("/Filter")),
    Some(PdfNameObject(draw_name_for_test("/DCTDecode"))),
  )
  @test.assert_eq(
    jpeg_stream.dictionary.lookup_immediate(draw_name_for_test("/Width")),
    Some(PdfInteger(400)),
  )
  @test.assert_eq(jpeg_stream.data, StreamGot(jpeg))

  guard ops[1] is PdfDrawImageXObject("P0", PdfStreamObject(png_stream)) else {
    fail("expected PNG image XObject op")
  }
  @test.assert_eq(
    png_stream.dictionary.lookup_immediate(draw_name_for_test("/Filter")),
    Some(PdfNameObject(draw_name_for_test("/FlateDecode"))),
  )
  @test.assert_eq(
    png_stream.dictionary.lookup_immediate(draw_name_for_test("/Width")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    png_stream.dictionary.lookup_immediate(draw_name_for_test("/Height")),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(png_stream.data, StreamGot(png_idat))

  guard ops[2] is PdfDrawImageXObject("JP0", PdfStreamObject(jp2_stream)) else {
    fail("expected JPEG2000 image XObject op")
  }
  @test.assert_eq(
    jp2_stream.dictionary.lookup_immediate(draw_name_for_test("/Filter")),
    Some(PdfNameObject(draw_name_for_test("/JPXDecode"))),
  )
  @test.assert_eq(
    jp2_stream.dictionary.lookup_immediate(draw_name_for_test("/Height")),
    Some(PdfInteger(300)),
  )
  @test.assert_eq(jp2_stream.data, StreamGot(jpeg2000))
}

///|
test "pdf draw control image data helpers propagate parser errors" {
  let document = @pdflite.pdf_document_empty()
  let control = @pdflite.pdf_draw_control_new()
  let bad_jpeg : Result[Unit, Error] = try? control.add_jpeg_data(
    "Bad",
    draw_bytes_for_test([0xFF, 0xD8, 0xFF, 0xDB]),
  )
  guard bad_jpeg is Err(@pdflite.PdfError::BadJPEGHeader) else {
    fail("expected BadJPEGHeader")
  }
  let bad_png : Result[Unit, Error] = try? control.add_png_data(
    document,
    "Bad",
    draw_bytes_for_test([0x89, 0x50]),
  )
  guard bad_png is Err(@pdflite.PdfError::BadPNG(_)) else {
    fail("expected BadPNG")
  }
  let bad_jp2 : Result[Unit, Error] = try? control.add_jpeg2000_data(
    "Bad",
    draw_bytes_for_test([0x00, 0x00, 0x00, 0x0C, 0x6A]),
  )
  guard bad_jp2 is Err(@pdflite.PdfError::BadJPEG2000Header) else {
    fail("expected BadJPEG2000Header")
  }
}

///|
test "pdf draw control text helpers add fontpack once and font text ops" {
  let control = @pdflite.pdf_draw_control_new()
  let pack : @pdflite.PdfFontPack = { fonts: [], entries: [] }
  control.set_font("F0", 10.0)
  control.set_fontpack(Some(pack))
  control.begin_text_section()
  try! control.add_text("hello")
  try! control.add_special_text("world")
  try! control.end_text_section()

  let expected : Array[@pdflite.PdfDrawOp] = [
    PdfDrawTextSection([
      PdfDrawFontPack("F0", pack, []),
      PdfDrawFont("F0", 10.0),
      PdfDrawText("hello"),
      PdfDrawFont("F0", 10.0),
      PdfDrawSpecialText("world"),
    ]),
  ]
  @test.assert_eq(control.ops(), expected)
}

///|
test "pdf draw control paragraph helpers parse justification width and escaped newlines" {
  let document = @pdflite.pdf_document_empty()
  let control = @pdflite.pdf_draw_control_new()
  control.set_font("F1", 8.0)
  control.set_paragraph_indent(Some(3.0))
  control.begin_text_section()
  try! control.add_para(document, "L200=One")
  try! control.add_paras(document, "C100=One\\nTwo\\n")
  try! control.end_text_section()

  let expected : Array[@pdflite.PdfDrawOp] = [
    PdfDrawTextSection([
      PdfDrawFont("F1", 8.0),
      PdfDrawPara(None, PdfDrawLeft, 200.0, ["One"]),
      PdfDrawFont("F1", 8.0),
      PdfDrawPara(Some(3.0), PdfDrawCentre, 100.0, ["One", "Two"]),
    ]),
  ]
  @test.assert_eq(control.ops(), expected)
}

///|
fn draw_control_assert_soft_error_for_test(
  result : Result[Unit, Error],
  expected : String,
) -> Unit raise Error {
  guard result is Err(@pdflite.PdfError::SoftError(message)) else {
    fail("expected draw-control SoftError")
  }
  @test.assert_eq(message, expected)
}

///|
test "pdf draw control command helpers report cpdf parse errors" {
  let control = @pdflite.pdf_draw_control_new()
  draw_control_assert_soft_error_for_test(
    try? control.set_line_thickness("x"),
    "Thickness must be a number",
  )
  draw_control_assert_soft_error_for_test(
    try? control.set_line_cap("flat"),
    "Unknown cap type",
  )
  draw_control_assert_soft_error_for_test(
    try? control.set_line_join("flat"),
    "Unknown join type",
  )
  draw_control_assert_soft_error_for_test(
    try? control.set_miter_limit("x"),
    "Miter limit must be a number",
  )
  draw_control_assert_soft_error_for_test(
    try? control.set_dash_pattern("1 x"),
    "Dash pattern elements must one or more numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.set_matrix("1 2"),
    "Matrix must have six numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.set_matrix("1 x 3 4 5 6"),
    "Matrix elements must be numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.matrix_translate("1"),
    "-mtrans takes two numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.matrix_rotate("0 0"),
    "-mrot takes three numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.matrix_scale("1 2 3"),
    "-mscale takes four numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.matrix_shear_x("1 2"),
    "-mshearx takes three numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.matrix_shear_y("1 2"),
    "-msheary takes three numbers",
  )
}

///|
test "pdf draw control text helpers report cpdf parse errors" {
  let document = @pdflite.pdf_document_empty()
  draw_control_assert_soft_error_for_test(
    try? @pdflite.pdf_draw_control_new().add_text("outside"),
    "-text must be in a -bt / -et section",
  )
  draw_control_assert_soft_error_for_test(
    try? @pdflite.pdf_draw_control_new().add_special_text("outside"),
    "-stext must be in a -bt / -et section",
  )
  draw_control_assert_soft_error_for_test(
    try? @pdflite.pdf_draw_control_new().add_para(document, "L100=outside"),
    "-para must be in a -bt / -et section",
  )
  draw_control_assert_soft_error_for_test(
    try? @pdflite.pdf_draw_control_new().add_paras(document, "L100=outside"),
    "-paras must be in a -bt / -et section",
  )

  let control = @pdflite.pdf_draw_control_new()
  control.begin_text_section()
  draw_control_assert_soft_error_for_test(
    try? control.add_para(document, "X100=bad"),
    "Unknown justification specification",
  )
  draw_control_assert_soft_error_for_test(
    try? control.add_para(document, "L100=bad=extra"),
    "addjpeg: bad file specification",
  )
}

///|
test "pdf draw control path and paint helpers append cpdf draw ops" {
  let document = @pdflite.pdf_document_empty()
  let control = @pdflite.pdf_draw_control_new()
  try! control.add_rect(document, "1 2 3 4")
  try! control.add_to(document, "5 6")
  try! control.add_line(document, "7 8")
  try! control.add_bezier("1 2 3 4 5 6")
  try! control.add_bezier23("7 8 9 10")
  try! control.add_bezier13("11 12 13 14")
  try! control.stroke()
  try! control.fill()
  try! control.fill_even_odd()
  try! control.stroke_fill()
  try! control.stroke_fill_even_odd()
  try! control.clip()
  try! control.clip_even_odd()
  try! control.close_path()

  let expected : Array[@pdflite.PdfDrawOp] = [
    PdfDrawRect(1.0, 2.0, 3.0, 4.0),
    PdfDrawTo(5.0, 6.0),
    PdfDrawLine(7.0, 8.0),
    PdfDrawBezier(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    PdfDrawBezier23(7.0, 8.0, 9.0, 10.0),
    PdfDrawBezier13(11.0, 12.0, 13.0, 14.0),
    PdfDrawStroke,
    PdfDrawFill,
    PdfDrawFillEvenOdd,
    PdfDrawFillStroke,
    PdfDrawFillStrokeEvenOdd,
    PdfDrawClip,
    PdfDrawClipEvenOdd,
    PdfDrawClosePath,
  ]
  @test.assert_eq(control.ops(), expected)
}

///|
test "pdf draw control circle helper expands to move and bezier ops" {
  let control = @pdflite.pdf_draw_control_new()
  try! control.add_circle("10 20 5")
  let ops = control.ops()
  @test.assert_eq(ops.length(), 5)
  @test.assert_eq(ops[0], PdfDrawTo(15.0, 20.0))
  guard ops[1] is PdfDrawBezier(_, _, _, _, _, _) else {
    fail("expected circle quarter to be a Bezier op")
  }
}

///|
test "pdf draw control path helpers report cpdf parse errors" {
  let control = @pdflite.pdf_draw_control_new()
  draw_control_assert_soft_error_for_test(
    try? control.add_bezier("1 2 3"),
    "-bez requires six numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.add_bezier("1 x 3 4 5 6"),
    "malformed -bez",
  )
  draw_control_assert_soft_error_for_test(
    try? control.add_bezier23("1 2 3"),
    "-bez23 requires four numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.add_bezier23("1 x 3 4"),
    "malformed -bez23",
  )
  draw_control_assert_soft_error_for_test(
    try? control.add_bezier13("1 2 3"),
    "-bez13 requires four numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.add_bezier13("1 x 3 4"),
    "malformed -bez13",
  )
  draw_control_assert_soft_error_for_test(
    try? control.add_circle("1 2"),
    "-circle requires three numbers",
  )
  draw_control_assert_soft_error_for_test(
    try? control.add_circle("1 x 3"),
    "malformed -circle",
  )
}
