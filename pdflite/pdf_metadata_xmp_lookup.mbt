///|
fn pdf_metadata_add_unique(values : Array[String], value : String) -> Unit {
  if value != "" && !values.contains(value) {
    values.push(value)
  }
}

///|
fn pdf_metadata_namespace_prefixes(
  data : BytesView,
  xml_uri : String,
  fallback : String,
) -> Array[String] {
  let prefixes : Array[String] = []
  pdf_metadata_add_unique(prefixes, fallback)
  let namespace_bytes = @ascii.encode(xml_uri)
  let xmlns : ReadOnlyArray[Int] = [120, 109, 108, 110, 115, 58]
  let mut search_start = 0
  while search_start < data.length() {
    let namespace_start = pdf_metadata_find_bytes_from(
      data, search_start, namespace_bytes,
    )
    if namespace_start < 0 {
      search_start = data.length()
    } else {
      let mut attribute_start = namespace_start
      while attribute_start > 0 &&
            !pdf_metadata_is_xml_separator(data[attribute_start - 1]) {
        attribute_start -= 1
      }
      if @core.pdf_view_matches_ascii_at(data, attribute_start, xmlns) {
        let prefix_start = attribute_start + xmlns.length()
        let mut prefix_end = prefix_start
        while prefix_end < namespace_start &&
              data[prefix_end].to_int() != 61 &&
              data[prefix_end].to_int() != 34 &&
              data[prefix_end].to_int() != 39 {
          prefix_end += 1
        }
        match pdf_metadata_decode_xml_text(data[prefix_start:prefix_end]) {
          Some(prefix) => pdf_metadata_add_unique(prefixes, prefix)
          None => ()
        }
      }
      search_start = namespace_start + namespace_bytes.length()
    }
  }
  prefixes
}

///|
fn pdf_metadata_extract_quoted_xml_value(
  data : BytesView,
  start : Int,
  quote : Int,
) -> String? {
  let end = pdf_metadata_find_byte(data, start, quote)
  if end < 0 {
    None
  } else {
    pdf_metadata_decode_xml_text(data[start:end])
  }
}

///|
fn pdf_metadata_extract_xmp_attribute(
  data : BytesView,
  prefix : String,
  name : String,
) -> String? {
  let double_pattern = @ascii.encode(prefix + ":" + name + "=\"")
  let double_start = pdf_metadata_find_bytes_from(data, 0, double_pattern)
  if double_start >= 0 {
    pdf_metadata_extract_quoted_xml_value(
      data,
      double_start + double_pattern.length(),
      34,
    )
  } else {
    let single_pattern = @ascii.encode(prefix + ":" + name + "='")
    let single_start = pdf_metadata_find_bytes_from(data, 0, single_pattern)
    if single_start >= 0 {
      pdf_metadata_extract_quoted_xml_value(
        data,
        single_start + single_pattern.length(),
        39,
      )
    } else {
      None
    }
  }
}

///|
fn pdf_metadata_combine_list_items(values : ArrayView[String]) -> String {
  let output = StringBuilder::new()
  for value in values {
    if !output.is_empty() {
      output.write_string(", ")
    }
    output.write_string(value)
  }
  output.to_string()
}

///|
fn pdf_metadata_extract_rdf_list_items_for_prefix(
  value : BytesView,
  prefix : String,
) -> Array[String] {
  let items : Array[String] = []
  let open_pattern = @ascii.encode("<" + prefix + ":li")
  let close_pattern = @ascii.encode("</" + prefix + ":li>")
  let mut search_start = 0
  while search_start < value.length() {
    let item_start = pdf_metadata_find_bytes_from(
      value, search_start, open_pattern,
    )
    if item_start < 0 {
      search_start = value.length()
    } else {
      let name_end = item_start + open_pattern.length()
      if name_end >= value.length() ||
        !pdf_metadata_xml_tag_boundary(value[name_end]) {
        search_start = name_end
      } else {
        let item_tag_end = pdf_metadata_find_byte(value, name_end, 62)
        if item_tag_end < 0 {
          search_start = value.length()
        } else if value[item_tag_end - 1].to_int() == 47 {
          search_start = item_tag_end + 1
        } else {
          let item_value_start = item_tag_end + 1
          let item_value_end = pdf_metadata_find_bytes_from(
            value, item_value_start, close_pattern,
          )
          if item_value_end < 0 {
            search_start = value.length()
          } else {
            match
              pdf_metadata_decode_xml_text(
                value[item_value_start:item_value_end],
              ) {
              Some(item) => items.push(item)
              None => ()
            }
            search_start = item_value_end + close_pattern.length()
          }
        }
      }
    }
  }
  items
}

///|
fn pdf_metadata_extract_rdf_list_items(
  data : BytesView,
  value : BytesView,
) -> String? {
  let items : Array[String] = []
  let prefixes = pdf_metadata_namespace_prefixes(
    data, @metadata.pdf_metadata_rdf_namespace, "rdf",
  )
  for prefix in prefixes {
    for item in pdf_metadata_extract_rdf_list_items_for_prefix(value, prefix) {
      items.push(item)
    }
  }
  if items.length() == 0 {
    None
  } else {
    Some(pdf_metadata_combine_list_items(items))
  }
}

///|
fn pdf_metadata_extract_xmp_element(
  data : BytesView,
  prefix : String,
  name : String,
) -> String? {
  let open_pattern = @ascii.encode("<" + prefix + ":" + name)
  let tag_start = pdf_metadata_find_bytes_from(data, 0, open_pattern)
  if tag_start < 0 {
    None
  } else {
    let tag_end = pdf_metadata_find_byte(
      data,
      tag_start + open_pattern.length(),
      62,
    )
    if tag_end < 0 || data[tag_end - 1].to_int() == 47 {
      None
    } else {
      let close_pattern = @ascii.encode("</" + prefix + ":" + name + ">")
      let value_start = tag_end + 1
      let value_end = pdf_metadata_find_bytes_from(
        data, value_start, close_pattern,
      )
      if value_end < 0 {
        None
      } else {
        let value = data[value_start:value_end]
        match pdf_metadata_extract_rdf_list_items(data, value) {
          Some(items) => Some(items)
          None => pdf_metadata_decode_xml_text(value)
        }
      }
    }
  }
}

///|
fn pdf_metadata_get_xmp_data(
  data : BytesView,
  xml_uri : String,
  fallback_prefix : String,
  name : String,
) -> String? {
  let prefixes = pdf_metadata_namespace_prefixes(data, xml_uri, fallback_prefix)
  for prefix in prefixes {
    match pdf_metadata_extract_xmp_attribute(data, prefix, name) {
      Some(value) => break Some(value)
      None =>
        match pdf_metadata_extract_xmp_element(data, prefix, name) {
          Some(value) => break Some(value)
          None => ()
        }
    }
  } nobreak {
    None
  }
}

///|
/// Return the first XMP metadata value matching an XML namespace URI and local
/// name. This is the tree-free counterpart of cpdfmetadata's `get_data_for`,
/// covering namespace aliases, attributes, simple element text, and RDF lists.
pub fn pdf_metadata_get_data_for_bytes(
  xml_uri : String,
  name : String,
  metadata : BytesView,
) -> String? {
  pdf_metadata_get_xmp_data(
    metadata,
    xml_uri,
    pdf_metadata_namespace_fallback_prefix(xml_uri),
    name,
  )
}
