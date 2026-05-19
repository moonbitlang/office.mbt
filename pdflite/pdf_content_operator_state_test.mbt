///|
fn content_operator_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
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
