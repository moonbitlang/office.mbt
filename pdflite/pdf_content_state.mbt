///|
/// Colour operands carried by cpdfcontent's path drawing state.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfContentColourValues {
  PdfContentColourFloats(Array[Double])
  PdfContentColourNamed(String, Array[Double])
  PdfContentColourPattern
}

///|
/// Dash pattern carried by cpdfcontent's path drawing state.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentDashPattern {
  array : Array[Double]
  phase : Double
}

///|
/// Path drawing state exported by cpdfcontent's JSON view.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentPathState {
  clipping_path : Array[@shape.PdfPath]
  colourspace_stroke : PdfColourSpace
  colourspace_non_stroke : PdfColourSpace
  colour_stroke : PdfContentColourValues
  colour_non_stroke : PdfContentColourValues
  line_width : Double
  line_cap : Int32
  line_join : Int32
  dash_pattern : PdfContentDashPattern
  rendering_intent : String
}

///|
/// Clipping-only state exported for inline images, images, and shadings.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentClippingState {
  clipping_path : Array[@shape.PdfPath]
}

///|
/// Text state fields exported alongside glyph content objects.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentGlyphState {
  rendering_mode : Int32
  knockout : Bool
  font : String
  font_size : Double
  clipping_path : Array[@shape.PdfPath]
}

///|
/// Content objects emitted by cpdfcontent's JSON exporter.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfContentObject {
  PdfContentGlyphObject(Int32, String, String)
  PdfContentInlineImageObject
  PdfContentImageObject(String)
  PdfContentPathObject(@shape.PdfDrawnPath)
  PdfContentShadingObject(String)
}

///|
/// Content state variant carried by one cpdfcontent JSON entry.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfContentState {
  PdfContentStateGlyph(PdfContentGlyphState)
  PdfContentStatePath(PdfContentPathState)
  PdfContentStateClipping(PdfContentClippingState)
}

///|
/// Eight-point cpdfcontent bounding box quad.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentBoundingBox {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
  x2 : Double
  y2 : Double
  x3 : Double
  y3 : Double
}

///|
/// One item in cpdfcontent's JSON content list.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentJsonEntry {
  object : PdfContentObject
  state : PdfContentState
  bounding_box : PdfContentBoundingBox
}
