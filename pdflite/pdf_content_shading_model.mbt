///|
/// Placeholder for a tiling pattern; detailed tiling-paint payloads are not
/// expanded by the content reader yet.
pub(all) enum PdfContentTiling {
  PdfContentTiling
} derive(Debug, Eq, ToJson)

///|
/// Function-based shading dictionary data.
pub(all) struct PdfContentFunctionShading {
  funshading_domain : (Double, Double, Double, Double)
  funshading_matrix : @geometry.TransformMatrix
  funshading_function : PdfFunction
} derive(Debug, Eq, ToJson)

///|
/// Radial shading dictionary data.
pub(all) struct PdfContentRadialShading {
  radialshading_coords : (Double, Double, Double, Double, Double, Double)
  radialshading_domain : (Double, Double)
  radialshading_function : Array[PdfFunction]
  radialshading_extend : (Bool, Bool)
} derive(Debug, Eq, ToJson)

///|
/// Axial shading dictionary data.
pub(all) struct PdfContentAxialShading {
  axialshading_coords : (Double, Double, Double, Double)
  axialshading_domain : (Double, Double)
  axialshading_function : Array[PdfFunction]
  axialshading_extend : (Bool, Bool)
} derive(Debug, Eq, ToJson)

///|
/// Parsed shading kind selected from `/ShadingType`.
pub(all) enum PdfContentShadingKind {
  PdfContentFunctionShading(PdfContentFunctionShading)
  PdfContentAxialShading(PdfContentAxialShading)
  PdfContentRadialShading(PdfContentRadialShading)
  PdfContentFreeFormGouraudShading
  PdfContentLatticeFormGouraudShading
  PdfContentCoonsPatchMesh
  PdfContentTensorProductPatchMesh
} derive(Debug, Eq, ToJson)

///|
/// Parsed shading with shared colour-space, matrix, graphics-state, and
/// antialias metadata.
pub(all) struct PdfContentShading {
  shading_colourspace : PdfObject
  shading_background : PdfObject?
  shading_bbox : PdfObject?
  shading_antialias : Bool
  shading_matrix : @geometry.TransformMatrix
  shading_extgstate : PdfObject
  shading : PdfContentShadingKind
} derive(Debug, Eq, ToJson)

///|
/// Parsed pattern resource, either a tiling-pattern placeholder or a shading
/// pattern.
pub(all) enum PdfContentPattern {
  PdfContentColouredTilingPattern(PdfContentTiling)
  PdfContentUncolouredTilingPattern(PdfContentTiling)
  PdfContentShadingPattern(PdfContentShading)
} derive(Debug, Eq, ToJson)
