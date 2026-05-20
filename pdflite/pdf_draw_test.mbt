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
