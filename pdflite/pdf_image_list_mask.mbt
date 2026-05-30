///|
fn PdfDocument::pdf_image_indirect_mask_number(
  self : PdfDocument,
  image : @syntax.PdfObject,
  key : PdfName,
) -> Int? {
  match self.direct(image) {
    PdfDictionary(entries)
    | PdfStreamObject({ dictionary: PdfDictionary(entries), .. }) =>
      for entry in entries {
        if entry.0 == key {
          break match entry.1 {
            PdfIndirect(number) => Some(number)
            _ => None
          }
        }
      } nobreak {
        None
      }
    _ => None
  }
}

///|
fn PdfDocument::pdf_image_list_mask(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  page_number : Int,
  image : @syntax.PdfObject,
  inline : Bool,
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> (String, Int?) raise PdfError {
  match
    self.lookup_direct_or_else(
      pdf_image_image_mask_key(),
      pdf_image_im_key(),
      image,
    ) {
    Some(PdfBoolean(true)) => ("ImageMask", None)
    _ =>
      match self.lookup_direct(pdf_image_mask_key(), image) {
        Some(PdfStreamObject(_)) => {
          let number = self.pdf_image_indirect_mask_number(
            image,
            pdf_image_mask_key(),
          )
          match number {
            Some(number) =>
              self.pdf_image_collect_xobject(
                resources,
                page_number,
                pdf_image_name("/Mask"),
                PdfIndirect(number),
                inline,
                entries,
                form_numbers,
              )
            None => ()
          }
          ("ExplicitMask", number)
        }
        Some(_) => ("ColourKeyMask", None)
        None =>
          match self.lookup_direct(pdf_image_smask_key(), image) {
            Some(_) => {
              let number = self.pdf_image_indirect_mask_number(
                image,
                pdf_image_smask_key(),
              )
              match number {
                Some(number) =>
                  self.pdf_image_collect_xobject(
                    resources,
                    page_number,
                    pdf_image_name("/SMask"),
                    PdfIndirect(number),
                    inline,
                    entries,
                    form_numbers,
                  )
                None => ()
              }
              ("SMask", number)
            }
            None =>
              match self.lookup_direct(pdf_image_smask_in_data_key(), image) {
                Some(_) => ("SMaskInData", None)
                None => ("NoMask", None)
              }
          }
      }
  }
}
