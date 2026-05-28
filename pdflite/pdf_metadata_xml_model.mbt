///|
/// Qualified XML name used by the metadata XML tree parser.
pub(all) struct PdfMetadataXmlName {
  uri : String
  local_name : String
  prefix : String?
} derive(Debug, Eq, ToJson)

///|
/// XML attribute used by the metadata XML tree parser.
pub(all) struct PdfMetadataXmlAttribute {
  name : PdfMetadataXmlName
  value : String
} derive(Debug, Eq, ToJson)

///|
/// XML element tag name and attributes used by metadata trees.
pub(all) struct PdfMetadataXmlTag {
  name : PdfMetadataXmlName
  attributes : Array[PdfMetadataXmlAttribute]
} derive(Debug, Eq, ToJson)

///|
/// Minimal XML tree representation used for XMP metadata.
pub(all) enum PdfMetadataXmlTree {
  PdfMetadataXmlElement(PdfMetadataXmlTag, Array[PdfMetadataXmlTree])
  PdfMetadataXmlData(String)
} derive(Debug, Eq, ToJson)

///|
/// Parsed XML metadata document with an optional DTD fragment.
pub(all) struct PdfMetadataXmlDocument {
  dtd : String?
  tree : PdfMetadataXmlTree
} derive(Debug, Eq, ToJson)

///|
let pdf_metadata_xml_uri : String = "http://www.w3.org/XML/1998/namespace"

///|
let pdf_metadata_xmlns_uri : String = "http://www.w3.org/2000/xmlns/"
