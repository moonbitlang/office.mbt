///|
fn PdfDocument::pdf_bookmark_import_target_object(
  self : PdfDocument,
  page_number : Int,
  object : PdfObject,
) -> @destination.PdfDestination raise PdfError {
  match object {
    PdfArray([PdfInteger(_), .. rest]) =>
      match self.page_object_number(page_number) {
        Some(page_object_number) =>
          self.read_destination(
            PdfArray([PdfIndirect(page_object_number), ..rest]),
          )
        None => raise SoftError("bookmark_of_data: page obj num not found")
      }
    PdfNull => DestNull
    PdfString(name) => DestString(name)
    _ => DestAction(object)
  }
}

///|
fn PdfDocument::pdf_bookmark_import_target(
  self : PdfDocument,
  page_number : Int,
  destination : PdfBytes?,
) -> @destination.PdfDestination raise PdfError {
  match destination {
    Some(data) =>
      self.pdf_bookmark_import_target_object(
        page_number,
        pdf_parse_object_from_view(data),
      )
    None => self.target_of_page_number(page_number)
  }
}

///|
fn PdfDocument::pdf_bookmark_import_bookmark(
  self : PdfDocument,
  level : Int,
  title : BytesView,
  page_number : Int,
  is_open : Bool,
  destination : PdfBytes?,
) -> PdfBookmark raise PdfError {
  {
    level,
    text: pdf_pdfdocstring_of_utf8(pdf_bookmark_import_fixup_text(title)),
    target: self.pdf_bookmark_import_target(page_number, destination),
    is_open,
    colour: pdf_bookmark_black,
    flags: 0,
  }
}
