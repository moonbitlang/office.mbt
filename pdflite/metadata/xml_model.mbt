///|
/// Qualified XML name used by the metadata XML tree parser.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfMetadataXmlName {
  uri : String
  local_name : String
  prefix : String?
}

///|
/// XML attribute used by the metadata XML tree parser.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfMetadataXmlAttribute {
  name : PdfMetadataXmlName
  value : String
}

///|
/// XML element tag name and attributes used by metadata trees.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfMetadataXmlTag {
  name : PdfMetadataXmlName
  attributes : Array[PdfMetadataXmlAttribute]
}

///|
/// Minimal XML tree representation used for XMP metadata.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfMetadataXmlTree {
  PdfMetadataXmlElement(PdfMetadataXmlTag, Array[PdfMetadataXmlTree])
  PdfMetadataXmlData(String)
}

///|
/// Parsed XML metadata document with an optional DTD fragment.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfMetadataXmlDocument {
  dtd : String?
  tree : PdfMetadataXmlTree
}
