///|
pub struct ShapeLine {
  mut color : String?
  mut width : Double?
} derive(Eq, Show)

///|
fn ShapeLine::new() -> ShapeLine {
  { color: None, width: None }
}

///|
pub fn ShapeLine::with_values(color? : String, width? : Double) -> ShapeLine {
  let line = ShapeLine::new()
  match color {
    Some(value) => line.color = Some(value)
    None => ()
  }
  match width {
    Some(value) => line.width = Some(value)
    None => ()
  }
  line
}

///|
pub struct ShapeFill {
  mut color : String?
  mut transparency : Int?
} derive(Eq, Show)

///|
fn ShapeFill::new() -> ShapeFill {
  { color: None, transparency: None }
}

///|
pub fn ShapeFill::with_values(
  color? : String,
  transparency? : Int,
) -> ShapeFill raise XlsxError {
  let fill = ShapeFill::new()
  match color {
    Some(value) => fill.color = Some(value)
    None => ()
  }
  match transparency {
    Some(value) => {
      if value < 0 || value > 100 {
        raise InvalidSheetOperation(msg="shape fill transparency out of range")
      }
      fill.transparency = Some(value)
    }
    None => ()
  }
  fill
}

///|
pub struct Shape {
  reference : String
  cell : String
  shape_type : String
  macro_alias : String
  macro_name : String
  format : GraphicOptions
  text : String
  paragraph : Array[RichTextRun]
  width : Int
  height : Int
  scale_x : Double
  scale_y : Double
  fill : ShapeFill
  fill_color : String
  fill_transparency : Int
  line : ShapeLine
  line_color : String
  line_width : Double
  name : String
  alt_text : String
  print_object : Bool
  locked : Bool
  positioning : PicturePositioning
} derive(Eq, Show)

///|
let default_shape_size = 160

///|
fn shape_graphic_options(
  scale_x : Double,
  scale_y : Double,
  name : String,
  alt_text : String,
  print_object : Bool,
  locked : Bool,
  positioning : PicturePositioning,
) -> GraphicOptions {
  let format = GraphicOptions::new()
  format.scale_x = Some(scale_x)
  format.scale_y = Some(scale_y)
  format.name = Some(name)
  format.alt_text = Some(alt_text)
  format.print_object = Some(print_object)
  format.locked = Some(locked)
  format.positioning = Some(positioning)
  format
}

///|
fn shape_fill_from_values(
  fill_color : String,
  fill_transparency : Int,
) -> ShapeFill {
  let fill = ShapeFill::new()
  if fill_color != "" {
    fill.color = Some(fill_color)
  }
  fill.transparency = Some(fill_transparency)
  fill
}

///|
fn shape_line_from_values(
  line_color : String,
  line_width : Double,
) -> ShapeLine {
  let line = ShapeLine::new()
  if line_color != "" {
    line.color = Some(line_color)
  }
  line.width = Some(line_width)
  line
}

///|
pub fn Shape::new(
  reference : String,
  shape_type : String,
  macro_name? : String = "",
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
  name? : String = "",
  alt_text? : String = "",
  print_object? : Bool = true,
  locked? : Bool = true,
  positioning? : PicturePositioning = OneCell,
) -> Shape raise XlsxError {
  if reference == "" {
    raise InvalidSheetOperation(msg="shape reference empty")
  }
  if shape_type == "" {
    raise InvalidSheetOperation(msg="shape type empty")
  }
  if width <= 0 || height <= 0 {
    raise InvalidSheetOperation(msg="shape size must be > 0")
  }
  if scale_x <= 0.0 || scale_y <= 0.0 {
    raise InvalidSheetOperation(msg="shape scale must be > 0")
  }
  if fill_transparency < 0 || fill_transparency > 100 {
    raise InvalidSheetOperation(msg="shape fill transparency out of range")
  }
  if line_width <= 0.0 {
    raise InvalidSheetOperation(msg="shape line width must be > 0")
  }
  ignore(cell_ref_to_rc(reference))
  let format = shape_graphic_options(
    scale_x, scale_y, name, alt_text, print_object, locked, positioning,
  )
  let fill = shape_fill_from_values(fill_color, fill_transparency)
  let line = shape_line_from_values(line_color, line_width)
  {
    reference,
    cell: reference,
    shape_type,
    macro_alias: macro_name,
    macro_name,
    format,
    text,
    paragraph,
    width,
    height,
    scale_x,
    scale_y,
    fill,
    fill_color,
    fill_transparency,
    line,
    line_color,
    line_width,
    name,
    alt_text,
    print_object,
    locked,
    positioning,
  }
}
