///|
pub struct Slicer {
  name : String
  cell : String
  table_sheet : String
  table_name : String
  caption : String
  width : Int
  height : Int
  display_header : Bool?
  item_desc : Bool
  format : GraphicOptions
} derive(Eq, Show)

///|
pub fn Slicer::new(name : String) -> Slicer raise XlsxError {
  if name == "" {
    raise XlsxError::InvalidSheetOperation(msg="slicer name empty")
  }
  {
    name,
    cell: "",
    table_sheet: "",
    table_name: "",
    caption: "",
    width: 200,
    height: 200,
    display_header: None,
    item_desc: false,
    format: GraphicOptions::new(),
  }
}

///|
fn write_slicer_xml(slicer : Slicer, cache_id : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<slicer xmlns=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" name=\"",
  )
  sb.write_view(escape_xml_attr(slicer.name))
  sb.write_view("\" cacheId=\"\{cache_id}\"")
  if slicer.caption != "" {
    sb.write_view(" caption=\"")
    sb.write_view(escape_xml_attr(slicer.caption))
    sb.write_view("\"")
  }
  match slicer.display_header {
    Some(value) => sb.write_view(" showCaption=\"\{bool_attr(value)}\"")
    None => ()
  }
  sb.write_view("/>")
  sb.to_string()
}

///|
fn write_slicer_cache_xml(slicer : Slicer, cache_id : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<slicerCacheDefinition xmlns=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" name=\"",
  )
  sb.write_view(escape_xml_attr(slicer.name))
  sb.write_view("\" cacheId=\"\{cache_id}\"")
  let source_name = if slicer.table_name != "" {
    slicer.table_name
  } else {
    slicer.name
  }
  sb.write_view(" sourceName=\"")
  sb.write_view(escape_xml_attr(source_name))
  sb.write_view("\"/>")
  sb.to_string()
}
