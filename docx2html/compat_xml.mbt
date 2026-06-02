///|
pub type XmlNode = @xml.XmlNode

///|
pub type XmlElement = @xml.XmlElement

///|
pub fn xml_element(
  name : String,
  attributes? : Map[String, String] = {},
  children? : Array[XmlNode] = [],
) -> XmlElement {
  @xml.xml_element(name, attributes~, children~)
}

///|
pub fn xml_text(value : String) -> XmlNode {
  @xml.xml_text(value)
}

///|
pub fn read_xml_string(
  value : String,
  namespace_map? : Map[String, String] = {},
) -> XmlElement raise DocxError {
  bridge_core_error(() => @xml.read_xml_string(value, namespace_map~))
}

///|
pub fn write_xml_string(
  element : XmlElement,
  namespaces? : Map[String, String] = {},
) -> String {
  @xml.write_xml_string(element, namespaces~)
}
