///|
pub struct Shape {
  reference : String
  shape_type : String
  text : String
} derive(Eq, Show)

///|
pub fn Shape::new(
  reference : String,
  shape_type : String,
  text? : String = "",
) -> Shape raise XlsxError {
  if reference == "" {
    raise XlsxError::InvalidSheetOperation(msg="shape reference empty")
  }
  if shape_type == "" {
    raise XlsxError::InvalidSheetOperation(msg="shape type empty")
  }
  ignore(cell_ref_to_rc(reference))
  { reference, shape_type, text }
}
