///|
fn pdf_ua_xml_tag_is_self_closing(
  data : BytesView,
  tag_start : Int,
  tag_end : Int,
) -> Bool {
  let mut position = tag_end - 1
  while position > tag_start && pdf_metadata_is_xml_space(data[position]) {
    position -= 1
  }
  position > tag_start && data[position].to_int() == 47
}

///|
fn pdf_ua_remove_xml_element_prefix(
  data : BytesView,
  prefix : String,
  field : String,
) -> (PdfBytes, Bool) {
  let open_pattern = @ascii.encode("<" + prefix + ":" + field)
  let close_pattern = @ascii.encode("</" + prefix + ":" + field + ">")
  let removals : Array[(Int, Int)] = []
  let mut search_start = 0
  while search_start < data.length() {
    let tag_start = pdf_metadata_find_bytes_from(
      data, search_start, open_pattern,
    )
    if tag_start < 0 {
      search_start = data.length()
    } else {
      let name_end = tag_start + open_pattern.length()
      if name_end >= data.length() ||
        !pdf_metadata_xml_tag_boundary(data[name_end]) {
        search_start = name_end
      } else {
        let tag_end = pdf_metadata_find_byte(data, name_end, 62)
        if tag_end < 0 {
          search_start = data.length()
        } else if pdf_ua_xml_tag_is_self_closing(data, tag_start, tag_end) {
          search_start = tag_end + 1
          removals.push((tag_start, search_start))
        } else {
          let value_end = pdf_metadata_find_bytes_from(
            data,
            tag_end + 1,
            close_pattern,
          )
          if value_end < 0 {
            search_start = data.length()
          } else {
            search_start = value_end + close_pattern.length()
            removals.push((tag_start, search_start))
          }
        }
      }
    }
  }
  if removals.length() > 0 {
    let mut output_length = data.length()
    for removal in removals {
      output_length -= removal.1 - removal.0
    }
    let output = Array::make(output_length, b'\x00')
    let mut output_position = 0
    let mut data_position = 0
    for removal in removals {
      output_position = pdf_ua_write_view(
        output,
        output_position,
        data[data_position:removal.0],
      )
      data_position = removal.1
    }
    let _ = pdf_ua_write_view(output, output_position, data[data_position:])
    (Bytes::from_array(output), true)
  } else {
    (data.to_owned(), false)
  }
}

///|
fn pdf_ua_remove_marker_elements(data : BytesView) -> PdfBytes {
  let prefixes = pdf_metadata_namespace_prefixes(
    data, @metadata.pdf_metadata_pdfuaid_namespace, "pdfuaid",
  )
  let mut output = data.to_owned()
  for prefix in prefixes {
    for field in ["part", "rev", "amd", "corr"] {
      let (rewritten, _) = pdf_ua_remove_xml_element_prefix(
        output, prefix, field,
      )
      output = rewritten
    }
  }
  output
}

///|
fn pdf_ua_find_rdf_open_tag(data : BytesView) -> (Int, String)? {
  let prefixes = pdf_metadata_namespace_prefixes(
    data, @metadata.pdf_metadata_rdf_namespace, "rdf",
  )
  for prefix in prefixes {
    let pattern = @ascii.encode("<" + prefix + ":RDF")
    let mut search_start = 0
    while search_start < data.length() {
      let tag_start = pdf_metadata_find_bytes_from(data, search_start, pattern)
      if tag_start < 0 {
        search_start = data.length()
      } else {
        let name_end = tag_start + pattern.length()
        if name_end < data.length() &&
          pdf_metadata_xml_tag_boundary(data[name_end]) {
          let tag_end = pdf_metadata_find_byte(data, name_end, 62)
          if tag_end >= 0 {
            return Some((tag_end + 1, prefix))
          }
        }
        search_start = name_end
      }
    }
  }
  None
}

///|
fn pdf_ua_insert_marker_description(
  data : BytesView,
  part : String,
  revision : Int?,
) -> PdfBytes raise PdfError {
  match pdf_ua_find_rdf_open_tag(data) {
    Some((insert_at, rdf_prefix)) => {
      let marker = pdf_ua_marker_description_bytes(rdf_prefix, part, revision)
      let output = Array::make(data.length() + marker.length(), b'\x00')
      let mut position = pdf_ua_write_view(output, 0, data[:insert_at])
      position = pdf_ua_write_view(output, position, marker)
      let _ = pdf_ua_write_view(output, position, data[insert_at:])
      Bytes::from_array(output)
    }
    None =>
      raise SoftError(
        "insert_as_rdf_description: could not find insertion point.",
      )
  }
}

///|
fn PdfDocument::pdf_ua_mark_inner(
  self : PdfDocument,
  part : String,
  revision : Int?,
) -> PdfDocument raise PdfError {
  let document = match self.metadata() {
    Some(_) => self
    None => self.create_metadata()
  }
  match document.metadata() {
    Some(metadata) => {
      let without_marker = pdf_ua_remove_marker_elements(metadata)
      let marked = pdf_ua_insert_marker_description(
        without_marker, part, revision,
      )
      document.set_metadata_from_bytes(marked, keep_version=true)
    }
    None => raise SoftError("mark_pdfua: could not create metadata")
  }
}
