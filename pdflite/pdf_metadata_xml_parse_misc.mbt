///|
fn pdf_metadata_xml_skip_processing_instruction(
  data : BytesView,
  start : Int,
) -> Int raise @core.PdfError {
  let end = pdf_metadata_find_bytes_from(data, start + 2, b"?>")
  guard end >= 0 else { raise BadText }
  end + 2
}

///|
fn pdf_metadata_xml_skip_comment(
  data : BytesView,
  start : Int,
) -> Int raise @core.PdfError {
  let end = pdf_metadata_find_bytes_from(data, start + 4, b"-->")
  guard end >= 0 else { raise BadText }
  end + 3
}

///|
fn pdf_metadata_xml_skip_misc(
  data : BytesView,
  start : Int,
) -> Int raise @core.PdfError {
  let mut index = start
  let mut done = false
  while !done {
    index = pdf_metadata_xml_skip_space(data, index)
    if index + 1 < data.length() &&
      pdf_metadata_view_matches_at(data, index, b"<?") {
      index = pdf_metadata_xml_skip_processing_instruction(data, index)
    } else if index + 3 < data.length() &&
      pdf_metadata_view_matches_at(data, index, b"<!--") {
      index = pdf_metadata_xml_skip_comment(data, index)
    } else {
      done = true
    }
  }
  index
}

///|
fn pdf_metadata_xml_parse_dtd(
  data : BytesView,
  start : Int,
) -> (String?, Int) raise @core.PdfError {
  let index = pdf_metadata_xml_skip_misc(data, start)
  if index + 8 < data.length() &&
    pdf_metadata_view_matches_at(data, index, b"<!DOCTYPE") {
    let end = pdf_metadata_xml_find_tag_end(data, index + 2)
    let text = @utf8.decode(data[index:end + 1]) catch {
      _ => raise InvalidUTF8
    }
    (Some(text), end + 1)
  } else {
    (None, index)
  }
}
