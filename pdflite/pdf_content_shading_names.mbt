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
