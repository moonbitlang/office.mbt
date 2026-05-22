///|
fn content_state_json_int_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn content_state_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn content_state_clipping_path_for_test() -> @pdflite.PdfPath {
  {
    winding_rule: PdfPathNonZero,
    subpaths: [
      {
        hole: PdfPathNotHole,
        closure: PdfPathOpen,
        segments: [
          PdfPathStraight(@pdflite.point2(1.0, 2.0), @pdflite.point2(3.0, 4.0)),
        ],
      },
    ],
  }
}

///|
fn content_state_clipping_json_for_test() -> Json {
  Json::array([
    {
      "winding": "non-zero",
      "subpaths": [
        {
          "closed": false,
          "segments": [
            { "line": [{ "x": 1.0, "y": 2.0 }, { "x": 3.0, "y": 4.0 }] },
          ],
        },
      ],
      "stroked": false,
      "filled": false,
    },
  ])
}

///|
fn content_state_initial_clipping_json_for_test() -> Json {
  Json::array([
    {
      "winding": "even-odd",
      "subpaths": [
        {
          "closed": true,
          "segments": [
            { "line": [{ "x": 10.0, "y": 20.0 }, { "x": 10.0, "y": 220.0 }] },
            { "line": [{ "x": 10.0, "y": 220.0 }, { "x": 110.0, "y": 220.0 }] },
            { "line": [{ "x": 110.0, "y": 220.0 }, { "x": 110.0, "y": 20.0 }] },
            { "line": [{ "x": 110.0, "y": 20.0 }, { "x": 10.0, "y": 20.0 }] },
          ],
        },
      ],
      "stroked": false,
      "filled": false,
    },
  ])
}

///|
test "cpdfcontent state exposes initial content states" {
  let clipping_path = @pdflite.pdf_content_initial_clipping_path(
    10.0, 20.0, 110.0, 220.0,
  )
  @test.assert_eq(clipping_path.length(), 1)
  @test.assert_eq(clipping_path[0].winding_rule, PdfPathEvenOdd)
  @test.assert_eq(clipping_path[0].subpaths[0].closure, PdfPathClosed)
  @test.assert_eq(clipping_path[0].subpaths[0].segments.length(), 4)
  let path_state = @pdflite.pdf_content_initial_path_state(
    10.0, 20.0, 110.0, 220.0,
  )
  let dash_json = Json::object(
    Map([("array", Json::array([])), ("phase", Json::number(0.0))]),
  )
  let path_expected = Json::object(
    Map([
      ("clipping path", content_state_initial_clipping_json_for_test()),
      ("colourspace stroke", Json::string("DeviceGray")),
      ("colourspace non stroke", Json::string("DeviceGray")),
      ("colour stroke", Json::array([Json::number(1.0)])),
      ("colour non stroke", Json::array([Json::number(1.0)])),
      ("line width", Json::number(1.0)),
      ("line cap", content_state_json_int_for_test(0)),
      ("line join", content_state_json_int_for_test(0)),
      ("dash pattern", dash_json),
      ("rendering intent", Json::string("/RelativeColorimetric")),
    ]),
  )
  @test.assert_eq(path_state.content_json(), path_expected)
  @test.assert_eq(
    @pdflite.pdf_content_initial_clipping_state(10.0, 20.0, 110.0, 220.0).content_json(),
    Json::object(
      Map([("clipping path", content_state_initial_clipping_json_for_test())]),
    ),
  )
  let glyph_state = @pdflite.pdf_content_initial_glyph_state(
    10.0, 20.0, 110.0, 220.0,
  )
  @test.assert_eq(glyph_state.rendering_mode, 0)
  @test.assert_eq(glyph_state.knockout, true)
  @test.assert_eq(glyph_state.font, "")
  @test.assert_eq(glyph_state.font_size, 12.0)
  let drawn = @pdflite.pdf_content_initial_drawn_path()
  @test.assert_eq(drawn.stroked, false)
  @test.assert_eq(drawn.filled, false)
  @test.assert_eq(drawn.path.winding_rule, PdfPathEvenOdd)
  @test.assert_eq(drawn.path.subpaths.length(), 0)
}

///|
test "cpdfcontent state derives JSON-facing states from operator state" {
  let clipping_path = [content_state_clipping_path_for_test()]
  let clipping_state = @pdflite.pdf_content_clipping_state_of_paths(
    clipping_path,
  )
  @test.assert_eq(clipping_state.clipping_path, clipping_path)
  @test.assert_eq(
    clipping_state.content_json(),
    Json::object(
      Map([("clipping path", content_state_clipping_json_for_test())]),
    ),
  )
  let path_state = @pdflite.pdf_content_initial_path_state(0.0, 0.0, 10.0, 10.0).content_with_clipping_path(
    clipping_path,
  )
  @test.assert_eq(path_state.clipping_path, clipping_path)
  @test.assert_eq(
    @pdflite.pdf_content_path_state_with_clipping_path(
      @pdflite.pdf_content_initial_path_state(0.0, 0.0, 10.0, 10.0),
      clipping_path,
    ).clipping_path,
    clipping_path,
  )
  let text_state = @pdflite.pdf_content_initial_text_state()
    .content_apply_text_state_op(
      Op_Tf(content_state_name_for_test("/F2"), 13.0),
    )
    .content_apply_text_state_op(Op_Tr(5))
  let glyph_state = text_state.content_glyph_state(clipping_path)
  @test.assert_eq(glyph_state.rendering_mode, 5)
  @test.assert_eq(glyph_state.knockout, true)
  @test.assert_eq(glyph_state.font, "/F2")
  @test.assert_eq(glyph_state.font_size, 13.0)
  @test.assert_eq(glyph_state.clipping_path, clipping_path)
  let non_knockout_state = { ..text_state, knockout: false }.content_glyph_state(
    clipping_path,
  )
  @test.assert_eq(non_knockout_state.knockout, false)
  @test.assert_eq(
    @pdflite.pdf_content_glyph_state_of_text_state(text_state, clipping_path),
    glyph_state,
  )
}

///|
test "cpdfcontent state applies basic path-state operators" {
  let initial = @pdflite.pdf_content_initial_path_state(0.0, 0.0, 10.0, 10.0)
  let state = initial
    .content_apply_path_state_op(Op_w(2.5))
    .content_apply_path_state_op(Op_J(1))
    .content_apply_path_state_op(Op_j(2))
    .content_apply_path_state_op(Op_d([3.0, 1.5], 0.25))
    .content_apply_path_state_op(
      Op_ri(content_state_name_for_test("/Absolute")),
    )
  @test.assert_eq(state.line_width, 2.5)
  @test.assert_eq(state.line_cap, 1)
  @test.assert_eq(state.line_join, 2)
  @test.assert_eq(state.dash_pattern, { array: [3.0, 1.5], phase: 0.25 })
  @test.assert_eq(state.rendering_intent, "/Absolute")
  @test.assert_eq(
    @pdflite.pdf_content_apply_path_state_op(state, Op_w(4.0)).line_width,
    4.0,
  )
  @test.assert_eq(state.content_apply_path_state_op(Op_m(1.0, 2.0)), state)
}

///|
test "cpdfcontent state applies colour path-state operators" {
  let initial = @pdflite.pdf_content_initial_path_state(0.0, 0.0, 10.0, 10.0)
  let device_stroke = initial
    .content_apply_path_state_op(Op_RG(0.1, 0.2, 0.3))
    .content_apply_path_state_op(Op_K(0.4, 0.5, 0.6, 0.7))
    .content_apply_path_state_op(
      Op_CS(content_state_name_for_test("/DeviceRGB")),
    )
  @test.assert_eq(device_stroke.colourspace_stroke, PdfDeviceRGB)
  @test.assert_eq(
    device_stroke.colour_stroke,
    PdfContentColourFloats([0.0, 0.0, 0.0]),
  )
  let non_stroke = device_stroke
    .content_apply_path_state_op(Op_g(0.25))
    .content_apply_path_state_op(Op_rg(0.3, 0.4, 0.5))
    .content_apply_path_state_op(Op_k(0.1, 0.2, 0.3, 0.4))
    .content_apply_path_state_op(
      Op_cs(content_state_name_for_test("/DeviceCMYK")),
    )
    .content_apply_path_state_op(Op_sc([0.8, 0.7, 0.6, 0.5]))
  @test.assert_eq(non_stroke.colourspace_non_stroke, PdfDeviceCMYK)
  @test.assert_eq(
    non_stroke.colour_non_stroke,
    PdfContentColourFloats([0.8, 0.7, 0.6, 0.5]),
  )
  let sampled = non_stroke
    .content_apply_path_state_op(Op_SC([0.9]))
    .content_apply_path_state_op(
      Op_SCNName(content_state_name_for_test("/P1"), [0.6]),
    )
    .content_apply_path_state_op(
      Op_scnName(content_state_name_for_test("/P2"), [0.2]),
    )
  @test.assert_eq(sampled.colour_stroke, PdfContentColourNamed("/P2", [0.2]))
  @test.assert_eq(
    sampled.colour_non_stroke,
    PdfContentColourNamed("/P1", [0.6]),
  )
}

///|
test "cpdfcontent state serializes path drawing state JSON" {
  let clipping_path = content_state_clipping_path_for_test()
  let state : @pdflite.PdfContentPathState = {
    clipping_path: [clipping_path],
    colourspace_stroke: PdfDeviceRGB,
    colourspace_non_stroke: PdfPatternWithBaseColourSpace(PdfDeviceCMYK),
    colour_stroke: PdfContentColourFloats([0.1, 0.2, 0.3]),
    colour_non_stroke: PdfContentColourNamed("/P1", [0.5]),
    line_width: 2.5,
    line_cap: 1,
    line_join: 2,
    dash_pattern: { array: [3.0, 1.5], phase: 0.25 },
    rendering_intent: "/RelativeColorimetric",
  }
  let dash_json = Json::object(
    Map([
      ("array", Json::array([Json::number(3.0), Json::number(1.5)])),
      ("phase", Json::number(0.25)),
    ]),
  )
  @test.assert_eq(state.dash_pattern.content_json(), dash_json)
  @test.assert_eq(
    @pdflite.pdf_content_dash_pattern_content_json(state.dash_pattern),
    dash_json,
  )
  let expected = Json::object(
    Map([
      ("clipping path", content_state_clipping_json_for_test()),
      ("colourspace stroke", Json::string("DeviceRGB")),
      ("colourspace non stroke", Json::string("PatternWithBaseColourspace")),
      (
        "colour stroke",
        Json::array([Json::number(0.1), Json::number(0.2), Json::number(0.3)]),
      ),
      (
        "colour non stroke",
        Json::array([Json::string("/P1"), Json::number(0.5)]),
      ),
      ("line width", Json::number(2.5)),
      ("line cap", content_state_json_int_for_test(1)),
      ("line join", content_state_json_int_for_test(2)),
      ("dash pattern", dash_json),
      ("rendering intent", Json::string("/RelativeColorimetric")),
    ]),
  )
  @test.assert_eq(state.content_json(), expected)
  @test.assert_eq(@pdflite.pdf_content_path_state_content_json(state), expected)
}

///|
test "cpdfcontent state serializes glyph and clipping-only state JSON" {
  let clipping_path = content_state_clipping_path_for_test()
  let clipping_state : @pdflite.PdfContentClippingState = {
    clipping_path: [clipping_path],
  }
  let clipping_expected = Json::object(
    Map([("clipping path", content_state_clipping_json_for_test())]),
  )
  @test.assert_eq(clipping_state.content_json(), clipping_expected)
  @test.assert_eq(
    @pdflite.pdf_content_clipping_state_content_json(clipping_state),
    clipping_expected,
  )
  let glyph_state : @pdflite.PdfContentGlyphState = {
    rendering_mode: 3,
    knockout: true,
    font: "/F1",
    font_size: 12.5,
    clipping_path: [clipping_path],
  }
  let glyph_expected = Json::object(
    Map([
      ("rendering mode", content_state_json_int_for_test(3)),
      ("knockout", Json::boolean(true)),
      ("font", Json::string("/F1")),
      ("font size", Json::number(12.5)),
      ("clipping path", content_state_clipping_json_for_test()),
    ]),
  )
  @test.assert_eq(glyph_state.content_json(), glyph_expected)
  @test.assert_eq(
    @pdflite.pdf_content_glyph_state_content_json(glyph_state),
    glyph_expected,
  )
}

///|
test "cpdfcontent state serializes content object JSON" {
  let drawn : @pdflite.PdfDrawnPath = {
    stroked: true,
    filled: false,
    path: content_state_clipping_path_for_test(),
  }
  let cases : Array[(@pdflite.PdfContentObject, Json)] = [
    (
      PdfContentGlyphObject(65, "A", "A"),
      Json::object(
        Map([
          ("obj", Json::string("glyph")),
          ("charcode", content_state_json_int_for_test(65)),
          ("bytes", Json::string("A")),
          ("extracted text", Json::string("A")),
        ]),
      ),
    ),
    (
      PdfContentInlineImageObject,
      Json::object(
        Map([
          ("obj", Json::string("inline image")),
          ("inline image", Json::null()),
        ]),
      ),
    ),
    (
      PdfContentImageObject("Im1"),
      Json::object(
        Map([("obj", Json::string("image")), ("image", Json::string("Im1"))]),
      ),
    ),
    (
      PdfContentPathObject(drawn),
      Json::object(
        Map([
          ("obj", Json::string("path")),
          (
            "path",
            Json::object(
              Map([
                ("winding", Json::string("non-zero")),
                (
                  "subpaths",
                  Json::array([
                    {
                      "closed": false,
                      "segments": [
                        {
                          "line": [
                            { "x": 1.0, "y": 2.0 },
                            { "x": 3.0, "y": 4.0 },
                          ],
                        },
                      ],
                    },
                  ]),
                ),
                ("stroked", Json::boolean(true)),
                ("filled", Json::boolean(false)),
              ]),
            ),
          ),
        ]),
      ),
    ),
    (
      PdfContentShadingObject("Sh1"),
      Json::object(
        Map([("obj", Json::string("shading")), ("shading", Json::string("Sh1"))]),
      ),
    ),
  ]
  for item in cases {
    let (object, expected) = item
    @test.assert_eq(object.content_json(), expected)
    @test.assert_eq(@pdflite.pdf_content_object_content_json(object), expected)
  }
}

///|
test "cpdfcontent state serializes content JSON entries" {
  let clipping_state : @pdflite.PdfContentClippingState = {
    clipping_path: [content_state_clipping_path_for_test()],
  }
  let state : @pdflite.PdfContentState = PdfContentStateClipping(clipping_state)
  let state_json = Json::object(
    Map([("clipping path", content_state_clipping_json_for_test())]),
  )
  @test.assert_eq(state.content_json(), state_json)
  @test.assert_eq(@pdflite.pdf_content_state_content_json(state), state_json)
  let bbox : @pdflite.PdfContentBoundingBox = {
    x0: 0.0,
    y0: 1.0,
    x1: 2.0,
    y1: 3.0,
    x2: 4.0,
    y2: 5.0,
    x3: 6.0,
    y3: 7.0,
  }
  let bbox_json = Json::array([
    Json::number(0.0),
    Json::number(1.0),
    Json::number(2.0),
    Json::number(3.0),
    Json::number(4.0),
    Json::number(5.0),
    Json::number(6.0),
    Json::number(7.0),
  ])
  @test.assert_eq(bbox.content_json(), bbox_json)
  @test.assert_eq(
    @pdflite.pdf_content_bounding_box_content_json(bbox),
    bbox_json,
  )
  let entry : @pdflite.PdfContentJsonEntry = {
    object: PdfContentImageObject("Im1"),
    state,
    bounding_box: bbox,
  }
  let entry_json = Json::object(
    Map([
      (
        "object",
        Json::object(
          Map([("obj", Json::string("image")), ("image", Json::string("Im1"))]),
        ),
      ),
      ("state", state_json),
      ("bbox", bbox_json),
    ]),
  )
  @test.assert_eq(entry.content_json(), entry_json)
  @test.assert_eq(
    @pdflite.pdf_content_json_entry_content_json(entry),
    entry_json,
  )
  @test.assert_eq(
    @pdflite.pdf_content_json_entries_content_json([entry]),
    Json::array([entry_json]),
  )
}
