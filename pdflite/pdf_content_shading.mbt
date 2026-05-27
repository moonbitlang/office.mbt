///|
fn pdf_content_shading_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_content_shading_domain_name : PdfName = pdf_content_shading_name(
  "/Domain",
)

///|
let pdf_content_shading_matrix_name : PdfName = pdf_content_shading_name(
  "/Matrix",
)

///|
let pdf_content_shading_function_name : PdfName = pdf_content_shading_name(
  "/Function",
)

///|
let pdf_content_shading_coords_name : PdfName = pdf_content_shading_name(
  "/Coords",
)

///|
let pdf_content_shading_extend_name : PdfName = pdf_content_shading_name(
  "/Extend",
)

///|
let pdf_content_shading_colourspace_name : PdfName = pdf_content_shading_name(
  "/colourSpace",
)

///|
let pdf_content_shading_background_name : PdfName = pdf_content_shading_name(
  "/Background",
)

///|
let pdf_content_shading_bbox_name : PdfName = pdf_content_shading_name("/BBox")

///|
let pdf_content_shading_type_name : PdfName = pdf_content_shading_name(
  "/ShadingType",
)

///|
let pdf_content_shading_extgstate_name : PdfName = pdf_content_shading_name(
  "/ExtGState",
)

///|
let pdf_content_shading_shading_name : PdfName = pdf_content_shading_name(
  "/Shading",
)

///|
let pdf_content_shading_pattern_name : PdfName = pdf_content_shading_name(
  "/Pattern",
)

///|
let pdf_content_shading_pattern_type_name : PdfName = pdf_content_shading_name(
  "/PatternType",
)

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
  funshading_matrix : TransformMatrix
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
  shading_matrix : TransformMatrix
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

///|
fn pdf_content_default_function() -> PdfFunction {
  { func: PdfFunctionCalculator({ operations: [] }), domain: [], range: None }
}

///|
fn PdfDocument::pdf_content_shading_function_or_default(
  self : PdfDocument,
  object : PdfObject?,
) -> PdfFunction {
  match object {
    Some(function_object) =>
      try self.parse_function(function_object) catch {
        _ => pdf_content_default_function()
      } noraise {
        function => function
      }
    None => pdf_content_default_function()
  }
}

///|
fn PdfDocument::pdf_content_shading_functions(
  self : PdfDocument,
  shading : PdfObject,
) -> Array[PdfFunction] raise PdfError {
  match self.lookup_direct(pdf_content_shading_function_name, shading) {
    Some(PdfArray(functions)) => {
      let parsed : Array[PdfFunction] = []
      for function_object in functions {
        parsed.push(self.parse_function(function_object))
      }
      parsed
    }
    Some(function_object) => [self.parse_function(function_object)]
    None => [pdf_content_default_function()]
  }
}

///|
fn PdfDocument::pdf_content_shading_domain4(
  self : PdfDocument,
  shading : PdfObject,
) -> (Double, Double, Double, Double) raise PdfError {
  match self.lookup_direct(pdf_content_shading_domain_name, shading) {
    Some(PdfArray(values)) if values.length() == 4 =>
      (
        self.get_number(values[0]),
        self.get_number(values[1]),
        self.get_number(values[2]),
        self.get_number(values[3]),
      )
    _ => (0.0, 1.0, 0.0, 1.0)
  }
}

///|
fn PdfDocument::pdf_content_shading_domain2(
  self : PdfDocument,
  shading : PdfObject,
) -> (Double, Double) raise PdfError {
  match self.lookup_direct(pdf_content_shading_domain_name, shading) {
    Some(PdfArray(values)) if values.length() == 2 =>
      (self.get_number(values[0]), self.get_number(values[1]))
    _ => (0.0, 1.0)
  }
}

///|
fn PdfDocument::pdf_content_shading_coords4(
  self : PdfDocument,
  shading : PdfObject,
) -> (Double, Double, Double, Double) raise PdfError {
  match self.lookup_direct(pdf_content_shading_coords_name, shading) {
    Some(PdfArray(values)) if values.length() == 4 =>
      (
        self.get_number(values[0]),
        self.get_number(values[1]),
        self.get_number(values[2]),
        self.get_number(values[3]),
      )
    _ => (0.0, 0.0, 0.0, 0.0)
  }
}

///|
fn PdfDocument::pdf_content_shading_coords6(
  self : PdfDocument,
  shading : PdfObject,
) -> (Double, Double, Double, Double, Double, Double) raise PdfError {
  match self.lookup_direct(pdf_content_shading_coords_name, shading) {
    Some(PdfArray(values)) if values.length() == 6 =>
      (
        self.get_number(values[0]),
        self.get_number(values[1]),
        self.get_number(values[2]),
        self.get_number(values[3]),
        self.get_number(values[4]),
        self.get_number(values[5]),
      )
    _ => (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  }
}

///|
fn PdfDocument::pdf_content_shading_extend(
  self : PdfDocument,
  shading : PdfObject,
) -> (Bool, Bool) {
  match self.lookup_direct(pdf_content_shading_extend_name, shading) {
    Some(PdfArray([PdfBoolean(first), PdfBoolean(second)])) => (first, second)
    _ => (false, false)
  }
}

///|
/// Read a `/ShadingType 1` function-based shading dictionary.
pub fn PdfDocument::content_read_function_shading(
  self : PdfDocument,
  shading : PdfObject,
) -> PdfContentShadingKind raise PdfError {
  PdfContentFunctionShading({
    funshading_domain: self.pdf_content_shading_domain4(shading),
    funshading_matrix: self.parse_matrix(
      pdf_content_shading_matrix_name, shading,
    ),
    funshading_function: self.pdf_content_shading_function_or_default(
      self.lookup_direct(pdf_content_shading_function_name, shading),
    ),
  })
}

///|
/// Read a `/ShadingType 3` radial shading dictionary.
pub fn PdfDocument::content_read_radial_shading(
  self : PdfDocument,
  shading : PdfObject,
) -> PdfContentShadingKind raise PdfError {
  PdfContentRadialShading({
    radialshading_coords: self.pdf_content_shading_coords6(shading),
    radialshading_domain: self.pdf_content_shading_domain2(shading),
    radialshading_function: self.pdf_content_shading_functions(shading),
    radialshading_extend: self.pdf_content_shading_extend(shading),
  })
}

///|
/// Read a `/ShadingType 2` axial shading dictionary.
pub fn PdfDocument::content_read_axial_shading(
  self : PdfDocument,
  shading : PdfObject,
) -> PdfContentShadingKind raise PdfError {
  PdfContentAxialShading({
    axialshading_coords: self.pdf_content_shading_coords4(shading),
    axialshading_domain: self.pdf_content_shading_domain2(shading),
    axialshading_function: self.pdf_content_shading_functions(shading),
    axialshading_extend: self.pdf_content_shading_extend(shading),
  })
}

///|
/// Read a shading dictionary and preserve the surrounding pattern matrix and
/// graphics-state dictionary supplied by the caller.
pub fn PdfDocument::content_read_shading(
  self : PdfDocument,
  shading_matrix : TransformMatrix,
  shading_extgstate : PdfObject,
  shading : PdfObject,
) -> PdfContentShading raise PdfError {
  let shading_kind = match
    self.lookup_direct(pdf_content_shading_type_name, shading) {
    Some(PdfInteger(1)) => self.content_read_function_shading(shading)
    Some(PdfInteger(2)) => self.content_read_axial_shading(shading)
    Some(PdfInteger(3)) => self.content_read_radial_shading(shading)
    Some(PdfInteger(4)) => PdfContentFreeFormGouraudShading
    Some(PdfInteger(5)) => PdfContentLatticeFormGouraudShading
    Some(PdfInteger(6)) => PdfContentCoonsPatchMesh
    Some(PdfInteger(7)) => PdfContentTensorProductPatchMesh
    _ => PdfContentTensorProductPatchMesh
  }
  {
    shading_colourspace: match
      self.lookup_direct(pdf_content_shading_colourspace_name, shading) {
      Some(colourspace) => colourspace
      None => PdfNull
    },
    shading_background: self.lookup_direct(
      pdf_content_shading_background_name, shading,
    ),
    shading_bbox: self.lookup_direct(pdf_content_shading_bbox_name, shading),
    shading_antialias: match
      self.lookup_direct(pdf_content_shading_bbox_name, shading) {
      Some(PdfBoolean(true)) => true
      _ => false
    },
    shading_matrix,
    shading_extgstate,
    shading: shading_kind,
  }
}

///|
/// Read a tiling pattern as the current placeholder representation.
pub fn pdf_content_read_tiling_pattern(
  _pattern : PdfObject,
) -> PdfContentPattern {
  PdfContentColouredTilingPattern(PdfContentTiling)
}

///|
/// Read a `/PatternType 2` shading pattern dictionary.
pub fn PdfDocument::content_read_shading_pattern(
  self : PdfDocument,
  pattern : PdfObject,
) -> PdfContentPattern raise PdfError {
  let matrix = self.parse_matrix(pdf_content_shading_matrix_name, pattern)
  let extgstate = match
    self.lookup_direct(pdf_content_shading_extgstate_name, pattern) {
    Some(PdfDictionary(_) as dictionary) => dictionary
    _ => pdf_dictionary([])
  }
  match self.lookup_direct(pdf_content_shading_shading_name, pattern) {
    Some(shading) =>
      PdfContentShadingPattern(
        self.content_read_shading(matrix, extgstate, shading),
      )
    None => raise SoftError("No shading dictionary")
  }
}

///|
/// Look up and read a named pattern resource.
pub fn PdfDocument::content_read_pattern(
  self : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentPattern? raise PdfError {
  match self.lookup_direct(pdf_content_shading_pattern_name, resources) {
    Some(pattern_dictionary) =>
      match self.lookup_direct(name, pattern_dictionary) {
        Some(pattern) =>
          match
            self.lookup_direct(pdf_content_shading_pattern_type_name, pattern) {
            Some(PdfInteger(1)) =>
              Some(pdf_content_read_tiling_pattern(pattern))
            Some(PdfInteger(2)) =>
              Some(self.content_read_shading_pattern(pattern))
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
/// Function wrapper for `PdfDocument::content_read_pattern`.
pub fn pdf_content_read_pattern(
  document : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> PdfContentPattern? raise PdfError {
  document.content_read_pattern(resources, name)
}
