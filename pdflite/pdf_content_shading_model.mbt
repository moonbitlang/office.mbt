///|
/// Placeholder for a tiling pattern; detailed tiling-paint payloads are not
/// expanded by the content reader yet.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfContentTiling {
  PdfContentTiling
}

///|
/// Function-based shading dictionary data.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentFunctionShading {
  funshading_domain : (Double, Double, Double, Double)
  funshading_matrix : @geometry.TransformMatrix
  funshading_function : PdfFunction
}

///|
/// Radial shading dictionary data.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentRadialShading {
  radialshading_coords : (Double, Double, Double, Double, Double, Double)
  radialshading_domain : (Double, Double)
  radialshading_function : Array[PdfFunction]
  radialshading_extend : (Bool, Bool)
}

///|
/// Axial shading dictionary data.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentAxialShading {
  axialshading_coords : (Double, Double, Double, Double)
  axialshading_domain : (Double, Double)
  axialshading_function : Array[PdfFunction]
  axialshading_extend : (Bool, Bool)
}

///|
/// Parsed shading kind selected from `/ShadingType`.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfContentShadingKind {
  PdfContentFunctionShading(PdfContentFunctionShading)
  PdfContentAxialShading(PdfContentAxialShading)
  PdfContentRadialShading(PdfContentRadialShading)
  PdfContentFreeFormGouraudShading
  PdfContentLatticeFormGouraudShading
  PdfContentCoonsPatchMesh
  PdfContentTensorProductPatchMesh
}

///|
/// Parsed shading with shared colour-space, matrix, graphics-state, and
/// antialias metadata.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentShading {
  shading_colourspace : @syntax.PdfObject
  shading_background : @syntax.PdfObject?
  shading_bbox : @syntax.PdfObject?
  shading_antialias : Bool
  shading_matrix : @geometry.TransformMatrix
  shading_extgstate : @syntax.PdfObject
  shading : PdfContentShadingKind
}

///|
/// Parsed pattern resource, either a tiling-pattern placeholder or a shading
/// pattern.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfContentPattern {
  PdfContentColouredTilingPattern(PdfContentTiling)
  PdfContentUncolouredTilingPattern(PdfContentTiling)
  PdfContentShadingPattern(PdfContentShading)
}
