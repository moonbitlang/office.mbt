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
  fill_color : String
  fill_transparency : Int
  line_color : String
  line_width : Double
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
  fill_color? : String = "",
  fill_transparency? : Int = 0,
  line_color? : String = "",
  line_width? : Double = 1.0,
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
  if fill_transparency < 0 || fill_transparency > 100 {
    raise XlsxError::InvalidSheetOperation(
      msg="shape fill transparency out of range",
    )
  }
  if line_width <= 0.0 {
    raise XlsxError::InvalidSheetOperation(msg="shape line width must be > 0")
  }
  ignore(cell_ref_to_rc(reference))
  {
    reference,
    shape_type,
    text,
    paragraph,
    width,
    height,
    scale_x,
    scale_y,
    fill_color,
    fill_transparency,
    line_color,
    line_width,
  }
}
