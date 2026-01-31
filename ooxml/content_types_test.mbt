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
