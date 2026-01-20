///|
test "content types xml" {
  let types = ContentTypes::new()
  types.add_default("xml", "application/xml")
  types.add_override("/xl/foo&bar.xml", "application/test+xml")
  inspect(
    types.to_xml(),
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      #|  <Default Extension="xml" ContentType="application/xml"/>
      #|  <Override PartName="/xl/foo&amp;bar.xml" ContentType="application/test+xml"/>
      #|</Types>
    ),
  )
}
