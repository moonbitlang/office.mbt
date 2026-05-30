///|
/// Parse cpdf's optional-content group JSON representation.
pub fn pdf_ocg_read_json(
  json : Json,
) -> @ocg.PdfOptionalContent? raise PdfError {
  match json {
    Null => None
    Object(entries) if entries.length() == 3 => {
      let ocgs = pdf_ocg_read_json_field(
        entries, "OCGs", "ocg_read_json: malformed JSON top-level dictionary",
      )
      let default = pdf_ocg_read_json_field(
        entries, "Default", "ocg_read_json: malformed JSON top-level dictionary",
      )
      let configs = pdf_ocg_read_json_field(
        entries, "Configs", "ocg_read_json: malformed JSON top-level dictionary",
      )
      Some({
        ocgs: pdf_ocg_read_json_ocgs(ocgs),
        default_config: pdf_ocg_read_json_config(default),
        configs: pdf_ocg_read_json_configs(configs),
      })
    }
    Object(_) =>
      raise SoftError("ocg_read_json: malformed JSON top-level dictionary")
    _ => raise SoftError("ocg_read_json: malformed JSON top-level")
  }
}

///|
/// Return a copy with catalog `/OCProperties` replaced from cpdf OCG JSON.
pub fn PdfDocument::ocg_replace_json(
  self : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  match pdf_ocg_read_json(json) {
    None => self.copy()
    Some(content) => self.write_optional_content_groups(content)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_replace_json`.
pub fn pdf_ocg_replace_json(
  json : Json,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.ocg_replace_json(json)
}
