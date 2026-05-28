///|
fn pdf_page_is_reserved_key(key : PdfName) -> Bool {
  key == pdf_page_type_key() ||
  key == pdf_page_parent_key() ||
  key == pdf_page_resources_key() ||
  key == pdf_page_mediabox_key() ||
  key == pdf_page_rotate_key() ||
  key == pdf_page_contents_key()
}

///|
fn pdf_page_rest_entries(
  rest : PdfObject,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match rest {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (key, _) = entry
        if !pdf_page_is_reserved_key(key) {
          output.push(entry)
        }
      }
      output
    }
    _ => raise DictionaryExpected
  }
}

///|
fn pdf_page_rest_object_from_page(page : PdfObject) -> PdfObject raise PdfError {
  match page {
    PdfDictionary(entries) => {
      let rest : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (key, _) = entry
        if !pdf_page_is_reserved_key(key) {
          rest.push(entry)
        }
      }
      PdfDictionary(rest)
    }
    _ => raise DictionaryExpected
  }
}
