///|
pub struct ContentTypeDefault {
  extension : String
  content_type : String
}

///|
pub struct ContentTypeOverride {
  part_name : String
  content_type : String
}

///|
pub struct ContentTypes {
  defaults : Array[ContentTypeDefault]
  overrides : Array[ContentTypeOverride]
}

///|
fn ContentTypes::new() -> ContentTypes {
  { defaults: [], overrides: [] }
}

///|
fn ContentTypes::add_default(
  self : ContentTypes,
  extension : String,
  content_type : String,
) -> Unit {
  self.defaults.push({ extension, content_type })
}

///|
fn ContentTypes::add_override(
  self : ContentTypes,
  part_name : String,
  content_type : String,
) -> Unit {
  self.overrides.push({ part_name, content_type })
}

///|
fn ContentTypes::to_xml(self : ContentTypes) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n",
  )
  for item in self.defaults {
    sb.write_view("  <Default Extension=\"")
    sb.write_view(escape_xml_attr(item.extension))
    sb.write_view("\" ContentType=\"")
    sb.write_view(escape_xml_attr(item.content_type))
    sb.write_view("\"/>\n")
  }
  for item in self.overrides {
    sb.write_view("  <Override PartName=\"")
    sb.write_view(escape_xml_attr(item.part_name))
    sb.write_view("\" ContentType=\"")
    sb.write_view(escape_xml_attr(item.content_type))
    sb.write_view("\"/>\n")
  }
  sb.write_view("</Types>")
  sb.to_string()
}
