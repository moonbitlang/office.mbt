///|
fn pdf_text_predefined_rksj_single_byte_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x7F {
    Some(code)
  } else if code >= 0xA1 && code <= 0xDF {
    Some(0xFF61 + code - 0xA1)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_rksj_single_byte_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x7F {
    Some(codepoint)
  } else if codepoint >= 0xFF61 && codepoint <= 0xFF9F {
    Some(0xA1 + codepoint - 0xFF61)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_pair_table_lookup(
  table : Array[(Int, Int)],
  key : Int,
) -> Int? {
  let mut low = 0
  let mut high = table.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = table[mid]
    if key < entry.0 {
      high = mid
    } else if key > entry.0 {
      low = mid + 1
    } else {
      return Some(entry.1)
    }
  }
  None
}

///|
fn pdf_text_predefined_pair_codepoints_table_lookup(
  table : Array[(Int, Array[Int])],
  key : Int,
) -> Array[Int]? {
  let mut low = 0
  let mut high = table.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = table[mid]
    if key < entry.0 {
      high = mid
    } else if key > entry.0 {
      low = mid + 1
    } else {
      return Some(entry.1.copy())
    }
  }
  None
}

///|
fn pdf_text_predefined_cid_range_lookup(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Int? {
  let mut low = 0
  let mut high = ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = ranges[mid]
    if code < entry.0 {
      high = mid
    } else if code > entry.1 {
      low = mid + 1
    } else {
      return Some(entry.2 + code - entry.0)
    }
  }
  None
}

///|
fn pdf_text_predefined_cid_range_lookup_unsigned(
  ranges : ArrayView[(Int, Int, Int)],
  code : Int,
) -> Int? {
  let target = code.reinterpret_as_uint()
  let mut low = 0
  let mut high = ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = ranges[mid]
    if target < entry.0.reinterpret_as_uint() {
      high = mid
    } else if target > entry.1.reinterpret_as_uint() {
      low = mid + 1
    } else {
      return Some(entry.2 + code - entry.0)
    }
  }
  None
}

///|
fn pdf_text_lower_packed_charcode(current : Int?, candidate : Int) -> Int? {
  match current {
    Some(value) =>
      if candidate.reinterpret_as_uint() < value.reinterpret_as_uint() {
        Some(candidate)
      } else {
        current
      }
    None => Some(candidate)
  }
}

///|
fn pdf_text_lower_optional_packed_charcode(
  current : Int?,
  candidate : Int?,
) -> Int? {
  match candidate {
    Some(code) => pdf_text_lower_packed_charcode(current, code)
    None => current
  }
}

///|
fn pdf_text_predefined_cid_range_charcode_of_cid(
  ranges : ArrayView[(Int, Int, Int)],
  cid : Int,
) -> Int? {
  let mut found : Int? = None
  for range in ranges {
    let first_cid = range.2
    let last_cid = range.2 + range.1 - range.0
    if cid >= first_cid && cid <= last_cid {
      found = pdf_text_lower_packed_charcode(found, range.0 + cid - first_cid)
    }
  }
  found
}

///|
fn pdf_text_predefined_unicode_table_charcode(
  unicode_table : ArrayView[Int],
  charcode_ranges : ArrayView[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  guard codepoint != 0 else { return None }
  let mut found : Int? = None
  for cid, candidate in unicode_table {
    if candidate == codepoint {
      match
        pdf_text_predefined_cid_range_charcode_of_cid(charcode_ranges, cid) {
        Some(code) => found = pdf_text_lower_packed_charcode(found, code)
        None => ()
      }
    }
  }
  found
}

///|
fn pdf_text_predefined_codepoint_range_charcode(
  codepoint_ranges : ArrayView[(Int, Int, Int)],
  charcode_ranges : ArrayView[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  let mut found : Int? = None
  for range in codepoint_ranges {
    let first_codepoint = range.2
    let last_codepoint = range.2 + range.1 - range.0
    if codepoint >= first_codepoint && codepoint <= last_codepoint {
      let cid = range.0 + codepoint - first_codepoint
      match
        pdf_text_predefined_cid_range_charcode_of_cid(charcode_ranges, cid) {
        Some(code) => found = pdf_text_lower_packed_charcode(found, code)
        None => ()
      }
    }
  }
  found
}

///|
fn pdf_text_predefined_sequence_table_charcode(
  sequence_table : ArrayView[(Int, Array[Int])],
  charcode_ranges : ArrayView[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  let mut found : Int? = None
  for entry in sequence_table {
    match entry.1 {
      [candidate] if candidate == codepoint =>
        match
          pdf_text_predefined_cid_range_charcode_of_cid(
            charcode_ranges,
            entry.0,
          ) {
          Some(code) => found = pdf_text_lower_packed_charcode(found, code)
          None => ()
        }
      _ => ()
    }
  }
  found
}
