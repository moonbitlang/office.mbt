///|
fn PdfFont::pdf_text_tounicode(
  self : PdfFont,
) -> Array[(Int32, @core.PdfBytes)]? {
  match self {
    PdfFontSimple(
      { fontdescriptor: Some({ tounicode: Some(tounicode), .. }), .. },
    ) => Some(tounicode)
    PdfFontCIDKeyed(
      {
        composite: {
          cid_fontdescriptor: { tounicode: Some(tounicode), .. },
          ..
        },
        ..
      },
    ) => Some(tounicode)
    _ => None
  }
}

///|
fn pdf_text_lookup_tounicode(
  tounicode : ArrayView[(Int32, @core.PdfBytes)],
  code : Int32,
) -> @core.PdfBytes? {
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
  bytes : @core.PdfBytes,
  code : Int32,
) -> Array[Int32] {
  try pdf_codepoints_of_utf16be(bytes) catch {
    _ => [code]
  } noraise {
    codepoints => codepoints
  }
}

///|
fn pdf_text_lookup_tounicode_codepoints(
  tounicode : ArrayView[(Int32, @core.PdfBytes)],
  code : Int32,
) -> Array[Int32]? {
  match pdf_text_lookup_tounicode(tounicode, code) {
    Some(bytes) =>
      Some(pdf_text_codepoints_of_tounicode_bytes_or_charcode(bytes, code))
    None => None
  }
}

///|
priv struct PdfTextExternalCMapLookup {
  cid_map : @hashmap.HashMap[Int32, Int32]
  notdef_map : @hashmap.HashMap[Int32, Int32]
  map : @hashmap.HashMap[Int32, Array[Int32]]
}

///|
fn pdf_text_cmap_cid_lookup_map(
  entries : ArrayView[(Int32, Int32)],
) -> @hashmap.HashMap[Int32, Int32] {
  let values : @hashmap.HashMap[Int32, Int32] = HashMap([])
  for entry in entries {
    if !values.contains(entry.0) {
      values[entry.0] = entry.1
    }
  }
  values
}

///|
fn pdf_text_tounicode_codepoints_lookup_map(
  entries : ArrayView[(Int32, @core.PdfBytes)],
) -> @hashmap.HashMap[Int32, Array[Int32]] {
  let values : @hashmap.HashMap[Int32, Array[Int32]] = HashMap([])
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
  tounicode : ArrayView[(Int32, @core.PdfBytes)],
  codepoint : Int32,
  shadow_first : ArrayView[(Int32, Int32)],
  shadow_second : ArrayView[(Int32, Int32)],
) -> Int32? {
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
