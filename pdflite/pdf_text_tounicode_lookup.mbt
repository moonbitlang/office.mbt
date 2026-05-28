///|
fn PdfFont::pdf_text_tounicode(self : PdfFont) -> Array[(Int, PdfBytes)]? {
  match self {
    PdfFontSimple(
      { fontdescriptor: Some({ tounicode: Some(tounicode), .. }), .. }
    ) => Some(tounicode)
    PdfFontCIDKeyed(
      {
        composite: {
          cid_fontdescriptor: { tounicode: Some(tounicode), .. },
          ..,
        },
        ..,
      }
    ) => Some(tounicode)
    _ => None
  }
}

///|
fn pdf_text_lookup_tounicode(
  tounicode : ArrayView[(Int, PdfBytes)],
  code : Int,
) -> PdfBytes? {
  for entry in tounicode {
    if entry.0 == code {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_codepoints_of_tounicode_bytes_or_charcode(
  bytes : PdfBytes,
  code : Int,
) -> Array[Int] {
  try pdf_codepoints_of_utf16be(bytes) catch {
    _ => [code]
  } noraise {
    codepoints => codepoints
  }
}

///|
fn pdf_text_lookup_tounicode_codepoints(
  tounicode : ArrayView[(Int, PdfBytes)],
  code : Int,
) -> Array[Int]? {
  match pdf_text_lookup_tounicode(tounicode, code) {
    Some(bytes) =>
      Some(pdf_text_codepoints_of_tounicode_bytes_or_charcode(bytes, code))
    None => None
  }
}

///|
priv struct PdfTextExternalCMapLookup {
  cid_map : @hashmap.HashMap[Int, Int]
  notdef_map : @hashmap.HashMap[Int, Int]
  map : @hashmap.HashMap[Int, Array[Int]]
}

///|
fn pdf_text_cmap_cid_lookup_map(
  entries : ArrayView[(Int, Int)],
) -> @hashmap.HashMap[Int, Int] {
  let values : @hashmap.HashMap[Int, Int] = HashMap([])
  for entry in entries {
    if !values.contains(entry.0) {
      values[entry.0] = entry.1
    }
  }
  values
}

///|
fn pdf_text_tounicode_codepoints_lookup_map(
  entries : ArrayView[(Int, PdfBytes)],
) -> @hashmap.HashMap[Int, Array[Int]] {
  let values : @hashmap.HashMap[Int, Array[Int]] = HashMap([])
  for entry in entries {
    if !values.contains(entry.0) {
      values[entry.0] = pdf_text_codepoints_of_tounicode_bytes_or_charcode(
        entry.1,
        entry.0,
      )
    }
  }
  values
}

///|
fn pdf_text_external_cmap_lookup(
  parsed : PdfParsedCMap,
) -> PdfTextExternalCMapLookup {
  {
    cid_map: pdf_text_cmap_cid_lookup_map(parsed.cid_map),
    notdef_map: pdf_text_cmap_cid_lookup_map(parsed.notdef_map),
    map: pdf_text_tounicode_codepoints_lookup_map(parsed.map),
  }
}

///|
fn pdf_text_reverse_lookup_tounicode_charcode(
  tounicode : ArrayView[(Int, PdfBytes)],
  codepoint : Int,
  shadow_first : ArrayView[(Int, Int)],
  shadow_second : ArrayView[(Int, Int)],
) -> Int? {
  for entry in tounicode {
    try pdf_codepoints_of_utf16be(entry.1) catch {
      _ => ()
    } noraise {
      [single] if single == codepoint &&
        !pdf_text_cmap_has_charcode_in_any(shadow_first, shadow_second, entry.0) =>
        break Some(entry.0)
      _ => ()
    }
  } nobreak {
    None
  }
}
