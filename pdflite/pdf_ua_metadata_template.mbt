///|
fn pdf_ua_metadata_length(subformat : PdfUASubformat, title : String) -> Int {
  pdf_ua_ascii_length(
    "<?xpacket begin=\"\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n",
  ) +
  pdf_ua_ascii_length("<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n") +
  pdf_ua_ascii_length(
    "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n",
  ) +
  pdf_ua_ascii_length(
    "<rdf:Description rdf:about=\"\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n",
  ) +
  pdf_ua_ascii_length("<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">") +
  pdf_ua_xml_escaped_utf8_length(title) +
  pdf_ua_ascii_length("</rdf:li></rdf:Alt></dc:title>\n</rdf:Description>\n") +
  pdf_ua_ascii_length("<rdf:Description rdf:about=\"\" xmlns:pdfuaid=\"") +
  pdf_ua_ascii_length(@metadata.pdf_metadata_pdfuaid_namespace) +
  pdf_ua_ascii_length("\">\n") +
  pdf_ua_pdfua_marker_length(subformat) +
  pdf_ua_ascii_length(
    "</rdf:Description>\n</rdf:RDF>\n</x:xmpmeta>\n<?xpacket end=\"w\"?>",
  )
}

///|
fn pdf_ua_metadata_bytes(
  subformat : PdfUASubformat,
  title : String,
) -> @core.PdfBytes {
  let output = Array::make(pdf_ua_metadata_length(subformat, title), b'\x00')
  let mut position = pdf_ua_write_ascii(
    output, 0, "<?xpacket begin=\"\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n",
  )
  position = pdf_ua_write_ascii(
    output, position, "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n",
  )
  position = pdf_ua_write_ascii(
    output, position, "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n",
  )
  position = pdf_ua_write_ascii(
    output, position, "<rdf:Description rdf:about=\"\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n",
  )
  position = pdf_ua_write_ascii(
    output, position, "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">",
  )
  position = pdf_ua_write_xml_escaped_utf8(output, position, title)
  position = pdf_ua_write_ascii(
    output, position, "</rdf:li></rdf:Alt></dc:title>\n</rdf:Description>\n",
  )
  position = pdf_ua_write_ascii(
    output, position, "<rdf:Description rdf:about=\"\" xmlns:pdfuaid=\"",
  )
  position = pdf_ua_write_ascii(
    output, position, @metadata.pdf_metadata_pdfuaid_namespace,
  )
  position = pdf_ua_write_ascii(output, position, "\">\n")
  position = pdf_ua_write_pdfua_marker(output, position, subformat)
  let _ = pdf_ua_write_ascii(
    output, position, "</rdf:Description>\n</rdf:RDF>\n</x:xmpmeta>\n<?xpacket end=\"w\"?>",
  )
  Bytes::from_array(output)
}
