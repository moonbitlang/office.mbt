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
/// Clipping-only state exported for inline images, images, and shadings.
pub(all) struct PdfContentClippingState {
  clipping_path : Array[PdfPath]
} derive(Debug, Eq, ToJson)

///|
/// Text state fields exported alongside glyph content objects.
pub(all) struct PdfContentGlyphState {
  rendering_mode : Int
  knockout : Bool
  font : String
  font_size : Double
  clipping_path : Array[PdfPath]
} derive(Debug, Eq, ToJson)

///|
/// Content objects emitted by cpdfcontent's JSON exporter.
pub(all) enum PdfContentObject {
  PdfContentGlyphObject(Int, String, String)
  PdfContentInlineImageObject
  PdfContentImageObject(String)
  PdfContentPathObject(PdfDrawnPath)
  PdfContentShadingObject(String)
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

///|
/// Return cpdfcontent's JSON shape for clipping-only state.
pub fn PdfContentClippingState::content_json(
  self : PdfContentClippingState,
) -> Json {
  Json::object(
    Map::of([
      (
        "clipping path",
        pdf_content_clipping_path_content_json(self.clipping_path),
      ),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfContentClippingState::content_json`.
pub fn pdf_content_clipping_state_content_json(
  state : PdfContentClippingState,
) -> Json {
  state.content_json()
}

///|
/// Return cpdfcontent's JSON shape for glyph state.
pub fn PdfContentGlyphState::content_json(self : PdfContentGlyphState) -> Json {
  Json::object(
    Map::of([
      ("rendering mode", pdf_util_json_number(self.rendering_mode)),
      ("knockout", Json::boolean(self.knockout)),
      ("font", Json::string(self.font)),
      ("font size", Json::number(self.font_size)),
      (
        "clipping path",
        pdf_content_clipping_path_content_json(self.clipping_path),
      ),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfContentGlyphState::content_json`.
pub fn pdf_content_glyph_state_content_json(
  state : PdfContentGlyphState,
) -> Json {
  state.content_json()
}

///|
/// Return cpdfcontent's JSON shape for a content object.
pub fn PdfContentObject::content_json(self : PdfContentObject) -> Json {
  match self {
    PdfContentGlyphObject(charcode, bytes, extracted_text) =>
      Json::object(
        Map::of([
          ("obj", Json::string("glyph")),
          ("charcode", pdf_util_json_number(charcode)),
          ("bytes", Json::string(bytes)),
          ("extracted text", Json::string(extracted_text)),
        ]),
      )
    PdfContentInlineImageObject =>
      Json::object(
        Map::of([
          ("obj", Json::string("inline image")),
          ("inline image", Json::null()),
        ]),
      )
    PdfContentImageObject(name) =>
      Json::object(
        Map::of([("obj", Json::string("image")), ("image", Json::string(name))]),
      )
    PdfContentPathObject(path) =>
      Json::object(
        Map::of([("obj", Json::string("path")), ("path", path.content_json())]),
      )
    PdfContentShadingObject(name) =>
      Json::object(
        Map::of([
          ("obj", Json::string("shading")),
          ("shading", Json::string(name)),
        ]),
      )
  }
}

///|
/// Compatibility wrapper for `PdfContentObject::content_json`.
pub fn pdf_content_object_content_json(object : PdfContentObject) -> Json {
  object.content_json()
}
