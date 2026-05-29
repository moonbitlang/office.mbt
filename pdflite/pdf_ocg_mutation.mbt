///|
/// Return a copy of the document with matching optional-content group names
/// replaced.
pub fn PdfDocument::ocg_rename(
  self : PdfDocument,
  old_name : PdfBytes,
  new_name : PdfBytes,
) -> PdfDocument {
  let pdf = self.copy()
  pdf.map_objects_in_place(fn(object) {
    match object {
      PdfDictionary(entries) =>
        match
          (
            pdf.lookup_direct(pdf_ocg_type_key(), object),
            pdf.lookup_direct(pdf_ocg_name_key(), object),
          ) {
          (Some(PdfNameObject(kind)), Some(PdfString(name))) =>
            if kind == pdf_ocg_ocg_name() && name == old_name {
              PdfDictionary(
                @syntax.dict_add_entries(
                  entries,
                  pdf_ocg_name_key(),
                  PdfString(new_name),
                ),
              )
            } else {
              object
            }
          _ => object
        }
      _ => object
    }
  })
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_rename`.
pub fn pdf_ocg_rename(
  old_name : PdfBytes,
  new_name : PdfBytes,
  document : PdfDocument,
) -> PdfDocument {
  document.ocg_rename(old_name, new_name)
}

///|
/// Return a copy of the document with every OCG listed in the default `/Order`.
///
/// Documents without optional-content properties, without `/OCGs`, or without a
/// default `/D` dictionary are returned unchanged.
pub fn PdfDocument::ocg_order_all(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_ocg_root()
  match self.lookup_direct(pdf_ocg_ocproperties_key(), root) {
    None => self.copy()
    Some(ocproperties) =>
      match
        (
          self.lookup_direct(pdf_ocg_ocgs_key(), ocproperties),
          self.lookup_direct(pdf_ocg_d_key(), ocproperties),
        ) {
        (Some(PdfArray(ocgs)), Some(PdfDictionary(_))) => {
          let pdf = self.copy()
          let default_config = self
            .lookup_direct(pdf_ocg_d_key(), ocproperties)
            .unwrap()
            .add_dict_entry(pdf_ocg_order_key(), PdfArray(ocgs.copy()))
          let new_ocproperties = ocproperties.add_dict_entry(
            pdf_ocg_d_key(),
            default_config,
          )
          let ocproperties_number = pdf.add_object(new_ocproperties)
          let new_root = pdf.add_object(
            root.add_dict_entry(
              pdf_ocg_ocproperties_key(),
              PdfIndirect(ocproperties_number),
            ),
          )
          pdf.set_root(new_root)
          pdf.set_trailer_dict(
            pdf
            .trailer_dict()
            .add_dict_entry(pdf_ocg_root_key(), PdfIndirect(new_root)),
          )
          pdf
        }
        _ => self.copy()
      }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_order_all`.
pub fn pdf_ocg_order_all(document : PdfDocument) -> PdfDocument raise PdfError {
  document.ocg_order_all()
}
