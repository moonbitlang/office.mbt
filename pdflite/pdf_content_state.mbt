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
/// Content state variant carried by one cpdfcontent JSON entry.
pub(all) enum PdfContentState {
  PdfContentStateGlyph(PdfContentGlyphState)
  PdfContentStatePath(PdfContentPathState)
  PdfContentStateClipping(PdfContentClippingState)
} derive(Debug, Eq, ToJson)

///|
/// Eight-point cpdfcontent bounding box quad.
pub(all) struct PdfContentBoundingBox {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
  x2 : Double
  y2 : Double
  x3 : Double
  y3 : Double
} derive(Debug, Eq, ToJson)

///|
/// One item in cpdfcontent's JSON content list.
pub(all) struct PdfContentJsonEntry {
  object : PdfContentObject
  state : PdfContentState
  bounding_box : PdfContentBoundingBox
} derive(Debug, Eq, ToJson)

///|
/// Return cpdfcontent's initial page-boundary clipping path.
pub fn pdf_content_initial_clipping_path(
  minx : Double,
  miny : Double,
  maxx : Double,
  maxy : Double,
) -> Array[PdfPath] {
  [
    {
      winding_rule: PdfPathEvenOdd,
      subpaths: [
        {
          hole: PdfPathNotHole,
          closure: PdfPathClosed,
          segments: [
            PdfPathStraight(point2(minx, miny), point2(minx, maxy)),
            PdfPathStraight(point2(minx, maxy), point2(maxx, maxy)),
            PdfPathStraight(point2(maxx, maxy), point2(maxx, miny)),
            PdfPathStraight(point2(maxx, miny), point2(minx, miny)),
          ],
        },
      ],
    },
  ]
}

///|
/// Return cpdfcontent's initial drawn-path placeholder.
pub fn pdf_content_initial_drawn_path() -> PdfDrawnPath {
  {
    stroked: false,
    filled: false,
    path: { winding_rule: PdfPathEvenOdd, subpaths: [] },
  }
}

///|
fn pdf_content_initial_dash_pattern() -> PdfContentDashPattern {
  { array: [], phase: 0.0 }
}

///|
fn pdf_content_initial_colour_values(
  space : PdfColourSpace,
) -> PdfContentColourValues {
  match space {
    PdfDeviceGray | PdfCalGray(_) | PdfPattern => PdfContentColourFloats([0.0])
    PdfDeviceRGB | PdfCalRGB(_) => PdfContentColourFloats([0.0, 0.0, 0.0])
    PdfLab(_) => PdfContentColourFloats([0.0, 0.0, 0.0, 0.0])
    PdfDeviceCMYK => PdfContentColourFloats([0.0, 0.0, 0.0, 1.0])
    PdfICCBased(components, _, _, _, _) =>
      PdfContentColourFloats([ for _ in 0..<components => 0.0 ])
    PdfIndexed(_) => PdfContentColourFloats([0.0])
    PdfPatternWithBaseColourSpace(base)
    | PdfSeparation(_, base, _)
    | PdfDeviceN(_, base, _, _) => pdf_content_initial_colour_values(base)
  }
}

///|
/// Return cpdfcontent's initial path drawing state for a page boundary.
pub fn pdf_content_initial_path_state(
  minx : Double,
  miny : Double,
  maxx : Double,
  maxy : Double,
) -> PdfContentPathState {
  {
    clipping_path: pdf_content_initial_clipping_path(minx, miny, maxx, maxy),
    colourspace_stroke: PdfDeviceGray,
    colourspace_non_stroke: PdfDeviceGray,
    colour_stroke: PdfContentColourFloats([1.0]),
    colour_non_stroke: PdfContentColourFloats([1.0]),
    line_width: 1.0,
    line_cap: 0,
    line_join: 0,
    dash_pattern: pdf_content_initial_dash_pattern(),
    rendering_intent: "/RelativeColorimetric",
  }
}

///|
/// Return cpdfcontent's initial clipping-only state for a page boundary.
pub fn pdf_content_initial_clipping_state(
  minx : Double,
  miny : Double,
  maxx : Double,
  maxy : Double,
) -> PdfContentClippingState {
  { clipping_path: pdf_content_initial_clipping_path(minx, miny, maxx, maxy) }
}

///|
/// Return cpdfcontent's initial glyph state fields for a page boundary.
pub fn pdf_content_initial_glyph_state(
  minx : Double,
  miny : Double,
  maxx : Double,
  maxy : Double,
) -> PdfContentGlyphState {
  {
    rendering_mode: 0,
    knockout: true,
    font: "",
    font_size: 12.0,
    clipping_path: pdf_content_initial_clipping_path(minx, miny, maxx, maxy),
  }
}

///|
fn pdf_content_state_copy_paths(paths : ArrayView[PdfPath]) -> Array[PdfPath] {
  [
    for path in paths => path
  ]
}

///|
/// Return a clipping-only content state from the current clipping path stack.
pub fn pdf_content_clipping_state_of_paths(
  clipping_path : ArrayView[PdfPath],
) -> PdfContentClippingState {
  { clipping_path: pdf_content_state_copy_paths(clipping_path) }
}

///|
/// Return this path state with a replaced clipping path stack.
pub fn PdfContentPathState::content_with_clipping_path(
  self : PdfContentPathState,
  clipping_path : ArrayView[PdfPath],
) -> PdfContentPathState {
  { ..self, clipping_path: pdf_content_state_copy_paths(clipping_path) }
}

///|
/// Compatibility wrapper for `PdfContentPathState::content_with_clipping_path`.
pub fn pdf_content_path_state_with_clipping_path(
  state : PdfContentPathState,
  clipping_path : ArrayView[PdfPath],
) -> PdfContentPathState {
  state.content_with_clipping_path(clipping_path)
}

///|
/// Return the JSON-facing glyph state for a text state and clipping path.
pub fn PdfContentTextState::content_glyph_state(
  self : PdfContentTextState,
  clipping_path : ArrayView[PdfPath],
) -> PdfContentGlyphState {
  {
    rendering_mode: self.rendering_mode,
    knockout: self.knockout,
    font: self.font,
    font_size: self.font_size,
    clipping_path: pdf_content_state_copy_paths(clipping_path),
  }
}

///|
/// Compatibility wrapper for `PdfContentTextState::content_glyph_state`.
pub fn pdf_content_glyph_state_of_text_state(
  state : PdfContentTextState,
  clipping_path : ArrayView[PdfPath],
) -> PdfContentGlyphState {
  state.content_glyph_state(clipping_path)
}

///|
fn pdf_content_state_copy_doubles(values : ArrayView[Double]) -> Array[Double] {
  [
    for value in values => value
  ]
}

///|
fn pdf_content_state_name_text(name : PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}

///|
/// Apply the cpdfcontent path-state operators that do not require resources.
pub fn PdfContentPathState::content_apply_path_state_op(
  self : PdfContentPathState,
  op : PdfContentOp,
) -> PdfContentPathState {
  match op {
    Op_w(width) => { ..self, line_width: width }
    Op_J(cap) => { ..self, line_cap: cap }
    Op_j(join) => { ..self, line_join: join }
    Op_d(dashes, phase) =>
      {
        ..self,
        dash_pattern: { array: pdf_content_state_copy_doubles(dashes), phase },
      }
    Op_ri(intent) =>
      { ..self, rendering_intent: pdf_content_state_name_text(intent) }
    Op_CS(name) =>
      match pdf_colour_space_of_device_name(name) {
        Some(space) =>
          {
            ..self,
            colourspace_stroke: space,
            colour_stroke: pdf_content_initial_colour_values(space),
          }
        None => self
      }
    Op_cs(name) =>
      match pdf_colour_space_of_device_name(name) {
        Some(space) =>
          {
            ..self,
            colourspace_non_stroke: space,
            colour_non_stroke: pdf_content_initial_colour_values(space),
          }
        None => self
      }
    Op_SC(values) | Op_SCN(values) =>
      {
        ..self,
        colour_stroke: PdfContentColourFloats(
          pdf_content_state_copy_doubles(values),
        ),
      }
    Op_sc(values) | Op_scn(values) =>
      {
        ..self,
        colour_non_stroke: PdfContentColourFloats(
          pdf_content_state_copy_doubles(values),
        ),
      }
    Op_SCNName(name, values) =>
      {
        ..self,
        colour_non_stroke: PdfContentColourNamed(
          pdf_content_state_name_text(name),
          pdf_content_state_copy_doubles(values),
        ),
      }
    Op_scnName(name, values) =>
      {
        ..self,
        colour_stroke: PdfContentColourNamed(
          pdf_content_state_name_text(name),
          pdf_content_state_copy_doubles(values),
        ),
      }
    Op_G(value) =>
      {
        ..self,
        colourspace_stroke: PdfDeviceGray,
        colour_stroke: PdfContentColourFloats([value]),
      }
    Op_g(value) =>
      {
        ..self,
        colourspace_non_stroke: PdfDeviceGray,
        colour_non_stroke: PdfContentColourFloats([value]),
      }
    Op_RG(red, green, blue) =>
      {
        ..self,
        colourspace_stroke: PdfDeviceRGB,
        colour_stroke: PdfContentColourFloats([red, green, blue]),
      }
    Op_rg(red, green, blue) =>
      {
        ..self,
        colourspace_non_stroke: PdfDeviceRGB,
        colour_non_stroke: PdfContentColourFloats([red, green, blue]),
      }
    Op_K(cyan, magenta, yellow, black) =>
      {
        ..self,
        colourspace_stroke: PdfDeviceCMYK,
        colour_stroke: PdfContentColourFloats([cyan, magenta, yellow, black]),
      }
    Op_k(cyan, magenta, yellow, black) =>
      {
        ..self,
        colourspace_non_stroke: PdfDeviceCMYK,
        colour_non_stroke: PdfContentColourFloats([cyan, magenta, yellow, black]),
      }
    _ => self
  }
}

///|
/// Compatibility wrapper for `PdfContentPathState::content_apply_path_state_op`.
pub fn pdf_content_apply_path_state_op(
  state : PdfContentPathState,
  op : PdfContentOp,
) -> PdfContentPathState {
  state.content_apply_path_state_op(op)
}

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

///|
/// Return cpdfcontent's JSON shape for a content state variant.
pub fn PdfContentState::content_json(self : PdfContentState) -> Json {
  match self {
    PdfContentStateGlyph(state) => state.content_json()
    PdfContentStatePath(state) => state.content_json()
    PdfContentStateClipping(state) => state.content_json()
  }
}

///|
/// Compatibility wrapper for `PdfContentState::content_json`.
pub fn pdf_content_state_content_json(state : PdfContentState) -> Json {
  state.content_json()
}

///|
/// Return cpdfcontent's eight-number bbox array.
pub fn PdfContentBoundingBox::content_json(
  self : PdfContentBoundingBox,
) -> Json {
  Json::array([
    Json::number(self.x0),
    Json::number(self.y0),
    Json::number(self.x1),
    Json::number(self.y1),
    Json::number(self.x2),
    Json::number(self.y2),
    Json::number(self.x3),
    Json::number(self.y3),
  ])
}

///|
/// Compatibility wrapper for `PdfContentBoundingBox::content_json`.
pub fn pdf_content_bounding_box_content_json(
  bbox : PdfContentBoundingBox,
) -> Json {
  bbox.content_json()
}

///|
/// Return cpdfcontent's JSON shape for one content-list entry.
pub fn PdfContentJsonEntry::content_json(self : PdfContentJsonEntry) -> Json {
  Json::object(
    Map::of([
      ("object", self.object.content_json()),
      ("state", self.state.content_json()),
      ("bbox", self.bounding_box.content_json()),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfContentJsonEntry::content_json`.
pub fn pdf_content_json_entry_content_json(entry : PdfContentJsonEntry) -> Json {
  entry.content_json()
}

///|
/// Return cpdfcontent's JSON shape for a content-list entry array.
pub fn pdf_content_json_entries_content_json(
  entries : ArrayView[PdfContentJsonEntry],
) -> Json {
  Json::array([ for entry in entries => entry.content_json() ])
}
