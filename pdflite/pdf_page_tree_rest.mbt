///|
fn pdf_page_is_reserved_key(key : @core.PdfName) -> Bool {
  key == pdf_page_type_key() ||
  key == pdf_page_parent_key() ||
  key == pdf_page_resources_key() ||
  key == pdf_page_mediabox_key() ||
  key == pdf_page_rotate_key() ||
  key == pdf_page_contents_key()
}

///|
fn pdf_page_rest_entries(
  rest : @syntax.PdfObject,
) -> Array[(@core.PdfName, @syntax.PdfObject)] raise @core.PdfError {
  match rest {
    PdfDictionary(entries) => {
      let output : Array[(@core.PdfName, @syntax.PdfObject)] = Array::new(
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
fn pdf_page_rest_object_from_page(
  page : @syntax.PdfObject,
) -> @syntax.PdfObject raise @core.PdfError {
  match page {
    PdfDictionary(entries) => {
      let rest : Array[(@core.PdfName, @syntax.PdfObject)] = Array::new(
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
