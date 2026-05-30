///|
fn pdf_ua_qualified_name(prefix : String, name : String) -> String {
  if prefix == "" {
    name
  } else {
    prefix + ":" + name
  }
}

///|
fn pdf_ua_marker_description_length(
  rdf_description : String,
  rdf_about : String,
  part : String,
  revision : Int?,
) -> Int {
  pdf_ua_ascii_length("<") +
  pdf_ua_ascii_length(rdf_description) +
  pdf_ua_ascii_length(" ") +
  pdf_ua_ascii_length(rdf_about) +
  pdf_ua_ascii_length("=\"\" ") +
  pdf_ua_ascii_length("xmlns:pdfuaid=\"") +
  pdf_ua_ascii_length(@metadata.pdf_metadata_pdfuaid_namespace) +
  pdf_ua_ascii_length("\">\n") +
  pdf_ua_pdfua_marker_part_length(part, revision) +
  pdf_ua_ascii_length("</") +
  pdf_ua_ascii_length(rdf_description) +
  pdf_ua_ascii_length(">\n")
}

///|
fn pdf_ua_marker_description_bytes(
  rdf_prefix : String,
  part : String,
  revision : Int?,
) -> @core.PdfBytes {
  let rdf_description = pdf_ua_qualified_name(rdf_prefix, "Description")
  let rdf_about = pdf_ua_qualified_name(rdf_prefix, "about")
  let output = Array::make(
    pdf_ua_marker_description_length(rdf_description, rdf_about, part, revision),
    b'\x00',
  )
  let mut position = pdf_ua_write_ascii(output, 0, "<")
  position = pdf_ua_write_ascii(output, position, rdf_description)
  position = pdf_ua_write_ascii(output, position, " ")
  position = pdf_ua_write_ascii(output, position, rdf_about)
  position = pdf_ua_write_ascii(output, position, "=\"\" ")
  position = pdf_ua_write_ascii(output, position, "xmlns:pdfuaid=\"")
  position = pdf_ua_write_ascii(
    output, position, @metadata.pdf_metadata_pdfuaid_namespace,
  )
  position = pdf_ua_write_ascii(output, position, "\">\n")
  position = pdf_ua_write_pdfua_marker_part(output, position, part, revision)
  position = pdf_ua_write_ascii(output, position, "</")
  position = pdf_ua_write_ascii(output, position, rdf_description)
  let _ = pdf_ua_write_ascii(output, position, ">\n")
  Bytes::from_array(output)
}
