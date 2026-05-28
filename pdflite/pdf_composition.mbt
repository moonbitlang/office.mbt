///|
fn pdf_composition_entry(
  label : String,
  bytes : Int,
  file_size : Int,
) -> PdfCompositionEntry {
  { label, bytes, percent: bytes.to_double() / file_size.to_double() * 100.0 }
}

///|
/// Return cpdf-style composition buckets for a document.
///
/// The result order is stable: images, fonts, content streams, structure info,
/// attached files, xref table, piece info, then unclassified bytes.
pub fn PdfDocument::composition(
  self : PdfDocument,
  file_size : Int,
) -> Array[PdfCompositionEntry] raise PdfError {
  if file_size <= 0 {
    raise BadNumberArgument("file_size must be positive")
  }
  let (
    image_numbers,
    font_numbers,
    content_numbers,
    structure_numbers,
    piece_info_numbers,
  ) = self.pdf_composition_find_objects()
  let images = self.pdf_composition_compressed_size(image_numbers)
  let fonts = self.pdf_composition_compressed_size(font_numbers)
  let content_streams = self.pdf_composition_compressed_size(content_numbers)
  let structure_info = self.pdf_composition_compressed_size(structure_numbers)
  let attached_files = self.size_attached_files()
  let xref_table = self.pdf_composition_xref_table_size()
  let piece_info = self.pdf_composition_compressed_size(piece_info_numbers)
  let classified = images +
    fonts +
    content_streams +
    structure_info +
    attached_files +
    xref_table +
    piece_info
  [
    pdf_composition_entry("Images", images, file_size),
    pdf_composition_entry("Fonts", fonts, file_size),
    pdf_composition_entry("Content streams", content_streams, file_size),
    pdf_composition_entry("Structure Info", structure_info, file_size),
    pdf_composition_entry("Attached Files", attached_files, file_size),
    pdf_composition_entry("XRef Table", xref_table, file_size),
    pdf_composition_entry("Piece Info", piece_info, file_size),
    pdf_composition_entry("Unclassified", file_size - classified, file_size),
  ]
}

///|
/// Convert a composition entry to the cpdf JSON row shape:
/// `[label, byte_count, percent]`.
pub fn PdfCompositionEntry::to_json(self : PdfCompositionEntry) -> Json {
  Json::array([
    Json::string(self.label),
    pdf_util_json_number(self.bytes),
    Json::number(self.percent),
  ])
}

///|
/// Return the document composition in cpdf JSON row format.
pub fn PdfDocument::composition_json(
  self : PdfDocument,
  file_size : Int,
) -> Json raise PdfError {
  let entries = self.composition(file_size)
  let values : Array[Json] = Array::new(capacity=entries.length())
  for entry in entries {
    values.push(entry.to_json())
  }
  Json::array(values)
}

///|
/// Return the document composition serialized as UTF-8 JSON bytes.
pub fn PdfDocument::composition_json_blob(
  self : PdfDocument,
  file_size : Int,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.composition_json(file_size).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::composition`.
pub fn pdf_composition(
  document : PdfDocument,
  file_size : Int,
) -> Array[PdfCompositionEntry] raise PdfError {
  document.composition(file_size)
}

///|
/// Compatibility wrapper for `PdfDocument::composition_json_blob`.
pub fn pdf_show_composition_json_blob(
  file_size : Int,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.composition_json_blob(file_size)
}

///|
/// Return the bytes cpdf's `show_composition` would print.
pub fn pdf_show_composition(
  file_size : Int,
  json : Bool,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  if json {
    pdf_composition_bytes_with_newline(
      document.composition_json_blob(file_size),
    )
  } else {
    document.composition_text(file_size)
  }
}
