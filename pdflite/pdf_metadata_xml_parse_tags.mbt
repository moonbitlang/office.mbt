///|
fn pdf_metadata_xml_find_tag_end(
  data : BytesView,
  start : Int,
) -> Int raise PdfError {
  let mut index = start
  let mut quote = 0
  while index < data.length() {
    let value = data[index].to_int()
    if quote != 0 {
      if value == quote {
        quote = 0
      }
    } else if value == 34 || value == 39 {
      quote = value
    } else if value == 62 {
      return index
    }
    index += 1
  }
  raise BadText
}

///|
fn pdf_metadata_xml_is_self_closing_tag(data : BytesView, end : Int) -> Bool {
  let mut index = end - 1
  while index >= 0 && pdf_metadata_is_xml_space(data[index]) {
    index -= 1
  }
  index >= 0 && data[index].to_int() == 47
}

///|
fn pdf_metadata_xml_parse_start_tag(
  data : BytesView,
  start : Int,
  context : ArrayView[(String, String)],
) -> (String, PdfMetadataXmlTag, Array[(String, String)], Bool, Int) raise PdfError {
  guard start < data.length() && data[start].to_int() == 60 else {
    raise BadText
  }
  let tag_end = pdf_metadata_xml_find_tag_end(data, start + 1)
  let self_closing = pdf_metadata_xml_is_self_closing_tag(data, tag_end)
  let body_end = if self_closing {
    let mut index = tag_end - 1
    while index >= start + 1 && pdf_metadata_is_xml_space(data[index]) {
      index -= 1
    }
    index
  } else {
    tag_end
  }
  guard body_end > start else { raise BadText }
  let body = data[start + 1:body_end]
  let body_start = pdf_metadata_xml_skip_space(body, 0)
  let (qname, after_name) = pdf_metadata_xml_read_name(body, body_start)
  let raw_attributes = pdf_metadata_xml_parse_raw_attributes(body, after_name)
  let next_context = pdf_metadata_xml_context_with_attributes(
    context, raw_attributes,
  )
  let tag = pdf_metadata_xml_tag_from_raw(qname, raw_attributes, next_context)
  (
    pdf_metadata_xml_decode_name(qname),
    tag,
    next_context,
    self_closing,
    tag_end + 1,
  )
}

///|
fn pdf_metadata_xml_parse_close_tag(
  data : BytesView,
  start : Int,
) -> (String, Int) raise PdfError {
  guard start + 1 < data.length() &&
    data[start].to_int() == 60 &&
    data[start + 1].to_int() == 47 else {
    raise BadText
  }
  let end = pdf_metadata_find_byte(data, start + 2, 62)
  guard end >= 0 else { raise BadText }
  let name = match pdf_metadata_decode_xml_text(data[start + 2:end]) {
    Some(name) => name
    None => raise InvalidUTF8
  }
  (name, end + 1)
}
