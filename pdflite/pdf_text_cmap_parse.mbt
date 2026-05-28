///|
/// Parse raw CMap or ToUnicode bytes into mapping tables and metadata.
///
/// The parser accepts common CMap sections such as code-space ranges,
/// `bfchar`/`bfrange`, CID ranges, notdef ranges, `/UseCMap`, `/WMode`, and
/// CID-system metadata. Unrecognized or malformed sections are skipped rather
/// than causing a document-level failure.
pub fn pdf_parse_cmap_data(data : BytesView) -> PdfParsedCMap {
  {
    map: match pdf_text_parse_tounicode(data) {
      Some(entries) => entries
      None => []
    },
    cid_map: match pdf_text_parse_cmap_cids(data) {
      Some(entries) => entries
      None => []
    },
    notdef_map: match pdf_text_parse_cmap_notdefs(data) {
      Some(entries) => entries
      None => []
    },
    codespaces: match pdf_text_parse_cmap_codespaces(data) {
      Some(entries) => entries
      None => []
    },
    usecmap: pdf_text_parse_cmap_usecmap(data),
    wmode: pdf_text_parse_cmap_wmode(data),
    cmap_name: pdf_text_parse_cmap_name_after_token(data, "/CMapName"),
    cmap_type: pdf_text_parse_cmap_int_after_token(data, "/CMapType"),
    cid_system_info: pdf_text_parse_cmap_cid_system_info(data),
  }
}

///|
/// Decode and parse a CMap stream object in this document.
///
/// The stream is decoded through its first filter, stream-dictionary metadata
/// is merged with parsed metadata, and indirect `/UseCMap` bases are composed
/// with cycle protection. Malformed or non-stream inputs raise `PdfError`.
pub fn PdfDocument::parse_cmap(
  self : PdfDocument,
  cmap : PdfObject,
) -> PdfParsedCMap raise PdfError {
  self.parse_cmap_with_seen(cmap, HashMap([]))
}

///|
/// Compatibility wrapper for `PdfDocument::parse_cmap`.
pub fn pdf_parse_cmap(
  document : PdfDocument,
  cmap : PdfObject,
) -> PdfParsedCMap raise PdfError {
  document.parse_cmap(cmap)
}
