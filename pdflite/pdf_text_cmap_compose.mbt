///|
/// Returns `primary` when it is present, otherwise `fallback` — layers a cmap's
/// own fields over the values it inherits.
fn[T] pdf_option_or(primary : T?, fallback : T?) -> T? {
  match primary {
    Some(_) => primary
    None => fallback
  }
}

///|
fn pdf_text_tounicode_has_charcode(
  entries : ArrayView[(Int, @core.PdfBytes)],
  code : Int,
) -> Bool {
  for entry in entries {
    if entry.0 == code {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_compose_tounicode_entries(
  current : ArrayView[(Int, @core.PdfBytes)],
  inherited : ArrayView[(Int, @core.PdfBytes)],
) -> Array[(Int, @core.PdfBytes)] {
  let output : Array[(Int, @core.PdfBytes)] = Array::new(
    capacity=current.length() + inherited.length(),
  )
  let seen : @hashmap.HashMap[Int, Bool] = HashMap([])
  for entry in current {
    output.push(entry)
    seen[entry.0] = true
  }
  for entry in inherited {
    if !seen.contains(entry.0) {
      seen[entry.0] = true
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_text_compose_cid_entries(
  current : ArrayView[(Int, Int)],
  inherited : ArrayView[(Int, Int)],
) -> Array[(Int, Int)] {
  let output : Array[(Int, Int)] = Array::new(
    capacity=current.length() + inherited.length(),
  )
  let seen : @hashmap.HashMap[Int, Bool] = HashMap([])
  for entry in current {
    output.push(entry)
    seen[entry.0] = true
  }
  for entry in inherited {
    if !seen.contains(entry.0) {
      seen[entry.0] = true
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_text_compose_codespaces(
  current : ArrayView[PdfCMapCodeSpace],
  inherited : ArrayView[PdfCMapCodeSpace],
) -> Array[PdfCMapCodeSpace] {
  let output : Array[PdfCMapCodeSpace] = Array::new(
    capacity=current.length() + inherited.length(),
  )
  for entry in current {
    output.push(entry)
  }
  for entry in inherited {
    output.push(entry)
  }
  output
}

///|
fn pdf_text_compose_parsed_cmap(
  current : PdfParsedCMap,
  inherited : PdfParsedCMap,
) -> PdfParsedCMap {
  {
    map: pdf_text_compose_tounicode_entries(current.map, inherited.map),
    cid_map: pdf_text_compose_cid_entries(current.cid_map, inherited.cid_map),
    notdef_map: pdf_text_compose_cid_entries(
      current.notdef_map,
      inherited.notdef_map,
    ),
    codespaces: pdf_text_compose_codespaces(
      current.codespaces,
      inherited.codespaces,
    ),
    usecmap: pdf_option_or(current.usecmap, inherited.usecmap),
    wmode: pdf_option_or(current.wmode, inherited.wmode),
    cmap_name: pdf_option_or(current.cmap_name, inherited.cmap_name),
    cmap_type: pdf_option_or(current.cmap_type, inherited.cmap_type),
    cid_system_info: pdf_option_or(
      current.cid_system_info,
      inherited.cid_system_info,
    ),
  }
}
