///|
pub(all) struct SlicerOptions {
  name : String
  cell : String
  table_sheet : String
  table_name : String
  mut caption : String
  mut macro_name : String
  mut width : Int
  mut height : Int
  mut display_header : Bool?
  mut item_desc : Bool
  mut format : GraphicOptions
} derive(Show)

///|
pub fn SlicerOptions::new(
  name : String,
  cell : String,
  table_sheet : String,
  table_name : String,
) -> SlicerOptions raise XlsxError {
  if name == "" || cell == "" || table_sheet == "" || table_name == "" {
    raise InvalidSheetOperation(msg="slicer options missing required fields")
  }
  ignore(cell_ref_to_rc(cell))
  {
    name,
    cell,
    table_sheet,
    table_name,
    caption: "",
    macro_name: "",
    width: 200,
    height: 200,
    display_header: None,
    item_desc: false,
    format: GraphicOptions::new(),
  }
}

///|
pub fn SlicerOptions::set_caption(
  self : SlicerOptions,
  caption : String,
) -> Unit {
  self.caption = caption
}

///|
pub fn SlicerOptions::set_macro_name(
  self : SlicerOptions,
  macro_name : String,
) -> Unit {
  self.macro_name = macro_name
}

///|
pub fn SlicerOptions::set_size(
  self : SlicerOptions,
  width : Int,
  height : Int,
) -> Unit raise XlsxError {
  if width <= 0 || height <= 0 {
    raise InvalidSheetOperation(msg="slicer size must be > 0")
  }
  self.width = width
  self.height = height
}

///|
pub fn SlicerOptions::set_display_header(
  self : SlicerOptions,
  display_header : Bool?,
) -> Unit {
  self.display_header = display_header
}

///|
pub fn SlicerOptions::set_item_desc(
  self : SlicerOptions,
  item_desc : Bool,
) -> Unit {
  self.item_desc = item_desc
}

///|
pub fn SlicerOptions::set_format(
  self : SlicerOptions,
  format : GraphicOptions,
) -> Unit {
  self.format = format
}
