///|
fn content_operator_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn content_operator_assert_line_for_test(
  segment : @pdflite.PdfPathSegment,
  start_x : Double,
  start_y : Double,
  finish_x : Double,
  finish_y : Double,
) -> Unit raise {
  match segment {
    PdfPathStraight(start, finish) => {
      @test.assert_eq(start, @pdflite.point2(start_x, start_y))
      @test.assert_eq(finish, @pdflite.point2(finish_x, finish_y))
    }
    _ => fail("expected straight path segment")
  }
}

///|
test "cpdfcontent operator state exposes initial state" {
  let state = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let clipping_path = @pdflite.pdf_content_initial_clipping_path(
    0.0, 0.0, 100.0, 200.0,
  )
  @test.assert_eq(state.ctm, @pdflite.transform_identity_matrix)
  @test.assert_eq(state.partial_path, PdfContentNoPartialPath)
  @test.assert_eq(state.clipping_path, clipping_path)
  @test.assert_eq(state.path, @pdflite.pdf_content_initial_drawn_path())
  @test.assert_eq(
    state.path_state,
    @pdflite.pdf_content_initial_path_state(0.0, 0.0, 100.0, 200.0),
  )
  @test.assert_eq(state.path_state.clipping_path, clipping_path)
  @test.assert_eq(state.text_state, @pdflite.pdf_content_initial_text_state())
  @test.assert_eq(state.miter_limit, 10.0)
  @test.assert_eq(state.flatness, 1.0)
  @test.assert_eq(state.alpha_constant_stroke, 1.0)
  @test.assert_eq(state.alpha_constant_non_stroke, 1.0)
  @test.assert_eq(state.alpha_source, false)
  @test.assert_eq(state.smoothness, 0.5)
  @test.assert_eq(state.stroke_adjustment, false)
  @test.assert_eq(state.overprint_stroke, false)
  @test.assert_eq(state.overprint_non_stroke, false)
  @test.assert_eq(state.overprint_mode, 0)
  @test.assert_eq(state.black_generation, PdfNull)
  @test.assert_eq(state.undercolour_removal, PdfNull)
  @test.assert_eq(state.transfer, PdfNull)
  @test.assert_eq(state.halftone, PdfNull)
  @test.assert_eq(state.marked_content_point, None)
  @test.assert_eq(state.marked_content.length(), 0)
  @test.assert_eq(state.type3_d0, None)
  @test.assert_eq(state.type3_d1, None)
  @test.assert_eq(state.state_stack.length(), 0)
}

///|
test "cpdfcontent operator state saves and restores q Q frames" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let pushed = initial.content_apply_graphics_state_op(Op_q)
  @test.assert_eq(pushed.state_stack.length(), 1)
  @test.assert_eq(pushed.state_stack[0].ctm, initial.ctm)
  @test.assert_eq(pushed.state_stack[0].path_state, initial.path_state)
  @test.assert_eq(pushed.state_stack[0].text_state, initial.text_state)
  @test.assert_eq(pushed.state_stack[0].alpha_constant_stroke, 1.0)
  @test.assert_eq(pushed.state_stack[0].alpha_constant_non_stroke, 1.0)
  @test.assert_eq(pushed.state_stack[0].alpha_source, false)
  @test.assert_eq(pushed.state_stack[0].smoothness, 0.5)
  @test.assert_eq(pushed.state_stack[0].stroke_adjustment, false)
  @test.assert_eq(pushed.state_stack[0].overprint_stroke, false)
  @test.assert_eq(pushed.state_stack[0].overprint_non_stroke, false)
  @test.assert_eq(pushed.state_stack[0].overprint_mode, 0)
  @test.assert_eq(pushed.state_stack[0].black_generation, PdfNull)
  @test.assert_eq(pushed.state_stack[0].undercolour_removal, PdfNull)
  @test.assert_eq(pushed.state_stack[0].transfer, PdfNull)
  @test.assert_eq(pushed.state_stack[0].halftone, PdfNull)
  let changed : @pdflite.PdfContentOperatorState = {
    ..pushed,
    ctm: @pdflite.transform_translate(7.0, 8.0),
    partial_path: pushed.partial_path.content_apply_path_op(Op_m(1.0, 2.0)).partial_path,
    clipping_path: [],
    path_state: pushed.path_state.content_apply_path_state_op(Op_w(3.0)),
    text_state: pushed.text_state.content_apply_text_state_op(Op_Tc(5.0)),
    alpha_constant_stroke: 0.75,
    alpha_constant_non_stroke: 0.5,
    alpha_source: true,
    smoothness: 0.25,
    stroke_adjustment: true,
    overprint_stroke: true,
    overprint_non_stroke: true,
    overprint_mode: 1,
    black_generation: PdfInteger(1),
    undercolour_removal: PdfInteger(2),
    transfer: PdfInteger(3),
    halftone: PdfInteger(4),
  }
  let restored = changed.content_apply_graphics_state_op(Op_Q)
  @test.assert_eq(restored.ctm, initial.ctm)
  @test.assert_eq(restored.partial_path, initial.partial_path)
  @test.assert_eq(restored.clipping_path, initial.clipping_path)
  @test.assert_eq(restored.path, initial.path)
  @test.assert_eq(restored.path_state, initial.path_state)
  @test.assert_eq(restored.text_state, initial.text_state)
  @test.assert_eq(restored.alpha_constant_stroke, initial.alpha_constant_stroke)
  @test.assert_eq(
    restored.alpha_constant_non_stroke,
    initial.alpha_constant_non_stroke,
  )
  @test.assert_eq(restored.alpha_source, initial.alpha_source)
  @test.assert_eq(restored.smoothness, initial.smoothness)
  @test.assert_eq(restored.stroke_adjustment, initial.stroke_adjustment)
  @test.assert_eq(restored.overprint_stroke, initial.overprint_stroke)
  @test.assert_eq(restored.overprint_non_stroke, initial.overprint_non_stroke)
  @test.assert_eq(restored.overprint_mode, initial.overprint_mode)
  @test.assert_eq(restored.black_generation, initial.black_generation)
  @test.assert_eq(restored.undercolour_removal, initial.undercolour_removal)
  @test.assert_eq(restored.transfer, initial.transfer)
  @test.assert_eq(restored.halftone, initial.halftone)
  @test.assert_eq(restored.state_stack.length(), 0)
  @test.assert_eq(initial.content_apply_graphics_state_op(Op_Q), initial)
}

///|
test "cpdfcontent operator state composes cm matrices" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let moved = initial
    .content_apply_graphics_state_op(
      Op_cm(@pdflite.transform_translate(10.0, 20.0)),
    )
    .content_apply_graphics_state_op(
      Op_cm(@pdflite.transform_translate(1.0, 2.0)),
    )
  @test.assert_eq(moved.ctm, @pdflite.transform_translate(11.0, 22.0))
  @test.assert_eq(
    @pdflite.pdf_content_apply_graphics_state_op(
      initial,
      Op_cm(@pdflite.transform_translate(3.0, 4.0)),
    ).ctm,
    @pdflite.transform_translate(3.0, 4.0),
  )
  @test.assert_eq(initial.content_apply_graphics_state_op(Op_w(9.0)), initial)
}

///|
test "cpdfcontent operator core applies path clipping and state ops" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let state = initial
    .content_apply_core_op(Op_w(2.5))
    .content_apply_core_op(Op_Tc(3.5))
    .content_apply_core_op(Op_m(0.0, 0.0))
    .content_apply_core_op(Op_l(10.0, 0.0))
    .content_apply_core_op(Op_W)
    .content_apply_core_op(Op_n)
  @test.assert_eq(state.path_state.line_width, 2.5)
  @test.assert_eq(state.text_state.character_spacing, 3.5)
  @test.assert_eq(
    state.clipping_path.length(),
    initial.clipping_path.length() + 1,
  )
  @test.assert_eq(state.path_state.clipping_path, state.clipping_path)
  @test.assert_eq(state.partial_path, PdfContentNoPartialPath)
  let painted = initial
    .content_apply_core_op(Op_m(1.0, 2.0))
    .content_apply_core_op(Op_l(3.0, 4.0))
    .content_apply_core_op(Op_S)
  @test.assert_eq(painted.path.stroked, true)
  @test.assert_eq(painted.path.filled, false)
  @test.assert_eq(painted.path.path.subpaths.length(), 1)
  guard painted.partial_path is PdfContentPartialPath(partial) else {
    fail("expected retained cleared partial path")
  }
  @test.assert_eq(partial.segments.length(), 0)
  @test.assert_eq(partial.subpaths.length(), 0)
  @test.assert_eq(
    @pdflite.pdf_content_apply_core_op(initial, Op_w(4.0)).path_state.line_width,
    4.0,
  )
}

///|
test "cpdfcontent operator core threads graphics stack" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let changed = initial
    .content_apply_core_op(Op_q)
    .content_apply_core_op(Op_cm(@pdflite.transform_translate(5.0, 6.0)))
    .content_apply_core_op(Op_w(7.0))
    .content_apply_core_op(Op_Tw(8.0))
    .content_apply_core_op(Op_M(9.0))
    .content_apply_core_op(Op_i(0.25))
    .content_apply_core_op(Op_BMC(content_operator_name_for_test("/Artifact")))
    .content_apply_core_op(Op_d0(500.0, 0.0))
  @test.assert_eq(changed.state_stack.length(), 1)
  @test.assert_eq(changed.ctm, @pdflite.transform_translate(5.0, 6.0))
  @test.assert_eq(changed.path_state.line_width, 7.0)
  @test.assert_eq(changed.text_state.word_spacing, 8.0)
  @test.assert_eq(changed.marked_content.length(), 1)
  @test.assert_eq(changed.miter_limit, 9.0)
  @test.assert_eq(changed.flatness, 0.25)
  @test.assert_eq(changed.type3_d0, Some({ width_x: 500.0, width_y: 0.0 }))
  @test.assert_eq(changed.content_apply_core_op(Op_Q), initial)
  @test.assert_eq(initial.content_apply_core_op(Op_BX), initial)
}

///|
test "cpdfcontent operator state applies direct graphics parameters" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let state = initial
    .content_apply_graphics_parameter_op(Op_M(13.0))
    .content_apply_graphics_parameter_op(Op_i(0.5))
  @test.assert_eq(state.miter_limit, 13.0)
  @test.assert_eq(state.flatness, 0.5)
  @test.assert_eq(
    @pdflite.pdf_content_apply_graphics_parameter_op(initial, Op_i(0.125)).flatness,
    0.125,
  )
}

///|
test "cpdfcontent operator state applies ExtGState graphics parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let extgstate = @pdflite.pdf_dictionary([
    (content_operator_name_for_test("/LW"), PdfReal(2.5)),
    (content_operator_name_for_test("/LC"), PdfInteger(1)),
    (content_operator_name_for_test("/LJ"), PdfInteger(2)),
    (content_operator_name_for_test("/ML"), PdfInteger(13)),
    (
      content_operator_name_for_test("/RI"),
      PdfNameObject(content_operator_name_for_test("/AbsoluteColorimetric")),
    ),
    (content_operator_name_for_test("/FL"), PdfInteger(3)),
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
        content_operator_name_for_test("/LW"),
        PdfNameObject(content_operator_name_for_test("/Ignored")),
      ),
      (content_operator_name_for_test("/LC"), PdfReal(9.0)),
      (content_operator_name_for_test("/LJ"), PdfReal(8.0)),
      (content_operator_name_for_test("/ML"), PdfBoolean(false)),
      (content_operator_name_for_test("/RI"), PdfString(b"Relative")),
      (content_operator_name_for_test("/FL"), PdfBoolean(true)),
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
  let dash = content_operator_name_for_test("/D")
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
            PdfNameObject(content_operator_name_for_test("/NoArray")),
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
          PdfNameObject(content_operator_name_for_test("/BadPhase")),
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
          PdfArray([PdfNameObject(content_operator_name_for_test("/BadDash"))]),
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
test "cpdfcontent operator state applies ExtGState alpha parameters" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let extgstate = @pdflite.pdf_dictionary([
    (content_operator_name_for_test("/CA"), PdfReal(0.75)),
    (content_operator_name_for_test("/ca"), PdfInteger(0)),
    (content_operator_name_for_test("/AIS"), PdfBoolean(true)),
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
        content_operator_name_for_test("/CA"),
        PdfNameObject(content_operator_name_for_test("/Ignored")),
      ),
      (content_operator_name_for_test("/ca"), PdfBoolean(false)),
      (content_operator_name_for_test("/AIS"), PdfInteger(1)),
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
    (content_operator_name_for_test("/SM"), PdfInteger(2)),
    (content_operator_name_for_test("/SA"), PdfBoolean(true)),
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
      (content_operator_name_for_test("/SM"), PdfBoolean(false)),
      (content_operator_name_for_test("/SA"), PdfInteger(1)),
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
  let op_stroke = content_operator_name_for_test("/OP")
  let op_non_stroke = content_operator_name_for_test("/op")
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
    content_operator_name_for_test("/BG2Value"),
  )
  let ucr2 : @pdflite.PdfObject = PdfNameObject(
    content_operator_name_for_test("/UCR2Value"),
  )
  let tr2 : @pdflite.PdfObject = PdfNameObject(
    content_operator_name_for_test("/TR2Value"),
  )
  let extgstate = @pdflite.pdf_dictionary([
    (
      content_operator_name_for_test("/BG"),
      PdfNameObject(content_operator_name_for_test("/BGValue")),
    ),
    (content_operator_name_for_test("/BG2"), bg2),
    (
      content_operator_name_for_test("/UCR"),
      PdfNameObject(content_operator_name_for_test("/UCRValue")),
    ),
    (content_operator_name_for_test("/UCR2"), ucr2),
    (
      content_operator_name_for_test("/TR"),
      PdfNameObject(content_operator_name_for_test("/TRValue")),
    ),
    (content_operator_name_for_test("/TR2"), tr2),
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
      (content_operator_name_for_test("/BG"), PdfNull),
      (content_operator_name_for_test("/UCR"), PdfNull),
      (content_operator_name_for_test("/TR"), PdfNull),
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
    content_operator_name_for_test("/HTOValue"),
  )
  let extgstate = @pdflite.pdf_dictionary([
    (
      content_operator_name_for_test("/HT"),
      PdfNameObject(content_operator_name_for_test("/HTValue")),
    ),
    (
      content_operator_name_for_test("/SMask"),
      PdfNameObject(content_operator_name_for_test("/SMaskValue")),
    ),
    (content_operator_name_for_test("/HTO"), hto),
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
      (content_operator_name_for_test("/HT"), PdfNull),
      (content_operator_name_for_test("/SMask"), PdfNull),
      (content_operator_name_for_test("/HTO"), PdfNull),
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
  let tk = content_operator_name_for_test("/TK")
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
        (tk, PdfNameObject(content_operator_name_for_test("/Ignored"))),
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

///|
test "cpdfcontent operator state applies marked content operators" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let span = content_operator_name_for_test("/Span")
  let artifact = content_operator_name_for_test("/Artifact")
  let properties = @pdflite.PdfDictionary([
    (content_operator_name_for_test("/MCID"), PdfInteger(7)),
  ])
  let point = initial.content_apply_marked_content_op(Op_MP(span))
  @test.assert_eq(
    point.marked_content_point,
    Some({ tag: "/Span", properties: None }),
  )
  let point_with_properties = point.content_apply_marked_content_op(
    Op_DP(span, properties),
  )
  @test.assert_eq(
    point_with_properties.marked_content_point,
    Some({ tag: "/Span", properties: Some(properties) }),
  )
  let nested = initial
    .content_apply_core_op(Op_BMC(artifact))
    .content_apply_core_op(Op_BDC(span, properties))
  @test.assert_eq(nested.marked_content.length(), 2)
  @test.assert_eq(nested.marked_content[0], {
    tag: "/Span",
    properties: Some(properties),
  })
  @test.assert_eq(nested.marked_content[1], {
    tag: "/Artifact",
    properties: None,
  })
  let popped = nested.content_apply_core_op(Op_EMC)
  @test.assert_eq(popped.marked_content.length(), 1)
  @test.assert_eq(popped.marked_content[0].tag, "/Artifact")
  @test.assert_eq(initial.content_apply_core_op(Op_EMC), initial)
  @test.assert_eq(
    @pdflite.pdf_content_apply_marked_content_op(initial, Op_BMC(span)).marked_content[0].tag,
    "/Span",
  )
}

///|
test "cpdfcontent operator state applies Type 3 metric operators" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let d0 = initial.content_apply_type3_metrics_op(Op_d0(500.0, 0.0))
  @test.assert_eq(d0.type3_d0, Some({ width_x: 500.0, width_y: 0.0 }))
  @test.assert_eq(d0.type3_d1, None)
  let d1 = d0.content_apply_core_op(Op_d1(500.0, 0.0, 0.0, -10.0, 600.0, 700.0))
  @test.assert_eq(d1.type3_d0, d0.type3_d0)
  @test.assert_eq(
    d1.type3_d1,
    Some({
      width_x: 500.0,
      width_y: 0.0,
      llx: 0.0,
      lly: -10.0,
      urx: 600.0,
      ury: 700.0,
    }),
  )
  @test.assert_eq(
    @pdflite.pdf_content_apply_type3_metrics_op(
      initial,
      Op_d1(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    ).type3_d1,
    Some({ width_x: 1.0, width_y: 2.0, llx: 3.0, lly: 4.0, urx: 5.0, ury: 6.0 }),
  )
}

///|
test "cpdfcontent operator state emits image entries from current CTM" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let state : @pdflite.PdfContentOperatorState = {
    ..initial,
    ctm: @pdflite.transform_translate(5.0, 6.0),
  }
  let bounding_box : @pdflite.PdfContentBoundingBox = {
    x0: 5.0,
    y0: 6.0,
    x1: 5.0,
    y1: 7.0,
    x2: 6.0,
    y2: 7.0,
    x3: 6.0,
    y3: 6.0,
  }
  @test.assert_eq(state.content_unit_square_bounding_box(), bounding_box)
  let clipping_state : @pdflite.PdfContentState = PdfContentStateClipping(
    @pdflite.pdf_content_clipping_state_of_paths(state.clipping_path),
  )
  let inline_image = state.content_inline_image_entry()
  @test.assert_eq(inline_image.object, PdfContentInlineImageObject)
  @test.assert_eq(inline_image.state, clipping_state)
  @test.assert_eq(inline_image.bounding_box, bounding_box)
  let image = state.content_image_entry(content_operator_name_for_test("/Im1"))
  @test.assert_eq(image.object, PdfContentImageObject("/Im1"))
  @test.assert_eq(image.state, clipping_state)
  @test.assert_eq(image.bounding_box, bounding_box)
  @test.assert_eq(@pdflite.pdf_content_inline_image_entry(state), inline_image)
  @test.assert_eq(
    @pdflite.pdf_content_image_entry(
      state,
      content_operator_name_for_test("/Im1"),
    ),
    image,
  )
}

///|
test "cpdfcontent operator state reads image entries from XObject resources" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let state : @pdflite.PdfContentOperatorState = {
    ..initial,
    ctm: @pdflite.transform_translate(5.0, 6.0),
  }
  let image_name = content_operator_name_for_test("/Im1")
  let form_name = content_operator_name_for_test("/Fm1")
  let unknown_name = content_operator_name_for_test("/Ps1")
  let no_subtype_name = content_operator_name_for_test("/NoSubtype")
  let xobject_key = content_operator_name_for_test("/XObject")
  let subtype_key = content_operator_name_for_test("/Subtype")
  let resources = @pdflite.pdf_dictionary([
    (
      xobject_key,
      @pdflite.pdf_dictionary([
        (
          image_name,
          @pdflite.pdf_dictionary([
            (
              subtype_key,
              PdfNameObject(content_operator_name_for_test("/Image")),
            ),
          ]),
        ),
        (
          form_name,
          @pdflite.pdf_dictionary([
            (
              subtype_key,
              PdfNameObject(content_operator_name_for_test("/Form")),
            ),
          ]),
        ),
        (
          unknown_name,
          @pdflite.pdf_dictionary([
            (subtype_key, PdfNameObject(content_operator_name_for_test("/PS"))),
          ]),
        ),
        (no_subtype_name, @pdflite.pdf_dictionary([])),
      ]),
    ),
  ])
  let image_result : Result[@pdflite.PdfContentJsonEntry?, Error] = try? doc.content_image_entry_from_resources(
    state, resources, image_name,
  )
  guard image_result is Ok(Some(image_entry)) else {
    fail("expected image XObject entry")
  }
  @test.assert_eq(image_entry.object, PdfContentImageObject("/Im1"))
  @test.assert_eq(image_entry.bounding_box, {
    x0: 5.0,
    y0: 6.0,
    x1: 5.0,
    y1: 7.0,
    x2: 6.0,
    y2: 7.0,
    x3: 6.0,
    y3: 6.0,
  })
  let form_result : Result[@pdflite.PdfContentJsonEntry?, Error] = try? doc.content_image_entry_from_resources(
    state, resources, form_name,
  )
  guard form_result is Ok(None) else {
    fail("expected form XObject to emit no image entry")
  }
  let wrapper_result : Result[@pdflite.PdfContentJsonEntry?, Error] = try? @pdflite.pdf_content_image_entry_from_resources(
    doc, state, resources, image_name,
  )
  guard wrapper_result is Ok(Some(wrapper_entry)) else {
    fail("expected wrapper image XObject entry")
  }
  @test.assert_eq(wrapper_entry, image_entry)
  let missing_resources : Result[@pdflite.PdfContentJsonEntry?, Error] = try? doc.content_image_entry_from_resources(
    state,
    @pdflite.pdf_dictionary([]),
    image_name,
  )
  guard missing_resources
    is Err(@pdflite.PdfError::SoftError("xobject not found")) else {
    fail("expected missing /XObject resource error")
  }
  let missing_name : Result[@pdflite.PdfContentJsonEntry?, Error] = try? doc.content_image_entry_from_resources(
    state,
    resources,
    content_operator_name_for_test("/Missing"),
  )
  guard missing_name is Err(@pdflite.PdfError::SoftError("Unknown xobject")) else {
    fail("expected missing named XObject error")
  }
  let unknown_kind : Result[@pdflite.PdfContentJsonEntry?, Error] = try? doc.content_image_entry_from_resources(
    state, resources, unknown_name,
  )
  guard unknown_kind
    is Err(@pdflite.PdfError::SoftError("Unknown kind of xobject")) else {
    fail("expected unknown XObject kind error")
  }
  let missing_subtype : Result[@pdflite.PdfContentJsonEntry?, Error] = try? doc.content_image_entry_from_resources(
    state, resources, no_subtype_name,
  )
  guard missing_subtype
    is Err(@pdflite.PdfError::SoftError("Unknown kind of xobject")) else {
    fail("expected missing XObject subtype error")
  }
}

///|
test "cpdfcontent operator state prepares Form XObject resources" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let state : @pdflite.PdfContentOperatorState = {
    ..initial,
    ctm: @pdflite.transform_translate(5.0, 6.0),
  }
  let form_name = content_operator_name_for_test("/Fm1")
  let image_name = content_operator_name_for_test("/Im1")
  let bad_bbox_name = content_operator_name_for_test("/BadBBox")
  let bad_matrix_name = content_operator_name_for_test("/BadMatrix")
  let xobject_key = content_operator_name_for_test("/XObject")
  let subtype_key = content_operator_name_for_test("/Subtype")
  let matrix_key = content_operator_name_for_test("/Matrix")
  let bbox_key = content_operator_name_for_test("/BBox")
  let form_matrix = @pdflite.transform_translate(10.0, 20.0)
  let resources = @pdflite.pdf_dictionary([
    (
      xobject_key,
      @pdflite.pdf_dictionary([
        (
          form_name,
          @pdflite.pdf_dictionary([
            (
              subtype_key,
              PdfNameObject(content_operator_name_for_test("/Form")),
            ),
            (matrix_key, @pdflite.pdf_object_of_matrix(form_matrix)),
            (
              bbox_key,
              PdfArray([
                PdfInteger(1),
                PdfInteger(2),
                PdfInteger(4),
                PdfInteger(6),
              ]),
            ),
          ]),
        ),
        (
          image_name,
          @pdflite.pdf_dictionary([
            (
              subtype_key,
              PdfNameObject(content_operator_name_for_test("/Image")),
            ),
          ]),
        ),
        (
          bad_bbox_name,
          @pdflite.pdf_dictionary([
            (
              subtype_key,
              PdfNameObject(content_operator_name_for_test("/Form")),
            ),
            (bbox_key, PdfBoolean(true)),
          ]),
        ),
        (
          bad_matrix_name,
          @pdflite.pdf_dictionary([
            (
              subtype_key,
              PdfNameObject(content_operator_name_for_test("/Form")),
            ),
            (matrix_key, PdfBoolean(true)),
          ]),
        ),
      ]),
    ),
  ])
  let form_result : Result[@pdflite.PdfContentOperatorState?, Error] = try? doc.content_form_xobject_enter_state(
    state, resources, form_name,
  )
  guard form_result is Ok(Some(form_state)) else {
    fail("expected Form XObject entry state")
  }
  @test.assert_eq(
    form_state.ctm,
    @pdflite.transform_matrix_compose(state.ctm, form_matrix),
  )
  @test.assert_eq(
    form_state.state_stack.length(),
    state.state_stack.length() + 1,
  )
  @test.assert_eq(form_state.path_state.clipping_path, form_state.clipping_path)
  @test.assert_eq(form_state.partial_path, PdfContentNoPartialPath)
  @test.assert_eq(form_state.content_apply_core_op(Op_Q), state)
  @test.assert_eq(
    form_state.clipping_path.length(),
    state.clipping_path.length() + 1,
  )
  let clip = form_state.clipping_path[0]
  @test.assert_eq(clip.winding_rule, PdfPathNonZero)
  @test.assert_eq(clip.subpaths.length(), 1)
  @test.assert_eq(clip.subpaths[0].closure, PdfPathClosed)
  @test.assert_eq(clip.subpaths[0].segments.length(), 3)
  content_operator_assert_line_for_test(
    clip.subpaths[0].segments[0],
    1.0,
    2.0,
    4.0,
    2.0,
  )
  content_operator_assert_line_for_test(
    clip.subpaths[0].segments[1],
    4.0,
    2.0,
    4.0,
    6.0,
  )
  content_operator_assert_line_for_test(
    clip.subpaths[0].segments[2],
    4.0,
    6.0,
    1.0,
    6.0,
  )
  let wrapper_result : Result[@pdflite.PdfContentOperatorState?, Error] = try? @pdflite.pdf_content_form_xobject_enter_state(
    doc, state, resources, form_name,
  )
  guard wrapper_result is Ok(Some(wrapper_state)) else {
    fail("expected wrapper Form XObject entry state")
  }
  @test.assert_eq(wrapper_state, form_state)
  let image_result : Result[@pdflite.PdfContentOperatorState?, Error] = try? doc.content_form_xobject_enter_state(
    state, resources, image_name,
  )
  guard image_result is Ok(None) else {
    fail("expected image XObject to emit no Form entry state")
  }
  let bad_bbox_result : Result[@pdflite.PdfContentOperatorState?, Error] = try? doc.content_form_xobject_enter_state(
    state, resources, bad_bbox_name,
  )
  guard bad_bbox_result is Ok(Some(bad_bbox_state)) else {
    fail("expected malformed Form BBox to use fallback bounds")
  }
  @test.assert_eq(
    bad_bbox_state.state_stack.length(),
    state.state_stack.length() + 1,
  )
  let bad_matrix_result : Result[@pdflite.PdfContentOperatorState?, Error] = try? doc.content_form_xobject_enter_state(
    state, resources, bad_matrix_name,
  )
  guard bad_matrix_result is Err(@pdflite.PdfError::MatrixMalformed) else {
    fail("expected malformed Form Matrix error")
  }
}

///|
test "cpdfcontent operator state merges Form XObject resources" {
  let doc = @pdflite.pdf_document_empty()
  let form_name = content_operator_name_for_test("/Fm1")
  let image_name = content_operator_name_for_test("/Im1")
  let nested_name = content_operator_name_for_test("/Nested")
  let xobject_key = content_operator_name_for_test("/XObject")
  let subtype_key = content_operator_name_for_test("/Subtype")
  let resources_key = content_operator_name_for_test("/Resources")
  let font_key = content_operator_name_for_test("/Font")
  let color_space_key = content_operator_name_for_test("/ColorSpace")
  let extgstate_key = content_operator_name_for_test("/ExtGState")
  let custom_key = content_operator_name_for_test("/Custom")
  let page_font_name = content_operator_name_for_test("/FPage")
  let form_font_name = content_operator_name_for_test("/FForm")
  let color_space_name = content_operator_name_for_test("/CSPage")
  let graphics_state_name = content_operator_name_for_test("/GSForm")
  let form_xobject = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (subtype_key, PdfNameObject(content_operator_name_for_test("/Form"))),
      (
        resources_key,
        @pdflite.pdf_dictionary([
          (font_key, @pdflite.pdf_dictionary([(form_font_name, PdfInteger(2))])),
          (
            xobject_key,
            @pdflite.pdf_dictionary([(nested_name, PdfInteger(10))]),
          ),
          (
            extgstate_key,
            @pdflite.pdf_dictionary([(graphics_state_name, PdfInteger(11))]),
          ),
          (custom_key, PdfInteger(9)),
        ]),
      ),
    ]),
    StreamGot(Bytes::new(0)),
  )
  let image_xobject = @pdflite.pdf_dictionary([
    (subtype_key, PdfNameObject(content_operator_name_for_test("/Image"))),
  ])
  let page_resources = @pdflite.pdf_dictionary([
    (font_key, @pdflite.pdf_dictionary([(page_font_name, PdfInteger(1))])),
    (
      color_space_key,
      @pdflite.pdf_dictionary([(color_space_name, PdfInteger(3))]),
    ),
    (
      xobject_key,
      @pdflite.pdf_dictionary([
        (form_name, form_xobject),
        (image_name, image_xobject),
      ]),
    ),
    (custom_key, PdfInteger(7)),
  ])
  let result : Result[@pdflite.PdfObject?, Error] = try? doc.content_form_xobject_resources(
    page_resources, form_name,
  )
  guard result is Ok(Some(total_resources)) else {
    fail("expected merged Form XObject resources")
  }
  @test.assert_eq(
    doc.lookup_direct(font_key, total_resources),
    Some(@pdflite.pdf_dictionary([(form_font_name, PdfInteger(2))])),
  )
  @test.assert_eq(
    doc.lookup_direct(color_space_key, total_resources),
    Some(@pdflite.pdf_dictionary([(color_space_name, PdfInteger(3))])),
  )
  @test.assert_eq(
    doc.lookup_direct(xobject_key, total_resources),
    Some(@pdflite.pdf_dictionary([(nested_name, PdfInteger(10))])),
  )
  @test.assert_eq(
    doc.lookup_direct(extgstate_key, total_resources),
    Some(@pdflite.pdf_dictionary([(graphics_state_name, PdfInteger(11))])),
  )
  @test.assert_eq(
    doc.lookup_direct(custom_key, total_resources),
    Some(PdfInteger(9)),
  )
  let wrapper_result : Result[@pdflite.PdfObject?, Error] = try? @pdflite.pdf_content_form_xobject_resources(
    doc, page_resources, form_name,
  )
  guard wrapper_result is Ok(Some(wrapper_resources)) else {
    fail("expected wrapper merged Form XObject resources")
  }
  @test.assert_eq(wrapper_resources, total_resources)
  let image_result : Result[@pdflite.PdfObject?, Error] = try? doc.content_form_xobject_resources(
    page_resources, image_name,
  )
  guard image_result is Ok(None) else {
    fail("expected image XObject to emit no Form resources")
  }
}

///|
test "cpdfcontent operator state parses Form XObject ops with merged resources" {
  let doc = @pdflite.pdf_document_empty()
  let form_name = content_operator_name_for_test("/Fm1")
  let image_name = content_operator_name_for_test("/Im1")
  let xobject_key = content_operator_name_for_test("/XObject")
  let subtype_key = content_operator_name_for_test("/Subtype")
  let resources_key = content_operator_name_for_test("/Resources")
  let length_key = content_operator_name_for_test("/Length")
  let color_space_key = content_operator_name_for_test("/ColorSpace")
  let color_space_name = content_operator_name_for_test("/CSForm")
  let form_data = @ascii.encode(
    "BI /W 2 /H 1 /BPC 8 /CS /CSForm ID A EI B EI Q",
  )
  let form_xobject = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (subtype_key, PdfNameObject(content_operator_name_for_test("/Form"))),
      (length_key, PdfInteger(form_data.length())),
      (
        resources_key,
        @pdflite.pdf_dictionary([
          (
            color_space_key,
            @pdflite.pdf_dictionary([
              (
                color_space_name,
                PdfNameObject(content_operator_name_for_test("/RGB")),
              ),
            ]),
          ),
        ]),
      ),
    ]),
    StreamGot(form_data),
  )
  let image_xobject = @pdflite.pdf_dictionary([
    (subtype_key, PdfNameObject(content_operator_name_for_test("/Image"))),
  ])
  let page_resources = @pdflite.pdf_dictionary([
    (
      xobject_key,
      @pdflite.pdf_dictionary([
        (form_name, form_xobject),
        (image_name, image_xobject),
      ]),
    ),
  ])
  let result : Result[Array[@pdflite.PdfContentOp]?, Error] = try? doc.content_form_xobject_ops(
    page_resources, form_name,
  )
  guard result is Ok(Some(ops)) else {
    fail("expected parsed Form XObject operators")
  }
  @test.assert_eq(ops, [
    Op_InlineImage(
      @pdflite.pdf_dictionary([
        (content_operator_name_for_test("/W"), PdfInteger(2)),
        (content_operator_name_for_test("/H"), PdfInteger(1)),
        (content_operator_name_for_test("/BPC"), PdfInteger(8)),
        (content_operator_name_for_test("/CS"), PdfNameObject(color_space_name)),
      ]),
      None,
      @ascii.encode("A EI B"),
    ),
    Op_Q,
  ])
  let wrapper_result : Result[Array[@pdflite.PdfContentOp]?, Error] = try? @pdflite.pdf_content_form_xobject_ops(
    doc, page_resources, form_name,
  )
  guard wrapper_result is Ok(Some(wrapper_ops)) else {
    fail("expected wrapper parsed Form XObject operators")
  }
  @test.assert_eq(wrapper_ops, ops)
  let image_result : Result[Array[@pdflite.PdfContentOp]?, Error] = try? doc.content_form_xobject_ops(
    page_resources, image_name,
  )
  guard image_result is Ok(None) else {
    fail("expected image XObject to emit no Form operators")
  }
}

///|
test "cpdfcontent operator state emits path entries for drawn paths" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  @test.assert_eq(initial.content_path_entry(false), None)
  let state = initial
    .content_apply_core_op(Op_w(2.0))
    .content_apply_core_op(Op_m(0.0, 0.0))
    .content_apply_core_op(Op_l(10.0, 0.0))
    .content_apply_core_op(Op_S)
  guard state.content_path_entry(true) is Some(entry) else {
    fail("expected current drawn path entry")
  }
  @test.assert_eq(entry.object, PdfContentPathObject(state.path))
  let expected_state : @pdflite.PdfContentState = PdfContentStatePath(
    @pdflite.pdf_content_path_state_with_clipping_path(
      state.path_state,
      state.clipping_path,
    ),
  )
  @test.assert_eq(entry.state, expected_state)
  @test.assert_eq(entry.bounding_box, {
    x0: -1.0,
    y0: -1.0,
    x1: -1.0,
    y1: 1.0,
    x2: 11.0,
    y2: 1.0,
    x3: 11.0,
    y3: -1.0,
  })
  @test.assert_eq(@pdflite.pdf_content_path_entry(state, true), Some(entry))
}

///|
test "cpdfcontent operator state emits shading entries" {
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let state : @pdflite.PdfContentOperatorState = {
    ..initial,
    ctm: @pdflite.transform_translate(5.0, 6.0),
  }
  let name = content_operator_name_for_test("/Sh1")
  let explicit = state.content_shading_entry(
    name,
    Some({ min_x: 1.0, min_y: 2.0, max_x: 3.0, max_y: 4.0 }),
  )
  guard explicit is Some(explicit_entry) else {
    fail("expected explicit shading bbox entry")
  }
  @test.assert_eq(explicit_entry.object, PdfContentShadingObject("/Sh1"))
  @test.assert_eq(explicit_entry.bounding_box, {
    x0: 1.0,
    y0: 2.0,
    x1: 1.0,
    y1: 4.0,
    x2: 3.0,
    y2: 4.0,
    x3: 3.0,
    y3: 2.0,
  })
  guard state.content_shading_entry(name, None) is Some(unbounded) else {
    fail("expected unbounded shading to use clipping path")
  }
  @test.assert_eq(unbounded.object, PdfContentShadingObject("/Sh1"))
  @test.assert_eq(unbounded.bounding_box, {
    x0: 5.0,
    y0: 6.0,
    x1: 5.0,
    y1: 206.0,
    x2: 105.0,
    y2: 206.0,
    x3: 105.0,
    y3: 6.0,
  })
  @test.assert_eq(
    @pdflite.pdf_content_shading_entry(state, name, None),
    Some(unbounded),
  )
}

///|
test "cpdfcontent operator state reads shading entries from resources" {
  let doc = @pdflite.pdf_document_empty()
  let initial = @pdflite.pdf_content_initial_operator_state(
    0.0, 0.0, 100.0, 200.0,
  )
  let state : @pdflite.PdfContentOperatorState = {
    ..initial,
    ctm: @pdflite.transform_translate(5.0, 6.0),
  }
  let shading_name = content_operator_name_for_test("/Sh1")
  let unbounded_name = content_operator_name_for_test("/Sh2")
  let invalid_name = content_operator_name_for_test("/Sh3")
  let resources = @pdflite.pdf_dictionary([
    (
      content_operator_name_for_test("/Shading"),
      @pdflite.pdf_dictionary([
        (
          shading_name,
          @pdflite.pdf_dictionary([
            (content_operator_name_for_test("/ShadingType"), PdfInteger(2)),
            (
              content_operator_name_for_test("/BBox"),
              PdfArray([
                PdfInteger(1),
                PdfInteger(2),
                PdfInteger(3),
                PdfInteger(4),
              ]),
            ),
          ]),
        ),
        (
          unbounded_name,
          @pdflite.pdf_dictionary([
            (content_operator_name_for_test("/ShadingType"), PdfInteger(2)),
          ]),
        ),
        (
          invalid_name,
          @pdflite.pdf_dictionary([
            (content_operator_name_for_test("/ShadingType"), PdfInteger(2)),
            (content_operator_name_for_test("/BBox"), PdfBoolean(true)),
          ]),
        ),
      ]),
    ),
  ])
  guard doc.content_shading_entry_from_resources(state, resources, shading_name)
    is Some(explicit) else {
    fail("expected explicit shading resource entry")
  }
  @test.assert_eq(explicit.object, PdfContentShadingObject("/Sh1"))
  @test.assert_eq(explicit.bounding_box, {
    x0: 1.0,
    y0: 2.0,
    x1: 1.0,
    y1: 4.0,
    x2: 3.0,
    y2: 4.0,
    x3: 3.0,
    y3: 2.0,
  })
  guard doc.content_shading_entry_from_resources(
      state, resources, unbounded_name,
    )
    is Some(unbounded) else {
    fail("expected unbounded shading resource entry")
  }
  @test.assert_eq(unbounded.bounding_box, {
    x0: 5.0,
    y0: 6.0,
    x1: 5.0,
    y1: 206.0,
    x2: 105.0,
    y2: 206.0,
    x3: 105.0,
    y3: 6.0,
  })
  @test.assert_eq(
    doc.content_shading_entry_from_resources(state, resources, invalid_name),
    None,
  )
  @test.assert_eq(
    doc.content_shading_entry_from_resources(
      state,
      resources,
      content_operator_name_for_test("/Missing"),
    ),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_content_shading_entry_from_resources(
      doc, state, resources, shading_name,
    ),
    Some(explicit),
  )
}
