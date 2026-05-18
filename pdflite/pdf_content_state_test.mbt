///|
fn content_state_json_int_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
test "cpdfcontent state serializes path drawing state JSON" {
  let clipping_path : @pdflite.PdfPath = {
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
      (
        "clipping path",
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
        ]),
      ),
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
