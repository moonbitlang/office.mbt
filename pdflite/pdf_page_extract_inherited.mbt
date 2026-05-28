///|
fn pdf_page_inheritable_keys() -> Array[PdfName] {
  [
    pdf_page_mediabox_key(),
    pdf_page_cropbox_key(),
    pdf_page_rotate_key(),
    pdf_page_resources_key(),
  ]
}

///|
fn PdfDocument::pdf_page_preserve_materialized_inherited_entries(
  self : PdfDocument,
  source : PdfDocument,
  old_page_numbers : ArrayView[Int],
  new_page_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  for index in 0..<old_page_numbers.length() {
    let old_page = source.lookup_object_or_null(old_page_numbers[index])
    let new_page_number = new_page_numbers[index]
    let original = self.lookup_object_or_null(new_page_number)
    let mut updated = original
    for key in pdf_page_inheritable_keys() {
      match old_page.lookup_immediate(key) {
        Some(value) => updated = updated.add_dict_entry(key, value)
        None => ()
      }
    }
    if updated != original {
      self.add_object_given_number(new_page_number, updated)
    }
  }
}

///|
