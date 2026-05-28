///|
/// Parse metadata XML bytes into a cpdfmetadata-style XML tree.
///
/// This parser is intentionally scoped to the XML/XMP subset used by PDF
/// metadata: elements, attributes, namespaces, comments, processing
/// instructions, optional DTD text, text data, and predefined or numeric XML
/// entities.
pub fn pdf_metadata_xmltree_of_bytes(
  metadata : BytesView,
) -> PdfMetadataXmlDocument raise PdfError {
  let (dtd, after_dtd) = pdf_metadata_xml_parse_dtd(metadata, 0)
  let root_start = pdf_metadata_xml_skip_misc(metadata, after_dtd)
  guard root_start < metadata.length() && metadata[root_start].to_int() == 60 else {
    raise BadText
  }
  let (tree, after_tree) = pdf_metadata_xml_parse_element(
    metadata,
    root_start,
    [],
  )
  let end = pdf_metadata_xml_skip_misc(metadata, after_tree)
  guard end == metadata.length() else { raise BadText }
  { dtd, tree }
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `xmltree_of_bytes`.
pub fn pdf_xmltree_of_bytes(
  metadata : BytesView,
) -> PdfMetadataXmlDocument raise PdfError {
  pdf_metadata_xmltree_of_bytes(metadata)
}
