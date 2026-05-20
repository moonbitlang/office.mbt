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
