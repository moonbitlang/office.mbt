///|
fn PdfDocument::pdf_page_resource_entry_count(
  self : PdfDocument,
  pages : ArrayView[@page.PdfPage],
) -> Int {
  let mut count = 0
  for resource_key in pdf_page_resource_keys() {
    for page in pages {
      match self.lookup_direct(resource_key, page.resources) {
        Some(PdfDictionary(entries)) => count += entries.length()
        _ => ()
      }
    }
  }
  count
}

///|
fn PdfDocument::pdf_page_renumber_resource_changes(
  self : PdfDocument,
  pages : ArrayView[@page.PdfPage],
) -> Array[(@core.PdfName, Int, @core.PdfName, @core.PdfName)] {
  let changes : Array[(@core.PdfName, Int, @core.PdfName, @core.PdfName)] = Array::new(
    capacity=self.pdf_page_resource_entry_count(pages),
  )
  let mut serial = 1
  for resource_key in pdf_page_resource_keys() {
    for page_index in 0..<pages.length() {
      match self.lookup_direct(resource_key, pages[page_index].resources) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            let (old_name, _) = entry
            changes.push(
              (
                resource_key,
                page_index + 1,
                old_name,
                pdf_page_name("/r" + serial.to_string()),
              ),
            )
            serial += 1
          }
        _ => ()
      }
    }
  }
  changes
}

///|
fn pdf_page_renumber_lookup_optional(
  changes : ArrayView[(@core.PdfName, Int, @core.PdfName, @core.PdfName)],
  resource_key : @core.PdfName,
  page_number : Int,
  old_name : @core.PdfName,
) -> @core.PdfName? {
  for change in changes {
    let (change_key, change_page, change_old_name, new_name) = change
    if change_key == resource_key &&
      change_page == page_number &&
      change_old_name == old_name {
      break Some(new_name)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_page_renumber_lookup(
  changes : ArrayView[(@core.PdfName, Int, @core.PdfName, @core.PdfName)],
  resource_key : @core.PdfName,
  page_number : Int,
  old_name : @core.PdfName,
) -> @core.PdfName raise @core.PdfError {
  match
    pdf_page_renumber_lookup_optional(
      changes, resource_key, page_number, old_name,
    ) {
    Some(new_name) => new_name
    None => raise DictionaryKeyNotFound(old_name)
  }
}
