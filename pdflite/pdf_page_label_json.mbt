///|
fn pdf_page_label_json_integral_number(value : Double) -> Int raise PdfError {
  let integer = value.to_int()
  guard integer.to_double() == value else { raise NumberExpected }
  integer
}

///|
fn pdf_page_label_json_int(value : Json?) -> Int raise PdfError {
  match value {
    Some(Number(number, repr=_)) => pdf_page_label_json_integral_number(number)
    _ => raise BadText
  }
}

///|
fn pdf_page_label_json_string(value : Json?) -> String raise PdfError {
  match value {
    Some(String(text)) => text
    _ => raise BadText
  }
}

///|
fn pdf_page_label_json_prefix(value : Json?) -> PdfBytes? raise PdfError {
  match value {
    Some(Null) => None
    Some(String(text)) => Some(pdf_pdfdocstring_of_utf8(@utf8.encode(text)))
    _ => raise BadText
  }
}

///|
fn pdf_page_label_of_json(json : Json) -> @label.PdfPageLabel raise PdfError {
  match json {
    Object(entries) => {
      let style = @label.pdf_page_label_style_of_string(
        pdf_page_label_json_string(entries.get("labelstyle")),
      )
      {
        label_style: style,
        label_prefix: pdf_page_label_json_prefix(entries.get("labelprefix")),
        start_page: pdf_page_label_json_int(entries.get("startpage")),
        start_value: pdf_page_label_json_int(entries.get("startvalue")),
      }
    }
    _ => raise BadText
  }
}

///|
/// Add page labels from cpdf's JSON page-label array shape.
///
/// Each entry must contain `labelstyle`, `labelprefix`, `startpage`, and
/// `startvalue`. Prefix strings are interpreted as UTF-8 and encoded as compact
/// PDFDocStrings, matching cpdf's `add_page_labels_json`.
pub fn PdfDocument::add_page_labels_json(
  self : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  match json {
    Array(items) => {
      let labels : Array[@label.PdfPageLabel] = []
      for item in items {
        labels.push(pdf_page_label_of_json(item))
      }
      self.write_page_labels(labels)
    }
    _ => raise BadText
  }
}

///|
/// Compatibility wrapper for `PdfDocument::add_page_labels_json`.
pub fn pdf_add_page_labels_json(
  document : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  document.add_page_labels_json(json)
}
