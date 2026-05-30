///|
let pdf_metadata_xml_uri : String = "http://www.w3.org/XML/1998/namespace"

///|
let pdf_metadata_xmlns_uri : String = "http://www.w3.org/2000/xmlns/"

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
