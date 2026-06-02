///|
/// Node in the lightweight XML tree.
pub type XmlNode = @xml.XmlNode

///|
/// XML element with a name, attributes, and child nodes.
pub type XmlElement = @xml.XmlElement

///|
/// Builds an XML element.
pub fn xml_element(
  name : String,
  attributes? : Map[String, String] = {},
  children? : Array[XmlNode] = [],
) -> XmlElement {
  @xml.xml_element(name, attributes~, children~)
}

///|
/// Builds an XML text node.
pub fn xml_text(value : String) -> XmlNode {
  @xml.xml_text(value)
}

///|
/// Parses XML text into an element.
pub fn read_xml_string(
  value : String,
  namespace_map? : Map[String, String] = {},
) -> XmlElement raise DocxError {
  bridge_core_error(() => @xml.read_xml_string(value, namespace_map~))
}

///|
/// Serializes an XML element to text.
pub fn write_xml_string(
  element : XmlElement,
  namespaces? : Map[String, String] = {},
) -> String {
  @xml.write_xml_string(element, namespaces~)
}
