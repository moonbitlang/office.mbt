///|
fn pdf_font_name_segments(font_name : String) -> Array[String] {
  let segments : Array[String] = []
  let mut start = 0
  for index in 0..<font_name.length() {
    if font_name.at(index).to_int() == 47 {
      if index > start {
        segments.push(font_name[start:index].to_owned())
      }
      start = index + 1
    }
  }
  if start < font_name.length() {
    segments.push(font_name[start:].to_owned())
  }
  segments
}

///|
fn pdf_font_segment_name(segment : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode("/" + segment))
}

///|
/// Resolve a cpdf font name path on a page.
///
/// `font_name` is the name shown by `list_fonts`, such as `/F1` for a page font
/// or `/Fm/FX` for a font inside a Form XObject. Valid pages whose path is not
/// found return `PdfNull`.
pub fn PdfDocument::font_from_name(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> @syntax.PdfObject raise @core.PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    [page_number],
    pages.length(),
    "font_from_name",
  )
  let segments = pdf_font_name_segments(font_name)
  if segments.length() == 0 {
    PdfNull
  } else {
    let mut resources = pages[page_number - 1].resources
    let mut found = @syntax.PdfNull
    let mut failed = false
    for index, segment in segments {
      if !failed {
        let key = pdf_font_segment_name(segment)
        if index == segments.length() - 1 {
          match self.lookup_direct(pdf_page_font_resource_name, resources) {
            Some(fonts) =>
              match self.lookup_direct(key, fonts) {
                Some(font) => found = font
                None => failed = true
              }
            None => failed = true
          }
        } else {
          match self.lookup_direct(pdf_page_xobject_key(), resources) {
            Some(xobjects) =>
              match self.lookup_direct(key, xobjects) {
                Some(xobject) =>
                  match self.lookup_direct(pdf_page_resources_key(), xobject) {
                    Some(next_resources) => resources = next_resources
                    None => failed = true
                  }
                None => failed = true
              }
            None => failed = true
          }
        }
      }
    }
    if failed {
      PdfNull
    } else {
      found
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::font_from_name`.
pub fn pdf_font_from_name(
  document : PdfDocument,
  font_name : String,
  page_number : Int,
) -> @syntax.PdfObject raise @core.PdfError {
  document.font_from_name(font_name, page_number)
}
