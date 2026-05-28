///|
/// Copy the trailer `/ID` from `source` onto this document.
///
/// The original document is left unchanged. When `keep_version` is false, PDF
/// 1.x outputs are bumped to at least 1.1, matching cpdf.
pub fn PdfDocument::copy_id_from(
  self : PdfDocument,
  source : PdfDocument,
  keep_version? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  match source.lookup_direct(pdf_metadata_id(), source.trailer_dict()) {
    Some(id) => {
      document.set_trailer_dict(
        document.trailer_dict().add_dict_entry(pdf_metadata_id(), id),
      )
      document.pdf_metadata_bump_minor(1, keep_version)
      document
    }
    None => document
  }
}

///|
/// Set or replace one `/Info` dictionary entry.
pub fn PdfDocument::set_info_entry(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  version : Int,
  keep_version? : Bool = false,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = if xmp_just_set {
    self
  } else {
    let document = self.copy()
    let info = match
      document.lookup_direct(pdf_metadata_info(), document.trailer_dict()) {
      Some(dictionary) => dictionary
      None => PdfDictionary([])
    }
    let info_number = document.add_object(info.add_dict_entry(key, value))
    document.set_trailer_dict(
      document
      .trailer_dict()
      .add_dict_entry(pdf_metadata_info(), PdfIndirect(info_number)),
    )
    document.pdf_metadata_bump_minor(version, keep_version)
    document
  }
  if !xmp_also {
    document
  } else {
    match document.metadata() {
      None => document
      Some(metadata) => {
        let (changes, replacement) = pdf_metadata_info_xmp_changes(key, value)
        let mut updated = metadata
        for change in changes {
          updated = pdf_metadata_rewrite_xmp_field(
            updated,
            change.0,
            pdf_metadata_namespace_fallback_prefix(change.0),
            change.1,
            replacement,
          )
        }
        document.set_metadata_from_bytes(updated, keep_version=true)
      }
    }
  }
}

///|
/// Set or replace one `/Info` entry from cpdf's string-key tuple form.
pub fn PdfDocument::set_info_entry_string(
  self : PdfDocument,
  entry : (String, PdfObject, Int),
  keep_version? : Bool = false,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  self.set_info_entry(
    pdf_metadata_source_key_name(entry.0),
    entry.1,
    entry.2,
    keep_version~,
    xmp_also~,
    xmp_just_set~,
  )
}

///|
/// Return one `/Info` dictionary entry as a UTF-8 string.
pub fn PdfDocument::info_utf8(self : PdfDocument, key : PdfName) -> String {
  let info = match
    self.lookup_direct(pdf_metadata_info(), self.trailer_dict()) {
    Some(dictionary) => dictionary
    None => PdfDictionary([])
  }
  match self.lookup_direct(key, info) {
    Some(PdfString(bytes)) =>
      @utf8.decode(pdf_utf8_of_pdfdocstring(bytes)) catch {
        _ => ""
      }
    Some(PdfBoolean(value)) => pdf_metadata_bool_string(value)
    _ => if key == pdf_metadata_trapped() { "False" } else { "" }
  }
}

///|
/// Return one cpdf-style slash-prefixed string-key `/Info` entry as UTF-8.
pub fn PdfDocument::info_utf8_string(
  self : PdfDocument,
  key : String,
) -> String {
  self.info_utf8(pdf_metadata_source_key_name(key))
}
