///|
fn content_state_json_int_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
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
    Map::of([
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
    Map::of([
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
    Map::of([("clipping path", content_state_clipping_json_for_test())]),
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
    Map::of([
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
        Map::of([
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
        Map::of([
          ("obj", Json::string("inline image")),
          ("inline image", Json::null()),
        ]),
      ),
    ),
    (
      PdfContentImageObject("Im1"),
      Json::object(
        Map::of([("obj", Json::string("image")), ("image", Json::string("Im1"))]),
      ),
    ),
    (
      PdfContentPathObject(drawn),
      Json::object(
        Map::of([
          ("obj", Json::string("path")),
          (
            "path",
            Json::object(
              Map::of([
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
        Map::of([
          ("obj", Json::string("shading")),
          ("shading", Json::string("Sh1")),
        ]),
      ),
    ),
  ]
  for item in cases {
    let (object, expected) = item
    @test.assert_eq(object.content_json(), expected)
    @test.assert_eq(@pdflite.pdf_content_object_content_json(object), expected)
  }
}
