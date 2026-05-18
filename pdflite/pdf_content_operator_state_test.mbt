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
  let changed : @pdflite.PdfContentOperatorState = {
    ..pushed,
    ctm: @pdflite.transform_translate(7.0, 8.0),
    partial_path: pushed.partial_path.content_apply_path_op(Op_m(1.0, 2.0)).partial_path,
    clipping_path: [],
    path_state: pushed.path_state.content_apply_path_state_op(Op_w(3.0)),
    text_state: pushed.text_state.content_apply_text_state_op(Op_Tc(5.0)),
  }
  let restored = changed.content_apply_graphics_state_op(Op_Q)
  @test.assert_eq(restored.ctm, initial.ctm)
  @test.assert_eq(restored.partial_path, initial.partial_path)
  @test.assert_eq(restored.clipping_path, initial.clipping_path)
  @test.assert_eq(restored.path, initial.path)
  @test.assert_eq(restored.path_state, initial.path_state)
  @test.assert_eq(restored.text_state, initial.text_state)
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
  @test.assert_eq(changed.state_stack.length(), 1)
  @test.assert_eq(changed.ctm, @pdflite.transform_translate(5.0, 6.0))
  @test.assert_eq(changed.path_state.line_width, 7.0)
  @test.assert_eq(changed.text_state.word_spacing, 8.0)
  @test.assert_eq(changed.content_apply_core_op(Op_Q), initial)
  @test.assert_eq(initial.content_apply_core_op(Op_BX), initial)
}
