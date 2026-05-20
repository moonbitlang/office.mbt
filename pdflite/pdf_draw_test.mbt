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
fn draw_standard_font_for_test(
  font : @pdflite.PdfStandardFont,
) -> @pdflite.PdfFont {
  PdfFontStandard({ font, encoding: PdfWinAnsiEncoding })
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
