///|
/// Colour operands carried by cpdfcontent's path drawing state.
pub(all) enum PdfContentColourValues {
  PdfContentColourFloats(Array[Double])
  PdfContentColourNamed(String, Array[Double])
  PdfContentColourPattern
} derive(Debug, Eq, ToJson)

///|
/// Dash pattern carried by cpdfcontent's path drawing state.
pub(all) struct PdfContentDashPattern {
  array : Array[Double]
  phase : Double
} derive(Debug, Eq, ToJson)

///|
/// Path drawing state exported by cpdfcontent's JSON view.
pub(all) struct PdfContentPathState {
  clipping_path : Array[PdfPath]
  colourspace_stroke : PdfColourSpace
  colourspace_non_stroke : PdfColourSpace
  colour_stroke : PdfContentColourValues
  colour_non_stroke : PdfContentColourValues
  line_width : Double
  line_cap : Int
  line_join : Int
  dash_pattern : PdfContentDashPattern
  rendering_intent : String
} derive(Debug, Eq, ToJson)

///|
fn pdf_colour_space_content_name(space : PdfColourSpace) -> String {
  match space {
    PdfDeviceGray => "DeviceGray"
    PdfDeviceRGB => "DeviceRGB"
    PdfDeviceCMYK => "DeviceCMYK"
    PdfCalGray(_) => "CalGray"
    PdfCalRGB(_) => "CalRGB"
    PdfLab(_) => "Lab"
    PdfICCBased(_) => "ICCBased"
    PdfIndexed(_) => "Indexed"
    PdfPattern => "Pattern"
    PdfPatternWithBaseColourSpace(_) => "PatternWithBaseColourspace"
    PdfSeparation(_) => "Separation"
    PdfDeviceN(_) => "DeviceN"
  }
}

///|
/// Return cpdfcontent's JSON colour-space name.
pub fn PdfColourSpace::content_json(self : PdfColourSpace) -> Json {
  Json::string(pdf_colour_space_content_name(self))
}

///|
/// Compatibility wrapper for `PdfColourSpace::content_json`.
pub fn pdf_colour_space_content_json(space : PdfColourSpace) -> Json {
  space.content_json()
}

///|
/// Return cpdfcontent's JSON shape for colour operands.
pub fn PdfContentColourValues::content_json(
  self : PdfContentColourValues,
) -> Json {
  match self {
    PdfContentColourFloats(values) =>
      Json::array([ for value in values => Json::number(value) ])
    PdfContentColourNamed(name, values) => {
      let output : Array[Json] = [Json::string(name)]
      for value in values {
        output.push(Json::number(value))
      }
      Json::array(output)
    }
    PdfContentColourPattern => Json::string("pattern")
  }
}

///|
/// Compatibility wrapper for `PdfContentColourValues::content_json`.
pub fn pdf_content_colour_values_content_json(
  values : PdfContentColourValues,
) -> Json {
  values.content_json()
}

///|
/// Return cpdfcontent's JSON shape for a path dash pattern.
pub fn PdfContentDashPattern::content_json(
  self : PdfContentDashPattern,
) -> Json {
  Json::object(
    Map::of([
      ("array", Json::array([ for value in self.array => Json::number(value) ])),
      ("phase", Json::number(self.phase)),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfContentDashPattern::content_json`.
pub fn pdf_content_dash_pattern_content_json(
  pattern : PdfContentDashPattern,
) -> Json {
  pattern.content_json()
}

///|
fn pdf_content_clipping_path_content_json(paths : ArrayView[PdfPath]) -> Json {
  Json::array(
    [
      for path in paths => {
        let drawn : PdfDrawnPath = { stroked: false, filled: false, path }
        drawn.content_json()
      }
    ],
  )
}

///|
/// Return cpdfcontent's JSON shape for path drawing state.
pub fn PdfContentPathState::content_json(self : PdfContentPathState) -> Json {
  Json::object(
    Map::of([
      (
        "clipping path",
        pdf_content_clipping_path_content_json(self.clipping_path),
      ),
      ("colourspace stroke", self.colourspace_stroke.content_json()),
      ("colourspace non stroke", self.colourspace_non_stroke.content_json()),
      ("colour stroke", self.colour_stroke.content_json()),
      ("colour non stroke", self.colour_non_stroke.content_json()),
      ("line width", Json::number(self.line_width)),
      ("line cap", pdf_util_json_number(self.line_cap)),
      ("line join", pdf_util_json_number(self.line_join)),
      ("dash pattern", self.dash_pattern.content_json()),
      ("rendering intent", Json::string(self.rendering_intent)),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfContentPathState::content_json`.
pub fn pdf_content_path_state_content_json(state : PdfContentPathState) -> Json {
  state.content_json()
}
