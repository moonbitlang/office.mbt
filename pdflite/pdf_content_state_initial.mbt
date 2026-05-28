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
