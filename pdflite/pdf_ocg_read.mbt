///|
/// Read catalog `/OCProperties` from the document.
///
/// Returns `None` when the catalog has no optional-content properties. When
/// properties are present, OCG entries are returned with their indirect object
/// numbers so callers can preserve or renumber references before writing.
pub fn PdfDocument::read_optional_content_groups(
  self : PdfDocument,
) -> @ocg.PdfOptionalContent? raise PdfError {
  let root = self.pdf_ocg_root()
  match self.lookup_direct(pdf_ocg_ocproperties_key(), root) {
    None => None
    Some(ocproperties) => {
      let ocgs = match self.lookup_direct(pdf_ocg_ocgs_key(), ocproperties) {
        Some(PdfArray(indirects)) => {
          let output : Array[(Int, @ocg.PdfOcg)] = []
          for indirect in indirects {
            match indirect {
              PdfIndirect(number) =>
                output.push((number, self.pdf_ocg_read_individual(indirect)))
              _ => ()
            }
          }
          output
        }
        _ => []
      }
      let default_config = match
        self.lookup_direct(pdf_ocg_d_key(), ocproperties) {
        Some(config) => self.pdf_ocg_read_config(config)
        None => raise DictionaryKeyNotFound(pdf_ocg_d_key())
      }
      let configs = match
        self.lookup_direct(pdf_ocg_configs_key(), ocproperties) {
        Some(PdfArray(configs)) =>
          [
            for config in configs => self.pdf_ocg_read_config(config)
          ]
        _ => []
      }
      Some({ ocgs, default_config, configs })
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::read_optional_content_groups`.
pub fn pdf_read_ocg(
  document : PdfDocument,
) -> @ocg.PdfOptionalContent? raise PdfError {
  document.read_optional_content_groups()
}

///|
/// Return the raw PDF string names of catalog optional-content groups.
///
/// This mirrors cpdf's `ocg_get_list`: missing optional-content metadata yields
/// an empty list, and malformed individual group entries are skipped.
pub fn PdfDocument::ocg_get_list(
  self : PdfDocument,
) -> Array[PdfBytes] raise PdfError {
  let root = self.pdf_ocg_root()
  match self.lookup_direct(pdf_ocg_ocproperties_key(), root) {
    None => []
    Some(ocproperties) =>
      match self.lookup_direct(pdf_ocg_ocgs_key(), ocproperties) {
        Some(PdfArray(indirects)) => {
          let names : Array[PdfBytes] = []
          for indirect in indirects {
            match indirect {
              PdfIndirect(_) =>
                match self.lookup_direct(pdf_ocg_name_key(), indirect) {
                  Some(PdfString(name)) => names.push(name)
                  _ => ()
                }
              _ => ()
            }
          }
          names
        }
        _ => []
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_get_list`.
pub fn pdf_ocg_get_list(
  document : PdfDocument,
) -> Array[PdfBytes] raise PdfError {
  document.ocg_get_list()
}
