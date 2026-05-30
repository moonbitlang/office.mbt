///|
fn draw_control_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn draw_control_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for value in values {
    output.push(try! @pdflite.pdf_byte_of_int(value))
  }
  Bytes::from_array(output)
}

///|
fn draw_control_append_bytes_for_test(
  output : Array[Byte],
  bytes : BytesView,
) -> Unit {
  for byte in bytes {
    output.push(byte)
  }
}

///|
fn draw_control_push_u32_for_test(output : Array[Byte], value : Int) -> Unit {
  output.push(try! @pdflite.pdf_byte_of_int((value >> 24) & 0xFF))
  output.push(try! @pdflite.pdf_byte_of_int((value >> 16) & 0xFF))
  output.push(try! @pdflite.pdf_byte_of_int((value >> 8) & 0xFF))
  output.push(try! @pdflite.pdf_byte_of_int(value & 0xFF))
}

///|
fn draw_control_png_chunk_for_test(
  chunk_type : ArrayView[Int],
  data : BytesView,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  draw_control_push_u32_for_test(output, data.length())
  for value in chunk_type {
    output.push(try! @pdflite.pdf_byte_of_int(value))
  }
  draw_control_append_bytes_for_test(output, data)
  draw_control_push_u32_for_test(output, 0)
  Bytes::from_array(output)
}

///|
fn draw_control_png_rgb_for_test() -> (@pdflite.PdfBytes, @pdflite.PdfBytes) {
  let header = draw_control_bytes_for_test([
    0, 0, 0, 2, 0, 0, 0, 1, 8, 2, 0, 0, 0,
  ])
  let idat = @flate.pdf_flate_encode(
    draw_control_bytes_for_test([0, 10, 20, 30, 40, 50, 60]),
  )
  let output : Array[Byte] = []
  for value in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
    output.push(try! @pdflite.pdf_byte_of_int(value))
  }
  draw_control_append_bytes_for_test(
    output,
    draw_control_png_chunk_for_test([0x49, 0x48, 0x44, 0x52], header),
  )
  draw_control_append_bytes_for_test(
    output,
    draw_control_png_chunk_for_test([0x49, 0x44, 0x41, 0x54], idat),
  )
  draw_control_append_bytes_for_test(
    output,
    draw_control_png_chunk_for_test([0x49, 0x45, 0x4E, 0x44], []),
  )
  (Bytes::from_array(output), idat)
}

///|
fn draw_control_jpeg_for_test() -> @pdflite.PdfBytes {
  draw_control_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x09, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xAA, 0xBB,
    0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x01, 0x2C, 0x01, 0x90, 0x03, 0x01, 0xFF, 0xD9,
  ])
}

///|
fn draw_control_jpeg2000_for_test() -> @pdflite.PdfBytes {
  draw_control_bytes_for_test([
    0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20, 0x0D, 0x0A, 0x87, 0x0A, 0x69,
    0x68, 0x64, 0x72, 0x00, 0x00, 0x01, 0x2C, 0x00, 0x00, 0x01, 0x90,
  ])
}

///|
fn draw_control_standard_font_for_test(
  font : @pdflite.PdfStandardFont,
) -> @pdflite.PdfFont {
  PdfFontStandard({ font, encoding: PdfWinAnsiEncoding })
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

  let document = @pdflite.pdf_document_empty()
  let alias_control = @pdflite.pdf_draw_control_new()
  try! @pdflite.pdf_addrect(alias_control, document, "0 0 10 20")
  alias_control.begin_text_section()
  try! alias_control.add_op(PdfDrawFont("F0", 12.0))
  try! alias_control.add_op(PdfDrawText("hello"))
  try! alias_control.end_text_section()
  @pdflite.pdf_push(alias_control)
  try! @pdflite.pdf_setfill(alias_control, "red")
  try! @pdflite.pdf_fill(alias_control)
  try! @pdflite.pdf_pop(alias_control)
  try! @pdflite.pdf_xobjbbox(alias_control, document, "1 2 30 40")
  @pdflite.pdf_startxobj(alias_control, "XO")
  try! @pdflite.pdf_addline(alias_control, document, "3 4")
  try! @pdflite.pdf_endxobj(alias_control)
  @test.assert_eq(alias_control.ops(), expected)

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
test "pdf draw control parses XObject bbox strings" {
  let document = @pdflite.pdf_document_empty()
  let control = @pdflite.pdf_draw_control_new()
  try! control.set_xobject_bbox_from_string(document, "1 2 30 40")
  control.start_xobject("XO")
  try! control.add_line(document, "3 4")
  try! control.end_xobject()

  @test.assert_eq(control.ops(), [
    PdfDrawFormXObject(1.0, 2.0, 30.0, 40.0, "XO", [PdfDrawLine(3.0, 4.0)]),
  ])

  let bad : Result[Unit, Error] = try? control.set_xobject_bbox_from_string(
    document, "1 2 3",
  )
  guard bad is Err(@pdflite.PdfError::BadRectangleSpecification("1 2 3")) else {
    fail("expected BadRectangleSpecification")
  }
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

  let alias_control = @pdflite.pdf_draw_control_new()
  @test.assert_eq(alias_control.auto_artifacts(), true)
  @pdflite.pdf_autoartifacts(alias_control, false)
  @test.assert_eq(alias_control.auto_artifacts(), false)
  @pdflite.pdf_setrolemap(alias_control, "/H1 /H")
  @test.assert_eq(alias_control.role_map(), "/H1 /H")
  try! @pdflite.pdf_setstroke(alias_control, "red")
  try! @pdflite.pdf_setfill(alias_control, "not-a-colour")
  try! @pdflite.pdf_addtag(alias_control, "Span")
  try! @pdflite.pdf_addstag(alias_control, "P")
  try! @pdflite.pdf_endtag(alias_control)
  try! @pdflite.pdf_endstag(alias_control)
  try! @pdflite.pdf_autotags(alias_control, false)
  try! @pdflite.pdf_artifact(alias_control)
  try! @pdflite.pdf_endartifact(alias_control)
  try! @pdflite.pdf_addnamespace(alias_control, "NS")
  try! @pdflite.pdf_eltinfo(alias_control, "K", PdfNull)
  try! @pdflite.pdf_endeltinfo(alias_control, "K")
  try! @pdflite.pdf_setthickness(alias_control, "2.5")
  try! @pdflite.pdf_setcap(alias_control, "square")
  try! @pdflite.pdf_setjoin(alias_control, "bevel")
  try! @pdflite.pdf_setmiter(alias_control, "4.5")
  try! @pdflite.pdf_setdash(alias_control, "1 2 3")
  try! @pdflite.pdf_setmatrix(alias_control, "1 2 3 4 5 6")
  try! @pdflite.pdf_setmtranslate(alias_control, "7 8")
  try! @pdflite.pdf_setmrotate(alias_control, "0 0 0.5")
  try! @pdflite.pdf_setmscale(alias_control, "1 2 3 4")
  try! @pdflite.pdf_setmshearx(alias_control, "1 2 0.25")
  try! @pdflite.pdf_setmsheary(alias_control, "1 2 0.75")
  try! @pdflite.pdf_usexobj(alias_control, "XO")
  @test.assert_eq(alias_control.ops(), expected)
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

  let alias_control = @pdflite.pdf_draw_control_new()
  try! @pdflite.pdf_addimage(alias_control, "Im0")
  try! @pdflite.pdf_addnewpage(alias_control)
  try! @pdflite.pdf_addopacity(alias_control, 0.5)
  try! @pdflite.pdf_addsopacity(alias_control, 0.25)
  try! @pdflite.pdf_addleading(alias_control, 12.0)
  try! @pdflite.pdf_addcharspace(alias_control, 1.0)
  try! @pdflite.pdf_addwordspace(alias_control, 2.0)
  try! @pdflite.pdf_addtextscale(alias_control, 90.0)
  try! @pdflite.pdf_addrendermode(alias_control, 3)
  try! @pdflite.pdf_addrise(alias_control, 4.0)
  try! @pdflite.pdf_addnewline(alias_control)
  @test.assert_eq(alias_control.ops(), expected)
}

///|
test "pdf draw control image data helpers append image XObjects" {
  let document = @pdflite.pdf_document_empty()
  let control = @pdflite.pdf_draw_control_new()
  let jpeg = draw_control_jpeg_for_test()
  let (png, png_idat) = draw_control_png_rgb_for_test()
  let jpeg2000 = draw_control_jpeg2000_for_test()
  try! control.add_jpeg_data("J0", jpeg)
  try! control.add_png_data(document, "P0", png)
  try! control.add_jpeg2000_data("JP0", jpeg2000)

  let ops = control.ops()
  @test.assert_eq(ops.length(), 3)
  guard ops[0] is PdfDrawImageXObject("J0", PdfStreamObject(jpeg_stream)) else {
    fail("expected JPEG image XObject op")
  }
  @test.assert_eq(
    jpeg_stream.dictionary.lookup_immediate(
      draw_control_name_for_test("/Filter"),
    ),
    Some(PdfNameObject(draw_control_name_for_test("/DCTDecode"))),
  )
  @test.assert_eq(
    jpeg_stream.dictionary.lookup_immediate(
      draw_control_name_for_test("/Width"),
    ),
    Some(PdfInteger(400)),
  )
  @test.assert_eq(jpeg_stream.data, StreamGot(jpeg))

  guard ops[1] is PdfDrawImageXObject("P0", PdfStreamObject(png_stream)) else {
    fail("expected PNG image XObject op")
  }
  @test.assert_eq(
    png_stream.dictionary.lookup_immediate(
      draw_control_name_for_test("/Filter"),
    ),
    Some(PdfNameObject(draw_control_name_for_test("/FlateDecode"))),
  )
  @test.assert_eq(
    png_stream.dictionary.lookup_immediate(draw_control_name_for_test("/Width")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    png_stream.dictionary.lookup_immediate(
      draw_control_name_for_test("/Height"),
    ),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(png_stream.data, StreamGot(png_idat))

  guard ops[2] is PdfDrawImageXObject("JP0", PdfStreamObject(jp2_stream)) else {
    fail("expected JPEG2000 image XObject op")
  }
  @test.assert_eq(
    jp2_stream.dictionary.lookup_immediate(
      draw_control_name_for_test("/Filter"),
    ),
    Some(PdfNameObject(draw_control_name_for_test("/JPXDecode"))),
  )
  @test.assert_eq(
    jp2_stream.dictionary.lookup_immediate(
      draw_control_name_for_test("/Height"),
    ),
    Some(PdfInteger(300)),
  )
  @test.assert_eq(jp2_stream.data, StreamGot(jpeg2000))

  let alias_control = @pdflite.pdf_draw_control_new()
  try! @pdflite.pdf_addjpeg(alias_control, "J0", jpeg)
  try! @pdflite.pdf_addpng(alias_control, document, "P0", png)
  try! @pdflite.pdf_addjpeg2000(alias_control, "JP0", jpeg2000)
  @test.assert_eq(alias_control.ops(), ops)
}

///|
test "pdf draw control image data helpers propagate parser errors" {
  let document = @pdflite.pdf_document_empty()
  let control = @pdflite.pdf_draw_control_new()
  let bad_jpeg : Result[Unit, Error] = try? control.add_jpeg_data(
    "Bad",
    draw_control_bytes_for_test([0xFF, 0xD8, 0xFF, 0xDB]),
  )
  guard bad_jpeg is Err(@pdflite.PdfError::BadJPEGHeader) else {
    fail("expected BadJPEGHeader")
  }
  let bad_png : Result[Unit, Error] = try? control.add_png_data(
    document,
    "Bad",
    draw_control_bytes_for_test([0x89, 0x50]),
  )
  guard bad_png is Err(@pdflite.PdfError::BadPNG(_)) else {
    fail("expected BadPNG")
  }
  let bad_jp2 : Result[Unit, Error] = try? control.add_jpeg2000_data(
    "Bad",
    draw_control_bytes_for_test([0x00, 0x00, 0x00, 0x0C, 0x6A]),
  )
  guard bad_jp2 is Err(@pdflite.PdfError::BadJPEG2000Header) else {
    fail("expected BadJPEG2000Header")
  }

  let alias_control = @pdflite.pdf_draw_control_new()
  let bad_alias_jpeg : Result[Unit, Error] = try? @pdflite.pdf_addjpeg(
    alias_control,
    "Bad",
    draw_control_bytes_for_test([0xFF, 0xD8, 0xFF, 0xDB]),
  )
  guard bad_alias_jpeg is Err(@pdflite.PdfError::BadJPEGHeader) else {
    fail("expected BadJPEGHeader through addjpeg wrapper")
  }
  let bad_alias_png : Result[Unit, Error] = try? @pdflite.pdf_addpng(
    alias_control,
    document,
    "Bad",
    draw_control_bytes_for_test([0x89, 0x50]),
  )
  guard bad_alias_png is Err(@pdflite.PdfError::BadPNG(_)) else {
    fail("expected BadPNG through addpng wrapper")
  }
  let bad_alias_jp2 : Result[Unit, Error] = try? @pdflite.pdf_addjpeg2000(
    alias_control,
    "Bad",
    draw_control_bytes_for_test([0x00, 0x00, 0x00, 0x0C, 0x6A]),
  )
  guard bad_alias_jp2 is Err(@pdflite.PdfError::BadJPEG2000Header) else {
    fail("expected BadJPEG2000Header through addjpeg2000 wrapper")
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

  let alias_control = @pdflite.pdf_draw_control_new()
  @pdflite.pdf_setfontname(alias_control, "F0")
  @pdflite.pdf_setfontsize(alias_control, 10.0)
  alias_control.set_fontpack(Some(pack))
  @pdflite.pdf_addbt(alias_control)
  try! @pdflite.pdf_addtext(alias_control, "hello")
  try! @pdflite.pdf_addspecialtext(alias_control, "world")
  try! @pdflite.pdf_addet(alias_control)
  @test.assert_eq(alias_control.ops(), expected)
}

///|
test "pdf draw control default fontpack helper appends once" {
  let control = @pdflite.pdf_draw_control_new()
  let first : @pdflite.PdfFontPack = { fonts: [], entries: [] }
  let second : @pdflite.PdfFontPack = {
    fonts: [draw_control_standard_font_for_test(PdfHelvetica)],
    entries: [],
  }
  control.set_fontpack(Some(first))
  try! control.add_default_fontpack("Body")
  try! control.add_default_fontpack("Ignored")
  @test.assert_eq(control.ops(), [PdfDrawFontPack("Body", first, [])])

  control.set_fontpack(Some(second))
  try! control.add_default_fontpack("Other")
  @test.assert_eq(control.ops(), [
    PdfDrawFontPack("Body", first, []),
    PdfDrawFontPack("Other", second, []),
  ])

  let alias_control = @pdflite.pdf_draw_control_new()
  alias_control.set_fontpack(Some(first))
  try! @pdflite.pdf_add_default_fontpack(alias_control, "Body")
  try! @pdflite.pdf_add_default_fontpack(alias_control, "Ignored")
  @test.assert_eq(alias_control.ops(), [PdfDrawFontPack("Body", first, [])])

  alias_control.set_fontpack(Some(second))
  try! @pdflite.pdf_add_default_fontpack(alias_control, "Other")
  @test.assert_eq(alias_control.ops(), [
    PdfDrawFontPack("Body", first, []),
    PdfDrawFontPack("Other", second, []),
  ])
}

///|
test "pdf draw control exposes font state readers" {
  let control = @pdflite.pdf_draw_control_new()
  @test.assert_eq(control.font_name(), "Times-Roman")
  @test.assert_eq(control.font_size(), 12.0)
  @test.assert_eq(control.paragraph_indent(), None)
  @test.assert_eq(@pdflite.pdf_getfontname(control), "Times-Roman")
  @test.assert_eq(@pdflite.pdf_getfontsize(control), 12.0)
  @test.assert_eq(@pdflite.pdf_getindent(control), None)
  @test.assert_eq(control.fontpack_initialized(), false)

  @pdflite.pdf_setfontname(control, "Body")
  @pdflite.pdf_setfontsize(control, 9.5)
  control.set_paragraph_indent(Some(4.0))
  @test.assert_eq(control.font_name(), "Body")
  @test.assert_eq(control.font_size(), 9.5)
  @test.assert_eq(control.paragraph_indent(), Some(4.0))
  @test.assert_eq(@pdflite.pdf_getfontname(control), "Body")
  @test.assert_eq(@pdflite.pdf_getfontsize(control), 9.5)
  @test.assert_eq(@pdflite.pdf_getindent(control), Some(4.0))

  let pack : @pdflite.PdfFontPack = { fonts: [], entries: [] }
  control.set_fontpack(Some(pack))
  @test.assert_eq(control.fontpack_initialized(), false)
  try! control.add_default_fontpack(control.font_name())
  @test.assert_eq(control.fontpack_initialized(), true)
  control.set_font("Caption", 7.0)
  @test.assert_eq(control.font_name(), "Caption")
  @test.assert_eq(control.font_size(), 7.0)
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

  let alias_control = @pdflite.pdf_draw_control_new()
  @pdflite.pdf_setfontname(alias_control, "F1")
  @pdflite.pdf_setfontsize(alias_control, 8.0)
  alias_control.set_paragraph_indent(Some(3.0))
  @pdflite.pdf_addbt(alias_control)
  try! @pdflite.pdf_addpara(alias_control, document, "L200=One")
  try! @pdflite.pdf_addparas(alias_control, document, "C100=One\\nTwo\\n")
  try! @pdflite.pdf_addet(alias_control)
  @test.assert_eq(alias_control.ops(), expected)
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

  let alias_control = @pdflite.pdf_draw_control_new()
  try! @pdflite.pdf_addrect(alias_control, document, "1 2 3 4")
  try! @pdflite.pdf_addto(alias_control, document, "5 6")
  try! @pdflite.pdf_addline(alias_control, document, "7 8")
  try! @pdflite.pdf_addbezier(alias_control, "1 2 3 4 5 6")
  try! @pdflite.pdf_addbezier23(alias_control, "7 8 9 10")
  try! @pdflite.pdf_addbezier13(alias_control, "11 12 13 14")
  try! @pdflite.pdf_stroke(alias_control)
  try! @pdflite.pdf_fill(alias_control)
  try! @pdflite.pdf_fillevenodd(alias_control)
  try! @pdflite.pdf_strokefill(alias_control)
  try! @pdflite.pdf_strokefillevenodd(alias_control)
  try! @pdflite.pdf_clip(alias_control)
  try! @pdflite.pdf_clipevenodd(alias_control)
  try! @pdflite.pdf_closepath(alias_control)
  @test.assert_eq(alias_control.ops(), expected)
}

///|
test "pdf draw control circle helper expands to move and bezier ops" {
  let control = @pdflite.pdf_draw_control_new()
  try! control.add_circle("10 20 5")
  let alias_control = @pdflite.pdf_draw_control_new()
  try! @pdflite.pdf_addcircle(alias_control, "10 20 5")
  let ops = control.ops()
  @test.assert_eq(alias_control.ops(), ops)
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
