// Ad-hoc XML DOM for lossless preservation of unknown subtrees.
//
// `XmlReader` is event-based by design. For most parsing paths we
// only need to recognise the elements we model and skip the rest cheaply.
// To preserve unknown OOXML chunks through read → write, skip points
// instead capture the subtree as a small DOM on the surrounding model node.
//
// `XmlElement` / `XmlNode` are that capture format. They mirror the event
// stream exactly: an element has a qualified name, attributes in source
// order, and children that are either nested elements, text, or CDATA. No
// schema interpretation; no defaults; no normalisation. The intent is
// that the corresponding writer produces semantically equivalent XML,
// even when the original element kind has no typed parser.

///|
/// A single XML element captured into an ad-hoc DOM. Attributes are in
/// source order; their values are already entity-decoded (matching what
/// `XmlReader` emits in `StartElement`).
pub(all) struct XmlElement {
  name : QName
  attributes : Array[(QName, String)]
  children : Array[XmlNode]
} derive(Eq, Debug)

///|
pub extend XmlElement with @debug.Debug::{to_repr}

///|
pub extend XmlElement with Eq::{not_equal, equal}

///|
pub extend XmlElement with Show::{to_string, output}

///|
/// One child of an `XmlElement`. The four reader events
/// (`StartElement`/`EndElement`/`Text`/`CData`) compress to three node
/// kinds — `EndElement` is implicit in the parent boundary.
pub(all) enum XmlNode {
  Element(XmlElement)
  Text(String)
  CData(String)
} derive(Eq, Debug)

///|
pub extend XmlNode with @debug.Debug::{to_repr}

///|
pub extend XmlNode with Eq::{not_equal, equal}

///|
pub extend XmlNode with Show::{to_string, output}

///|
/// Convenience constructor. Intended for tests / hand-built fixtures; real
/// readers build `XmlElement` via the `collect_subtree` helper.
pub fn XmlElement::new(
  name : QName,
  attributes : Array[(QName, String)],
  children : Array[XmlNode],
) -> XmlElement {
  { name, attributes, children, }
}

///|
pub impl Show for XmlElement with fn output(self, logger) {
  logger.write_string("XmlElement(")
  logger.write_object(self.name)
  logger.write_string(", attrs=")
  logger.write_object(self.attributes.length())
  logger.write_string(", children=")
  logger.write_object(self.children.length())
  logger.write_string(")")
}

///|
pub impl Show for XmlNode with fn output(self, logger) {
  match self {
    Element(e) => logger.write_object(e)
    Text(s) => {
      logger.write_string("Text(")
      logger.write_object(s)
      logger.write_string(")")
    }
    CData(s) => {
      logger.write_string("CData(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}
