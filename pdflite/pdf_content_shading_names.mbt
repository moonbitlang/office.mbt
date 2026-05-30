///|
fn pdf_content_shading_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_content_shading_domain_name : @core.PdfName = pdf_content_shading_name(
  "/Domain",
)

///|
let pdf_content_shading_matrix_name : @core.PdfName = pdf_content_shading_name(
  "/Matrix",
)

///|
let pdf_content_shading_function_name : @core.PdfName = pdf_content_shading_name(
  "/Function",
)

///|
let pdf_content_shading_coords_name : @core.PdfName = pdf_content_shading_name(
  "/Coords",
)

///|
let pdf_content_shading_extend_name : @core.PdfName = pdf_content_shading_name(
  "/Extend",
)

///|
let pdf_content_shading_colourspace_name : @core.PdfName = pdf_content_shading_name(
  "/colourSpace",
)

///|
let pdf_content_shading_background_name : @core.PdfName = pdf_content_shading_name(
  "/Background",
)

///|
let pdf_content_shading_bbox_name : @core.PdfName = pdf_content_shading_name(
  "/BBox",
)

///|
let pdf_content_shading_type_name : @core.PdfName = pdf_content_shading_name(
  "/ShadingType",
)

///|
let pdf_content_shading_extgstate_name : @core.PdfName = pdf_content_shading_name(
  "/ExtGState",
)

///|
let pdf_content_shading_shading_name : @core.PdfName = pdf_content_shading_name(
  "/Shading",
)

///|
let pdf_content_shading_pattern_name : @core.PdfName = pdf_content_shading_name(
  "/Pattern",
)

///|
let pdf_content_shading_pattern_type_name : @core.PdfName = pdf_content_shading_name(
  "/PatternType",
)
