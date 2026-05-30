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
  clipping_path : Array[@shape.PdfPath]
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
  clipping_path : Array[@shape.PdfPath]
} derive(Debug, Eq, ToJson)

///|
/// Text state fields exported alongside glyph content objects.
pub(all) struct PdfContentGlyphState {
  rendering_mode : Int
  knockout : Bool
  font : String
  font_size : Double
  clipping_path : Array[@shape.PdfPath]
} derive(Debug, Eq, ToJson)

///|
/// Content objects emitted by cpdfcontent's JSON exporter.
pub(all) enum PdfContentObject {
  PdfContentGlyphObject(Int, String, String)
  PdfContentInlineImageObject
  PdfContentImageObject(String)
  PdfContentPathObject(@shape.PdfDrawnPath)
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
