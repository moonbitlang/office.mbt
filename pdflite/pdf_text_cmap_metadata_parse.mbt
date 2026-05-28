///|
fn pdf_text_parse_cmap_int_after_token(data : BytesView, key : String) -> Int? {
  let cursor = byte_cursor_of_view(data)
  let mut expect_value = false
  for line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(line)
    let tokens = pdf_split_whitespace_tokens(uncommented)
    for token in tokens {
      if expect_value {
        expect_value = false
        let parsed = try pdf_parse_ascii_int_view(token) catch {
          _ => None
        } noraise {
          value => Some(value)
        }
        match parsed {
          Some(value) => return Some(value)
          None => ()
        }
      }
      if pdf_text_view_equals_ascii(token, key) {
        expect_value = true
      }
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_wmode(data : BytesView) -> Int? {
  pdf_text_parse_cmap_int_after_token(data, "/WMode")
}

///|
fn pdf_text_parse_cmap_name_token(token : BytesView) -> PdfName? {
  guard token.length() > 1 && token[0].to_int() == 47 else { return None }
  let bytes : Array[Byte] = [47]
  let mut index = 1
  while index < token.length() {
    let value = token[index].to_int()
    if value == 35 {
      guard index + 2 < token.length() else { return None }
      match
        (
          pdf_hex_value(token[index + 1].to_int()),
          pdf_hex_value(token[index + 2].to_int()),
        ) {
        (Some(high), Some(low)) => {
          bytes.push((high * 16 + low).to_byte())
          index += 3
        }
        _ => return None
      }
    } else {
      bytes.push(token[index])
      index += 1
    }
  }
  Some(pdf_name_of_bytes(Bytes::from_array(bytes)))
}

///|
fn pdf_text_parse_cmap_name_after_token(
  data : BytesView,
  key : String,
) -> PdfName? {
  let cursor = byte_cursor_of_view(data)
  let mut expect_value = false
  for line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(line)
    let tokens = pdf_split_whitespace_tokens(uncommented)
    for token in tokens {
      if expect_value {
        expect_value = false
        match pdf_text_parse_cmap_name_token(token) {
          Some(name) => return Some(name)
          None => ()
        }
      }
      if pdf_text_view_equals_ascii(token, key) {
        expect_value = true
      }
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_object_token(token : BytesView) -> PdfObject? {
  try pdf_parse_object_from_view(token) catch {
    _ => None
  } noraise {
    object => Some(object)
  }
}

///|
priv enum PdfTextCMapCIDSystemInfoKey {
  PdfTextCMapCIDSystemRegistry
  PdfTextCMapCIDSystemOrdering
  PdfTextCMapCIDSystemSupplement
}

///|
fn pdf_text_parse_cmap_cid_system_value(
  key : PdfTextCMapCIDSystemInfoKey,
  token : BytesView,
  registry : Array[PdfBytes],
  ordering : Array[PdfBytes],
  supplement : Array[Int],
) -> Unit {
  match (key, pdf_text_parse_cmap_object_token(token)) {
    (PdfTextCMapCIDSystemRegistry, Some(PdfString(value))) =>
      registry.push(value)
    (PdfTextCMapCIDSystemOrdering, Some(PdfString(value))) =>
      ordering.push(value)
    (PdfTextCMapCIDSystemSupplement, Some(PdfInteger(value))) =>
      supplement.push(value)
    _ => ()
  }
}

///|
fn pdf_text_parse_cmap_cid_system_info(data : BytesView) -> PdfCIDSystemInfo? {
  let cursor = byte_cursor_of_view(data)
  let registries : Array[PdfBytes] = Array::new(capacity=1)
  let orderings : Array[PdfBytes] = Array::new(capacity=1)
  let supplements : Array[Int] = Array::new(capacity=1)
  let mut seen_cid_system_info = false
  let mut expect_value : PdfTextCMapCIDSystemInfoKey? = None
  for line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(line)
    let tokens = pdf_split_whitespace_tokens(uncommented)
    for token in tokens {
      if !seen_cid_system_info {
        if pdf_text_view_equals_ascii(token, "/CIDSystemInfo") {
          seen_cid_system_info = true
        }
        continue
      }
      match expect_value {
        Some(key) => {
          pdf_text_parse_cmap_cid_system_value(
            key, token, registries, orderings, supplements,
          )
          expect_value = None
          if registries.length() > 0 &&
            orderings.length() > 0 &&
            supplements.length() > 0 {
            return Some({
              registry: registries[0],
              ordering: orderings[0],
              supplement: supplements[0],
            })
          }
        }
        None => ()
      }
      if pdf_text_view_equals_ascii(token, "/Registry") {
        expect_value = Some(PdfTextCMapCIDSystemRegistry)
      } else if pdf_text_view_equals_ascii(token, "/Ordering") {
        expect_value = Some(PdfTextCMapCIDSystemOrdering)
      } else if pdf_text_view_equals_ascii(token, "/Supplement") {
        expect_value = Some(PdfTextCMapCIDSystemSupplement)
      }
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_usecmap(data : BytesView) -> PdfName? {
  let cursor = byte_cursor_of_view(data)
  let mut previous_name : PdfName? = None
  for line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(line)
    let tokens = pdf_split_whitespace_tokens(uncommented)
    for token in tokens {
      if pdf_text_view_equals_ascii(token, "usecmap") {
        match previous_name {
          Some(name) => return Some(name)
          None => ()
        }
      }
      previous_name = pdf_text_parse_cmap_name_token(token)
    }
  } nobreak {
    None
  }
}
