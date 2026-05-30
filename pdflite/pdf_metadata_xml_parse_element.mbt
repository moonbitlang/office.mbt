///|
fn pdf_metadata_xml_parse_element(
  data : BytesView,
  start : Int,
  context : ArrayView[(String, String)],
) -> (@metadata.PdfMetadataXmlTree, Int) raise PdfError {
  let (qualified_name, tag, child_context, self_closing, after_tag) = pdf_metadata_xml_parse_start_tag(
    data, start, context,
  )
  if self_closing {
    (PdfMetadataXmlElement(tag, []), after_tag)
  } else {
    let children : Array[@metadata.PdfMetadataXmlTree] = []
    let mut index = after_tag
    let mut closed = false
    while !closed {
      guard index < data.length() else { raise BadText }
      if pdf_metadata_view_matches_at(data, index, b"</") {
        let (close_name, after_close) = pdf_metadata_xml_parse_close_tag(
          data, index,
        )
        guard close_name == qualified_name else { raise BadText }
        index = after_close
        closed = true
      } else if pdf_metadata_view_matches_at(data, index, b"<!--") {
        index = pdf_metadata_xml_skip_comment(data, index)
      } else if pdf_metadata_view_matches_at(data, index, b"<?") {
        index = pdf_metadata_xml_skip_processing_instruction(data, index)
      } else if data[index].to_int() == 60 {
        let (child, after_child) = pdf_metadata_xml_parse_element(
          data, index, child_context,
        )
        children.push(child)
        index = after_child
      } else {
        let next_tag = pdf_metadata_find_byte(data, index, 60)
        let data_end = if next_tag >= 0 { next_tag } else { data.length() }
        match pdf_metadata_decode_xml_text(data[index:data_end]) {
          Some(text) if text != "" => children.push(PdfMetadataXmlData(text))
          Some(_) => ()
          None => raise InvalidUTF8
        }
        index = data_end
      }
    }
    (PdfMetadataXmlElement(tag, children), index)
  }
}
