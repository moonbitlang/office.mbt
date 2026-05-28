///|
/// Build the cpdftype element stream for a table of contents.
///
/// `page_width` and `margin` are the already-resolved first-page dimensions
/// from cpdftoc's caller. Actual page typesetting and insertion remain a
/// separate step.
pub fn PdfDocument::toc_type_elements(
  self : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  dotleader : Bool,
  process_struct_tree : Bool,
  labels : ArrayView[PdfPageLabel],
  bookmarks : ArrayView[PdfBookmark],
  page_width : Double,
  margin : Double,
) -> Array[PdfTypeElement] raise PdfError {
  let title_elements = pdf_toc_title_elements(
    fontpack, font_size, title, process_struct_tree,
  )
  let body : Array[PdfTypeElement] = []
  pdf_toc_append_elements(body, title_elements)
  for bookmark in bookmarks {
    pdf_toc_append_elements(
      body,
      self.pdf_toc_bookmark_elements(
        fontpack, font_size, labels, page_width, margin, dotleader, process_struct_tree,
        bookmark,
      ),
    )
  }
  let output : Array[PdfTypeElement] = [
    pdf_toc_first_font(body),
    PdfTypeBeginDocument,
  ]
  pdf_toc_append_elements(output, body)
  output
}

///|
/// Compatibility wrapper for `PdfDocument::toc_type_elements`.
pub fn pdf_toc_type_elements(
  document : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  dotleader : Bool,
  process_struct_tree : Bool,
  labels : ArrayView[PdfPageLabel],
  bookmarks : ArrayView[PdfBookmark],
  page_width : Double,
  margin : Double,
) -> Array[PdfTypeElement] raise PdfError {
  document.toc_type_elements(
    fontpack, font_size, title, dotleader, process_struct_tree, labels, bookmarks,
    page_width, margin,
  )
}

///|
/// Typeset a TOC element stream into pages using cpdftoc's first-page geometry.
///
/// The first page's `/MediaBox` defines the paper size and base margin, while an
/// inherited `/CropBox`, when present, narrows the content width, offsets the
/// margins, and is copied onto the generated TOC pages. This helper does not
/// insert the pages into the source document.
pub fn PdfDocument::toc_typeset_pages(
  self : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  dotleader : Bool,
  process_struct_tree : Bool,
  labels : ArrayView[PdfPageLabel],
  bookmarks : ArrayView[PdfBookmark],
) -> PdfTypeTypesetResult raise PdfError {
  let source_pages = self.pages_of_pagetree()
  guard source_pages.length() > 0 else {
    raise SoftError("toc_typeset_pages: no pages")
  }
  let first_page = source_pages[0]
  let media = self.parse_rectangle(first_page.mediabox)
  let media_width = media.max_x - media.min_x
  let media_height = media.max_y - media.min_y
  let paper = paper_size_make(PdfPoint, media_width, media_height)
  let margin = double_min(media_width, media_height) * 0.1
  let cropbox = match
    self.lookup_direct(pdf_page_cropbox_key(), first_page.rest) {
    Some(raw_cropbox) => Some(self.parse_rectangle(raw_cropbox))
    None => None
  }
  let page_width = match cropbox {
    Some(crop) => crop.max_x - crop.min_x
    None => media_width
  }
  let (left_margin, right_margin, bottom_margin, top_margin) = match cropbox {
    Some(crop) =>
      (
        crop.min_x + margin,
        media.max_x - crop.max_x + margin,
        crop.min_y + margin,
        media.max_y - crop.max_y + margin,
      )
    None => (margin, margin, margin, margin)
  }
  let elements = self.toc_type_elements(
    fontpack, font_size, title, dotleader, process_struct_tree, labels, bookmarks,
    page_width, margin,
  )
  let result = self.pdf_type_typeset(
    process_struct_tree, left_margin, right_margin, top_margin, bottom_margin, paper,
    elements,
  )
  let cropbox_object = match cropbox {
    Some(crop) => Some(pdf_toc_rectangle_object(crop))
    None => None
  }
  { ..result, pages: pdf_toc_cropbox_pages(result.pages, cropbox_object) }
}

///|
/// Compatibility wrapper for `PdfDocument::toc_typeset_pages`.
pub fn pdf_toc_typeset_pages(
  document : PdfDocument,
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  dotleader : Bool,
  process_struct_tree : Bool,
  labels : ArrayView[PdfPageLabel],
  bookmarks : ArrayView[PdfBookmark],
) -> PdfTypeTypesetResult raise PdfError {
  document.toc_typeset_pages(
    fontpack, font_size, title, dotleader, process_struct_tree, labels, bookmarks,
  )
}
