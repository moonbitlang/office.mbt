///|
fn pdf_metadata_push_view(output : Array[Byte], bytes : BytesView) -> Unit {
  for byte in bytes {
    output.push(byte)
  }
}

///|
fn pdf_metadata_xml_text(value : String) -> PdfBytes {
  @utf8.encode(
    value
    .replace(old="&", new="&amp;")
    .replace(old="<", new="&lt;")
    .replace(old=">", new="&gt;"),
  )
}

///|
fn pdf_metadata_rewrite_xmp_element_prefix(
  data : BytesView,
  prefix : String,
  field : String,
  replacement : String,
) -> (PdfBytes, Bool) {
  let open_pattern = @ascii.encode("<" + prefix + ":" + field)
  let close_pattern = @ascii.encode("</" + prefix + ":" + field + ">")
  let replacement_bytes = pdf_metadata_xml_text(replacement)
  let output : Array[Byte] = Array::new(
    capacity=data.length() + replacement_bytes.length() + close_pattern.length(),
  )
  let mut changed = false
  let mut search_start = 0
  while search_start < data.length() {
    let tag_start = pdf_metadata_find_bytes_from(
      data, search_start, open_pattern,
    )
    if tag_start < 0 {
      pdf_metadata_push_view(output, data[search_start:])
      search_start = data.length()
    } else {
      let name_end = tag_start + open_pattern.length()
      if name_end >= data.length() ||
        !pdf_metadata_xml_tag_boundary(data[name_end]) {
        pdf_metadata_push_view(output, data[search_start:name_end])
        search_start = name_end
      } else {
        let tag_end = pdf_metadata_find_byte(data, name_end, 62)
        if tag_end < 0 {
          pdf_metadata_push_view(output, data[search_start:])
          search_start = data.length()
        } else if tag_end > tag_start && data[tag_end - 1].to_int() == 47 {
          pdf_metadata_push_view(output, data[search_start:tag_end - 1])
          output.push((62).to_byte())
          pdf_metadata_push_view(output, replacement_bytes)
          pdf_metadata_push_view(output, close_pattern)
          search_start = tag_end + 1
          changed = true
        } else {
          let value_start = tag_end + 1
          let value_end = pdf_metadata_find_bytes_from(
            data, value_start, close_pattern,
          )
          if value_end < 0 {
            pdf_metadata_push_view(output, data[search_start:])
            search_start = data.length()
          } else {
            pdf_metadata_push_view(output, data[search_start:value_start])
            pdf_metadata_push_view(output, replacement_bytes)
            pdf_metadata_push_view(
              output,
              data[value_end:value_end + close_pattern.length()],
            )
            search_start = value_end + close_pattern.length()
            changed = true
          }
        }
      }
    }
  }
  if changed {
    (Bytes::from_array(output), true)
  } else {
    (data.to_owned(), false)
  }
}

///|
fn pdf_metadata_rewrite_xmp_field(
  data : BytesView,
  xml_uri : String,
  fallback_prefix : String,
  field : String,
  replacement : String,
) -> PdfBytes {
  let mut output = data.to_owned()
  let prefixes = pdf_metadata_namespace_prefixes(data, xml_uri, fallback_prefix)
  for prefix in prefixes {
    let (rewritten, _) = pdf_metadata_rewrite_xmp_element_prefix(
      output, prefix, field, replacement,
    )
    output = rewritten
  }
  output
}
