///|
/// Return a copy of the document with catalog `/OCProperties` removed.
///
/// The original document is not mutated; the returned document receives a new
/// root object and trailer root reference.
pub fn PdfDocument::remove_optional_content_groups(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_ocg_root()
  let pdf = self.copy()
  let root_without_ocproperties = root.remove_dict_entry(
    pdf_ocg_ocproperties_key(),
  )
  let new_root = pdf.add_object(root_without_ocproperties)
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf.trailer_dict().add_dict_entry(pdf_ocg_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::remove_optional_content_groups`.
pub fn pdf_remove_ocg(document : PdfDocument) -> PdfDocument raise PdfError {
  document.remove_optional_content_groups()
}

///|
/// Return a copy of the document with catalog `/OCProperties` replaced.
///
/// OCG dictionaries are written using the object numbers stored in
/// `optional_content.ocgs`. Configuration dictionaries are added as new
/// objects, and the original document is left unchanged.
pub fn PdfDocument::write_optional_content_groups(
  self : PdfDocument,
  optional_content : @ocg.PdfOptionalContent,
) -> PdfDocument raise PdfError {
  let root = self.pdf_ocg_root()
  let pdf = self.copy()
  let original_max_object_number = pdf.objects.max_object_number()
  let mut max_ocg_number = original_max_object_number
  for entry in optional_content.ocgs {
    if entry.0 > max_ocg_number {
      max_ocg_number = entry.0
    }
  }
  if max_ocg_number > original_max_object_number {
    pdf.add_object_given_number(max_ocg_number, PdfNull)
  }
  for entry in optional_content.ocgs {
    let (number, ocg) = entry
    pdf.add_object_given_number(number, pdf.pdf_ocg_write_ocg(ocg))
  }
  let ocg_array_number = pdf.add_object(
    PdfArray([ for entry in optional_content.ocgs => PdfIndirect(entry.0) ]),
  )
  let default_number = pdf.pdf_ocg_write_config(optional_content.default_config)
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_ocg_ocgs_key(), PdfIndirect(ocg_array_number)),
    (pdf_ocg_d_key(), PdfIndirect(default_number)),
  ]
  if optional_content.configs.length() > 0 {
    let configs_number = pdf.add_object(
      PdfArray(
        [
          for config in optional_content.configs => {
            PdfIndirect(pdf.pdf_ocg_write_config(config))
          }
        ],
      ),
    )
    entries.push((pdf_ocg_configs_key(), PdfIndirect(configs_number)))
  }
  let ocproperties_number = pdf.add_object(PdfDictionary(entries))
  let new_root = pdf.add_object(
    root.add_dict_entry(
      pdf_ocg_ocproperties_key(),
      PdfIndirect(ocproperties_number),
    ),
  )
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf.trailer_dict().add_dict_entry(pdf_ocg_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::write_optional_content_groups`.
pub fn pdf_write_ocg(
  document : PdfDocument,
  optional_content : @ocg.PdfOptionalContent,
) -> PdfDocument raise PdfError {
  document.write_optional_content_groups(optional_content)
}
