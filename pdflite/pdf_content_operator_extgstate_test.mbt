///|
fn content_operator_ext_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
test "cpdfcontent operator state applies ExtGState graphics parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let extgstate = @pdflite.pdf_dictionary([
    (content_operator_ext_name_for_test("/LW"), PdfReal(2.5)),
    (content_operator_ext_name_for_test("/LC"), PdfInteger(1)),
    (content_operator_ext_name_for_test("/LJ"), PdfInteger(2)),
    (content_operator_ext_name_for_test("/ML"), PdfInteger(13)),
    (
      content_operator_ext_name_for_test("/RI"),
      PdfNameObject(content_operator_ext_name_for_test("/AbsoluteColorimetric")),
    ),
    (content_operator_ext_name_for_test("/FL"), PdfInteger(3)),
  ])
  let state = doc.content_apply_extgstate_graphics_parameter_op(
    initial, extgstate,
  )
  @test.assert_eq(state.path_state.line_width, 2.5)
  @test.assert_eq(state.path_state.line_cap, 1)
  @test.assert_eq(state.path_state.line_join, 2)
  @test.assert_eq(state.miter_limit, 13.0)
  @test.assert_eq(state.path_state.rendering_intent, "/AbsoluteColorimetric")
  @test.assert_eq(state.flatness, 3.0)
  @test.assert_eq(
    @pdflite.pdf_content_apply_extgstate_graphics_parameter_op(
      doc, initial, extgstate,
    ),
    state,
  )
  let ignored = doc.content_apply_extgstate_graphics_parameter_op(
    state,
    @pdflite.pdf_dictionary([
      (
        content_operator_ext_name_for_test("/LW"),
        PdfNameObject(content_operator_ext_name_for_test("/Ignored")),
      ),
      (content_operator_ext_name_for_test("/LC"), PdfReal(9.0)),
      (content_operator_ext_name_for_test("/LJ"), PdfReal(8.0)),
      (content_operator_ext_name_for_test("/ML"), PdfBoolean(false)),
      (content_operator_ext_name_for_test("/RI"), PdfString(b"Relative")),
      (content_operator_ext_name_for_test("/FL"), PdfBoolean(true)),
    ]),
  )
  @test.assert_eq(ignored, state)
}

///|
test "cpdfcontent operator state applies ExtGState dash parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let dash = content_operator_ext_name_for_test("/D")
  let state = try! doc.content_apply_extgstate_dash_op(
    initial,
    @pdflite.pdf_dictionary([
      (dash, PdfArray([PdfArray([PdfInteger(3), PdfReal(1.5)]), PdfInteger(2)])),
    ]),
  )
  @test.assert_eq(state.path_state.dash_pattern, {
    array: [3.0, 1.5],
    phase: 2.0,
  })
  @test.assert_eq(
    try! @pdflite.pdf_content_apply_extgstate_dash_op(
      doc,
      initial,
      @pdflite.pdf_dictionary([
        (
          dash,
          PdfArray([PdfArray([PdfInteger(3), PdfReal(1.5)]), PdfInteger(2)]),
        ),
      ]),
    ),
    state,
  )
  @test.assert_eq(
    try! doc.content_apply_extgstate_dash_op(
      state,
      @pdflite.pdf_dictionary([
        (
          dash,
          PdfArray([
            PdfNameObject(content_operator_ext_name_for_test("/NoArray")),
            PdfReal(0.5),
          ]),
        ),
      ]),
    ).path_state.dash_pattern,
    { array: [], phase: 0.5 },
  )
  @test.assert_eq(
    try! doc.content_apply_extgstate_dash_op(
      state,
      @pdflite.pdf_dictionary([(dash, PdfArray([PdfArray([])]))]),
    ),
    state,
  )
  let bad_phase : Result[@pdflite.PdfContentOperatorState, Error] = try? doc.content_apply_extgstate_dash_op(
    initial,
    @pdflite.pdf_dictionary([
      (
        dash,
        PdfArray([
          PdfArray([PdfInteger(1)]),
          PdfNameObject(content_operator_ext_name_for_test("/BadPhase")),
        ]),
      ),
    ]),
  )
  guard bad_phase is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected NumberExpected for malformed ExtGState dash phase")
  }
  let bad_dash : Result[@pdflite.PdfContentOperatorState, Error] = try? doc.content_apply_extgstate_dash_op(
    initial,
    @pdflite.pdf_dictionary([
      (
        dash,
        PdfArray([
          PdfArray([
            PdfNameObject(content_operator_ext_name_for_test("/BadDash")),
          ]),
          PdfInteger(0),
        ]),
      ),
    ]),
  )
  guard bad_dash is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected NumberExpected for malformed ExtGState dash array")
  }
}

///|
test "cpdfcontent operator state applies ExtGState font parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let subtype_key = content_operator_ext_name_for_test("/Subtype")
  let base_font_key = content_operator_ext_name_for_test("/BaseFont")
  let font_key = content_operator_ext_name_for_test("/Font")
  doc.add_object_given_number(
    7,
    @pdflite.pdf_dictionary([
      (subtype_key, PdfNameObject(content_operator_ext_name_for_test("/Type1"))),
      (
        base_font_key,
        PdfNameObject(content_operator_ext_name_for_test("/Helvetica")),
      ),
    ]),
  )
  let extgstate = @pdflite.pdf_dictionary([
    (font_key, PdfArray([PdfIndirect(7), PdfReal(18.5)])),
  ])
  let state = try! doc.content_apply_extgstate_font_op(initial, extgstate)
  @test.assert_eq(state.text_state.font, "__EXTGSTATE__7")
  @test.assert_eq(state.text_state.font_size, 18.5)
  @test.assert_eq(
    state.text_state.current_font,
    try! doc.read_font(PdfIndirect(7)),
  )
  @test.assert_eq(
    try! @pdflite.pdf_content_apply_extgstate_font_op(doc, initial, extgstate),
    state,
  )
  let malformed_size = try! doc.content_apply_extgstate_font_op(
    initial,
    @pdflite.pdf_dictionary([
      (font_key, PdfArray([PdfIndirect(7), PdfString(b"large")])),
    ]),
  )
  @test.assert_eq(malformed_size.text_state.font, "__EXTGSTATE__7")
  @test.assert_eq(
    malformed_size.text_state.font_size,
    initial.text_state.font_size,
  )
  @test.assert_eq(
    try! doc.content_apply_extgstate_font_op(
      initial,
      @pdflite.pdf_dictionary([
        (
          font_key,
          PdfArray([
            PdfNameObject(content_operator_ext_name_for_test("/F1")),
            PdfInteger(10),
          ]),
        ),
      ]),
    ),
    initial,
  )
  doc.add_object_given_number(9, @pdflite.pdf_dictionary([]))
  let bad_font : Result[@pdflite.PdfContentOperatorState, Error] = try? doc.content_apply_extgstate_font_op(
    initial,
    @pdflite.pdf_dictionary([
      (font_key, PdfArray([PdfIndirect(9), PdfInteger(10)])),
    ]),
  )
  guard bad_font is Err(@pdflite.PdfError::FontTypeExpected) else {
    fail("expected FontTypeExpected for malformed ExtGState font object")
  }
}

///|
test "cpdfcontent operator state applies source-shaped ExtGState resources" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let subtype_key = content_operator_ext_name_for_test("/Subtype")
  let base_font_key = content_operator_ext_name_for_test("/BaseFont")
  doc.add_object_given_number(
    7,
    @pdflite.pdf_dictionary([
      (subtype_key, PdfNameObject(content_operator_ext_name_for_test("/Type1"))),
      (
        base_font_key,
        PdfNameObject(content_operator_ext_name_for_test("/Helvetica")),
      ),
    ]),
  )
  let extgstate_key = content_operator_ext_name_for_test("/ExtGState")
  let gs_name = content_operator_ext_name_for_test("/GS1")
  let resources = @pdflite.pdf_dictionary([
    (
      extgstate_key,
      @pdflite.pdf_dictionary([
        (content_operator_ext_name_for_test("/LW"), PdfReal(2.5)),
        (
          content_operator_ext_name_for_test("/Font"),
          PdfArray([PdfIndirect(7), PdfInteger(16)]),
        ),
        (
          content_operator_ext_name_for_test("/BM"),
          PdfNameObject(content_operator_ext_name_for_test("/Multiply")),
        ),
        (content_operator_ext_name_for_test("/TK"), PdfBoolean(false)),
      ]),
    ),
  ])
  let state = try! doc.content_apply_extgstate_resource_op(
    initial, resources, gs_name,
  )
  @test.assert_eq(state.path_state.line_width, 2.5)
  @test.assert_eq(state.text_state.font, "__EXTGSTATE__7")
  @test.assert_eq(state.text_state.font_size, 16.0)
  @test.assert_eq(
    state.blend_mode,
    PdfNameObject(content_operator_ext_name_for_test("/Multiply")),
  )
  @test.assert_eq(state.text_state.knockout, false)
  @test.assert_eq(
    try! @pdflite.pdf_content_apply_extgstate_resource_op(
      doc, initial, resources, gs_name,
    ),
    state,
  )
  let spec_shaped_resources = @pdflite.pdf_dictionary([
    (
      extgstate_key,
      @pdflite.pdf_dictionary([
        (
          gs_name,
          @pdflite.pdf_dictionary([
            (content_operator_ext_name_for_test("/LW"), PdfReal(9.0)),
          ]),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.content_apply_extgstate_resource_op(
      initial, spec_shaped_resources, gs_name,
    ),
    initial,
  )
  @test.assert_eq(
    try! doc.content_apply_extgstate_resource_op(
      initial,
      @pdflite.pdf_dictionary([]),
      gs_name,
    ),
    initial,
  )
}

///|
test "cpdfcontent operator state applies ExtGState alpha parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let extgstate = @pdflite.pdf_dictionary([
    (content_operator_ext_name_for_test("/CA"), PdfReal(0.75)),
    (content_operator_ext_name_for_test("/ca"), PdfInteger(0)),
    (content_operator_ext_name_for_test("/AIS"), PdfBoolean(true)),
  ])
  let state = doc.content_apply_extgstate_alpha_op(initial, extgstate)
  @test.assert_eq(state.alpha_constant_stroke, 0.75)
  @test.assert_eq(state.alpha_constant_non_stroke, 0.0)
  @test.assert_eq(state.alpha_source, true)
  @test.assert_eq(
    @pdflite.pdf_content_apply_extgstate_alpha_op(doc, initial, extgstate),
    state,
  )
  let ignored = doc.content_apply_extgstate_alpha_op(
    state,
    @pdflite.pdf_dictionary([
      (
        content_operator_ext_name_for_test("/CA"),
        PdfNameObject(content_operator_ext_name_for_test("/Ignored")),
      ),
      (content_operator_ext_name_for_test("/ca"), PdfBoolean(false)),
      (content_operator_ext_name_for_test("/AIS"), PdfInteger(1)),
    ]),
  )
  @test.assert_eq(ignored, state)
}

///|
test "cpdfcontent operator state applies ExtGState rendering parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let extgstate = @pdflite.pdf_dictionary([
    (content_operator_ext_name_for_test("/SM"), PdfInteger(2)),
    (content_operator_ext_name_for_test("/SA"), PdfBoolean(true)),
  ])
  let state = doc.content_apply_extgstate_rendering_op(initial, extgstate)
  @test.assert_eq(state.smoothness, 2.0)
  @test.assert_eq(state.stroke_adjustment, true)
  @test.assert_eq(
    @pdflite.pdf_content_apply_extgstate_rendering_op(doc, initial, extgstate),
    state,
  )
  let ignored = doc.content_apply_extgstate_rendering_op(
    state,
    @pdflite.pdf_dictionary([
      (content_operator_ext_name_for_test("/SM"), PdfBoolean(false)),
      (content_operator_ext_name_for_test("/SA"), PdfInteger(1)),
    ]),
  )
  @test.assert_eq(ignored, state)
}

///|
test "cpdfcontent operator state applies ExtGState overprint parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let op_stroke = content_operator_ext_name_for_test("/OP")
  let op_non_stroke = content_operator_ext_name_for_test("/op")
  let stroke_only = doc.content_apply_extgstate_overprint_op(
    initial,
    @pdflite.pdf_dictionary([(op_stroke, PdfBoolean(true))]),
  )
  @test.assert_eq(stroke_only.overprint_stroke, true)
  @test.assert_eq(stroke_only.overprint_non_stroke, true)
  @test.assert_eq(stroke_only.overprint_mode, 0)
  let split = doc.content_apply_extgstate_overprint_op(
    initial,
    @pdflite.pdf_dictionary([
      (op_stroke, PdfBoolean(true)),
      (op_non_stroke, PdfBoolean(false)),
    ]),
  )
  @test.assert_eq(split.overprint_stroke, true)
  @test.assert_eq(split.overprint_non_stroke, false)
  let mode = doc.content_apply_extgstate_overprint_op(
    initial,
    @pdflite.pdf_dictionary([
      (op_stroke, PdfBoolean(true)),
      (op_non_stroke, PdfInteger(2)),
    ]),
  )
  @test.assert_eq(mode.overprint_stroke, true)
  @test.assert_eq(mode.overprint_non_stroke, true)
  @test.assert_eq(mode.overprint_mode, 2)
  @test.assert_eq(
    @pdflite.pdf_content_apply_extgstate_overprint_op(
      doc,
      initial,
      @pdflite.pdf_dictionary([
        (op_stroke, PdfBoolean(true)),
        (op_non_stroke, PdfInteger(2)),
      ]),
    ),
    mode,
  )
  let ignored = doc.content_apply_extgstate_overprint_op(
    mode,
    @pdflite.pdf_dictionary([
      (op_stroke, PdfInteger(1)),
      (op_non_stroke, PdfReal(2.0)),
    ]),
  )
  @test.assert_eq(ignored, mode)
}

///|
test "cpdfcontent operator state applies ExtGState transfer parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let bg2 : @pdflite.PdfObject = PdfNameObject(
    content_operator_ext_name_for_test("/BG2Value"),
  )
  let ucr2 : @pdflite.PdfObject = PdfNameObject(
    content_operator_ext_name_for_test("/UCR2Value"),
  )
  let tr2 : @pdflite.PdfObject = PdfNameObject(
    content_operator_ext_name_for_test("/TR2Value"),
  )
  let extgstate = @pdflite.pdf_dictionary([
    (
      content_operator_ext_name_for_test("/BG"),
      PdfNameObject(content_operator_ext_name_for_test("/BGValue")),
    ),
    (content_operator_ext_name_for_test("/BG2"), bg2),
    (
      content_operator_ext_name_for_test("/UCR"),
      PdfNameObject(content_operator_ext_name_for_test("/UCRValue")),
    ),
    (content_operator_ext_name_for_test("/UCR2"), ucr2),
    (
      content_operator_ext_name_for_test("/TR"),
      PdfNameObject(content_operator_ext_name_for_test("/TRValue")),
    ),
    (content_operator_ext_name_for_test("/TR2"), tr2),
  ])
  let state = doc.content_apply_extgstate_transfer_op(initial, extgstate)
  @test.assert_eq(state.black_generation, bg2)
  @test.assert_eq(state.undercolour_removal, ucr2)
  @test.assert_eq(state.transfer, tr2)
  @test.assert_eq(
    @pdflite.pdf_content_apply_extgstate_transfer_op(doc, initial, extgstate),
    state,
  )
  let ignored = doc.content_apply_extgstate_transfer_op(
    state,
    @pdflite.pdf_dictionary([
      (content_operator_ext_name_for_test("/BG"), PdfNull),
      (content_operator_ext_name_for_test("/UCR"), PdfNull),
      (content_operator_ext_name_for_test("/TR"), PdfNull),
    ]),
  )
  @test.assert_eq(ignored, state)
}

///|
test "cpdfcontent operator state applies ExtGState halftone parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let hto : @pdflite.PdfObject = PdfNameObject(
    content_operator_ext_name_for_test("/HTOValue"),
  )
  let extgstate = @pdflite.pdf_dictionary([
    (
      content_operator_ext_name_for_test("/HT"),
      PdfNameObject(content_operator_ext_name_for_test("/HTValue")),
    ),
    (
      content_operator_ext_name_for_test("/SMask"),
      PdfNameObject(content_operator_ext_name_for_test("/SMaskValue")),
    ),
    (content_operator_ext_name_for_test("/HTO"), hto),
  ])
  let state = doc.content_apply_extgstate_halftone_op(initial, extgstate)
  @test.assert_eq(state.halftone, hto)
  @test.assert_eq(
    @pdflite.pdf_content_apply_extgstate_halftone_op(doc, initial, extgstate),
    state,
  )
  let ignored = doc.content_apply_extgstate_halftone_op(
    state,
    @pdflite.pdf_dictionary([
      (content_operator_ext_name_for_test("/HT"), PdfNull),
      (content_operator_ext_name_for_test("/SMask"), PdfNull),
      (content_operator_ext_name_for_test("/HTO"), PdfNull),
    ]),
  )
  @test.assert_eq(ignored, state)
}

///|
test "cpdfcontent operator state applies ExtGState compositing parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let blend : @pdflite.PdfObject = PdfNameObject(
    content_operator_ext_name_for_test("/Multiply"),
  )
  let extgstate = @pdflite.pdf_dictionary([
    (content_operator_ext_name_for_test("/BM"), blend),
    (
      content_operator_ext_name_for_test("/UseBlackPtComp"),
      PdfNameObject(content_operator_ext_name_for_test("/ON")),
    ),
  ])
  let state = doc.content_apply_extgstate_compositing_op(initial, extgstate)
  @test.assert_eq(state.blend_mode, blend)
  @test.assert_eq(state.black_point_compensation, "/ON")
  @test.assert_eq(
    @pdflite.pdf_content_apply_extgstate_compositing_op(doc, initial, extgstate),
    state,
  )
  let ignored = doc.content_apply_extgstate_compositing_op(
    state,
    @pdflite.pdf_dictionary([
      (content_operator_ext_name_for_test("/BM"), PdfNull),
      (content_operator_ext_name_for_test("/UseBlackPtComp"), PdfString(b"ON")),
    ]),
  )
  @test.assert_eq(ignored, state)
}

///|
test "cpdfcontent operator state applies ExtGState text knockout" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let tk = content_operator_ext_name_for_test("/TK")
  let disabled = doc.content_apply_extgstate_text_op(
    initial,
    @pdflite.pdf_dictionary([(tk, PdfBoolean(false))]),
  )
  @test.assert_eq(disabled.text_state.knockout, false)
  @test.assert_eq(
    disabled.text_state.content_glyph_state(disabled.clipping_path).knockout,
    false,
  )
  @test.assert_eq(
    @pdflite.pdf_content_apply_extgstate_text_op(
      doc,
      initial,
      @pdflite.pdf_dictionary([(tk, PdfBoolean(false))]),
    ),
    disabled,
  )
  @test.assert_eq(
    doc.content_apply_extgstate_text_op(
      disabled,
      @pdflite.pdf_dictionary([
        (tk, PdfNameObject(content_operator_ext_name_for_test("/Ignored"))),
      ]),
    ),
    disabled,
  )
  @test.assert_eq(
    doc.content_apply_extgstate_text_op(
      disabled,
      @pdflite.pdf_dictionary([(tk, PdfBoolean(true))]),
    ).text_state.knockout,
    true,
  )
}
