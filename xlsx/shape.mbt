///|
pub struct Shape {
  reference : String
  shape_type : String
  text : String
  paragraph : Array[RichTextRun]
  width : Int
  height : Int
  scale_x : Double
  scale_y : Double
} derive(Eq, Show)

///|
let default_shape_size = 160

///|
pub fn Shape::new(
  reference : String,
  shape_type : String,
  text? : String = "",
  paragraph? : Array[RichTextRun] = [],
  width? : Int = default_shape_size,
  height? : Int = default_shape_size,
  scale_x? : Double = 1.0,
  scale_y? : Double = 1.0,
) -> Shape raise XlsxError {
  if reference == "" {
    raise XlsxError::InvalidSheetOperation(msg="shape reference empty")
  }
  if shape_type == "" {
    raise XlsxError::InvalidSheetOperation(msg="shape type empty")
  }
  if width <= 0 || height <= 0 {
    raise XlsxError::InvalidSheetOperation(msg="shape size must be > 0")
  }
  if scale_x <= 0.0 || scale_y <= 0.0 {
    raise XlsxError::InvalidSheetOperation(msg="shape scale must be > 0")
  }
  ignore(cell_ref_to_rc(reference))
  { reference, shape_type, text, paragraph, width, height, scale_x, scale_y }
}
