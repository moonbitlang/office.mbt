///|
fn pdf_metadata_xml_entity_digit(byte : Byte, base : Int) -> Int? {
  let value = byte.to_int()
  if value >= 48 && value <= 57 {
    let digit = value - 48
    if digit < base {
      Some(digit)
    } else {
      None
    }
  } else if base == 16 && value >= 65 && value <= 70 {
    Some(value - 55)
  } else if base == 16 && value >= 97 && value <= 102 {
    Some(value - 87)
  } else {
    None
  }
}

///|
fn pdf_metadata_xml_entity_codepoint(entity : BytesView) -> Int? {
  if entity.length() == 3 && pdf_metadata_view_matches_at(entity, 0, b"amp") {
    Some(38)
  } else if entity.length() == 2 &&
    pdf_metadata_view_matches_at(entity, 0, b"lt") {
    Some(60)
  } else if entity.length() == 2 &&
    pdf_metadata_view_matches_at(entity, 0, b"gt") {
    Some(62)
  } else if entity.length() == 4 &&
    pdf_metadata_view_matches_at(entity, 0, b"quot") {
    Some(34)
  } else if entity.length() == 4 &&
    pdf_metadata_view_matches_at(entity, 0, b"apos") {
    Some(39)
  } else if entity.length() >= 2 && entity[0].to_int() == 35 {
    let mut index = 1
    let mut base = 10
    if index < entity.length() &&
      (entity[index].to_int() == 120 || entity[index].to_int() == 88) {
      base = 16
      index += 1
    }
    if index >= entity.length() {
      return None
    }
    let mut codepoint = 0
    while index < entity.length() {
      match pdf_metadata_xml_entity_digit(entity[index], base) {
        Some(digit) => codepoint = codepoint * base + digit
        None => return None
      }
      if codepoint > 0x10FFFF {
        return None
      }
      index += 1
    }
    if codepoint >= 0xD800 && codepoint <= 0xDFFF {
      None
    } else {
      Some(codepoint)
    }
  } else {
    None
  }
}

///|
fn pdf_metadata_write_xml_codepoint(
  output : Array[Byte],
  position : Int,
  codepoint : Int,
) -> Int? {
  let encoded = pdf_utf8_of_codepoints([codepoint]) catch { _ => return None }
  let mut current = position
  for byte in encoded {
    output[current] = byte
    current += 1
  }
  Some(current)
}

///|
fn pdf_metadata_xml_codepoint_is_space(codepoint : Int) -> Bool {
  codepoint == 9 || codepoint == 10 || codepoint == 13 || codepoint == 32
}

///|
fn pdf_metadata_decode_xml_text(value : BytesView) -> String? {
  let trimmed = pdf_metadata_trim_xml_text(value)
  let output = Array::make(trimmed.length(), b'\x00')
  let mut output_position = 0
  let mut pending_space = false
  let mut index = 0
  while index < trimmed.length() {
    if trimmed[index].to_int() == 38 {
      let semicolon = pdf_metadata_find_byte(trimmed, index + 1, 59)
      if semicolon > index {
        match pdf_metadata_xml_entity_codepoint(trimmed[index + 1:semicolon]) {
          Some(codepoint) =>
            if pdf_metadata_xml_codepoint_is_space(codepoint) {
              if output_position > 0 {
                pending_space = true
              }
              index = semicolon + 1
            } else {
              if pending_space {
                output[output_position] = 32
                output_position += 1
                pending_space = false
              }
              match
                pdf_metadata_write_xml_codepoint(
                  output, output_position, codepoint,
                ) {
                Some(position) => {
                  output_position = position
                  index = semicolon + 1
                }
                None => {
                  output[output_position] = trimmed[index]
                  output_position += 1
                  index += 1
                }
              }
            }
          _ => {
            if pending_space {
              output[output_position] = 32
              output_position += 1
              pending_space = false
            }
            output[output_position] = trimmed[index]
            output_position += 1
            index += 1
          }
        }
      } else {
        if pending_space {
          output[output_position] = 32
          output_position += 1
          pending_space = false
        }
        output[output_position] = trimmed[index]
        output_position += 1
        index += 1
      }
    } else if pdf_metadata_is_xml_space(trimmed[index]) {
      if output_position > 0 {
        pending_space = true
      }
      index += 1
    } else {
      if pending_space {
        output[output_position] = 32
        output_position += 1
        pending_space = false
      }
      output[output_position] = trimmed[index]
      output_position += 1
      index += 1
    }
  }
  let text = @utf8.decode(Bytes::from_array(output[:output_position])) catch {
    _ => return None
  }
  Some(text)
}

///|
fn pdf_metadata_xml_decode_name(value : BytesView) -> String raise PdfError {
  @utf8.decode(value) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_metadata_xml_is_name_boundary(byte : Byte) -> Bool {
  let value = byte.to_int()
  value == 9 ||
  value == 10 ||
  value == 13 ||
  value == 32 ||
  value == 47 ||
  value == 61 ||
  value == 62
}

///|
fn pdf_metadata_xml_skip_space(data : BytesView, start : Int) -> Int {
  let mut index = start
  while index < data.length() && pdf_metadata_is_xml_space(data[index]) {
    index += 1
  }
  index
}

///|
fn pdf_metadata_xml_read_name(
  data : BytesView,
  start : Int,
) -> (Bytes, Int) raise PdfError {
  let mut index = start
  while index < data.length() && !pdf_metadata_xml_is_name_boundary(data[index]) {
    index += 1
  }
  guard index > start else { raise BadText }
  (data[start:index].to_owned(), index)
}

///|
fn pdf_metadata_xml_uri_lookup(
  context : ArrayView[(String, String)],
  prefix : String,
) -> String? {
  for offset in 0..<context.length() {
    let index = context.length() - 1 - offset
    if context[index].0 == prefix {
      break Some(context[index].1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_metadata_xml_resolve_name(
  qname : BytesView,
  is_attribute : Bool,
  context : ArrayView[(String, String)],
) -> PdfMetadataXmlName raise PdfError {
  let colon = pdf_metadata_find_byte(qname, 0, 58)
  if colon >= 0 {
    let prefix = pdf_metadata_xml_decode_name(qname[:colon])
    let local_name = pdf_metadata_xml_decode_name(qname[colon + 1:])
    let uri = if prefix == "xml" {
      pdf_metadata_xml_uri
    } else if prefix == "xmlns" {
      pdf_metadata_xmlns_uri
    } else {
      match pdf_metadata_xml_uri_lookup(context, prefix) {
        Some(uri) => uri
        None => raise BadText
      }
    }
    { uri, local_name, prefix: Some(prefix) }
  } else {
    let local_name = pdf_metadata_xml_decode_name(qname)
    let uri = if is_attribute {
      if local_name == "xmlns" {
        pdf_metadata_xmlns_uri
      } else {
        ""
      }
    } else {
      match pdf_metadata_xml_uri_lookup(context, "") {
        Some(uri) => uri
        None => ""
      }
    }
    { uri, local_name, prefix: None }
  }
}

///|
fn pdf_metadata_xml_parse_raw_attributes(
  data : BytesView,
  start : Int,
) -> Array[(Bytes, String)] raise PdfError {
  let attributes : Array[(Bytes, String)] = []
  let mut index = start
  while index < data.length() {
    index = pdf_metadata_xml_skip_space(data, index)
    if index >= data.length() {
      break
    }
    let (name, after_name) = pdf_metadata_xml_read_name(data, index)
    index = pdf_metadata_xml_skip_space(data, after_name)
    guard index < data.length() && data[index].to_int() == 61 else {
      raise BadText
    }
    index = pdf_metadata_xml_skip_space(data, index + 1)
    guard index < data.length() &&
      (data[index].to_int() == 34 || data[index].to_int() == 39) else {
      raise BadText
    }
    let quote = data[index].to_int()
    let value_start = index + 1
    let value_end = pdf_metadata_find_byte(data, value_start, quote)
    guard value_end >= 0 else { raise BadText }
    let value = match
      pdf_metadata_decode_xml_text(data[value_start:value_end]) {
      Some(value) => value
      None => raise InvalidUTF8
    }
    attributes.push((name, value))
    index = value_end + 1
  }
  attributes
}

///|
fn pdf_metadata_xml_context_with_attributes(
  context : ArrayView[(String, String)],
  attributes : ArrayView[(Bytes, String)],
) -> Array[(String, String)] raise PdfError {
  let output = context.to_owned()
  for attribute in attributes {
    let name = attribute.0[:]
    if name.length() == 5 && pdf_metadata_view_matches_at(name, 0, b"xmlns") {
      output.push(("", attribute.1))
    } else if name.length() > 6 &&
      pdf_metadata_view_matches_at(name, 0, b"xmlns:") {
      output.push((pdf_metadata_xml_decode_name(name[6:]), attribute.1))
    }
  }
  output
}

///|
fn pdf_metadata_xml_tag_from_raw(
  name : BytesView,
  attributes : ArrayView[(Bytes, String)],
  context : ArrayView[(String, String)],
) -> PdfMetadataXmlTag raise PdfError {
  let resolved_attributes : Array[PdfMetadataXmlAttribute] = []
  for attribute in attributes {
    resolved_attributes.push({
      name: pdf_metadata_xml_resolve_name(attribute.0, true, context),
      value: attribute.1,
    })
  }
  {
    name: pdf_metadata_xml_resolve_name(name, false, context),
    attributes: resolved_attributes,
  }
}

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

///|
fn pdf_metadata_xml_skip_processing_instruction(
  data : BytesView,
  start : Int,
) -> Int raise PdfError {
  let end = pdf_metadata_find_bytes_from(data, start + 2, b"?>")
  guard end >= 0 else { raise BadText }
  end + 2
}

///|
fn pdf_metadata_xml_skip_comment(
  data : BytesView,
  start : Int,
) -> Int raise PdfError {
  let end = pdf_metadata_find_bytes_from(data, start + 4, b"-->")
  guard end >= 0 else { raise BadText }
  end + 3
}

///|
fn pdf_metadata_xml_skip_misc(
  data : BytesView,
  start : Int,
) -> Int raise PdfError {
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
) -> (String?, Int) raise PdfError {
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

///|
fn pdf_metadata_xml_parse_element(
  data : BytesView,
  start : Int,
  context : ArrayView[(String, String)],
) -> (PdfMetadataXmlTree, Int) raise PdfError {
  let (qualified_name, tag, child_context, self_closing, after_tag) = pdf_metadata_xml_parse_start_tag(
    data, start, context,
  )
  if self_closing {
    (PdfMetadataXmlElement(tag, []), after_tag)
  } else {
    let children : Array[PdfMetadataXmlTree] = []
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
