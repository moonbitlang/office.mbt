///|
priv struct ContentTypeDefault {
  extension : String
  content_type : String
}

///|
priv struct ContentTypeOverride {
  part_name : String
  content_type : String
}

///|
priv struct ContentTypes {
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

///|
test "content types xml" {
  let types = ContentTypes::new()
  types.add_default("xml", "application/xml")
  types.add_override("/xl/foo&bar.xml", "application/test+xml")
  types.add_default("<&\"'", "a<>&\"'")
  types.add_override("/xl/quote\"'<>.xml", "application/test&\"'<>+xml")
  inspect(
    types.to_xml(),
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      #|  <Default Extension="xml" ContentType="application/xml"/>
      #|  <Default Extension="&lt;&amp;&quot;&apos;" ContentType="a&lt;&gt;&amp;&quot;&apos;"/>
      #|  <Override PartName="/xl/foo&amp;bar.xml" ContentType="application/test+xml"/>
      #|  <Override PartName="/xl/quote&quot;&apos;&lt;&gt;.xml" ContentType="application/test&amp;&quot;&apos;&lt;&gt;+xml"/>
      #|</Types>
    ),
  )
}
