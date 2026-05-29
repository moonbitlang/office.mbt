///|
/// Change `/MediaBox` and known page boxes with a coordinate transform.
///
/// The callback receives `(min_x, min_y, max_x, max_y)` and returns replacement
/// bounds. This ports cpdf's single-page `change_boxes` helper.
pub fn PdfDocument::change_boxes(
  self : PdfDocument,
  page : PdfPage,
  transform : (Double, Double, Double, Double) -> (
    Double,
    Double,
    Double,
    Double,
  ),
) -> PdfPage raise PdfError {
  let mut rest = page.rest
  for name in pdf_page_upright_box_names() {
    match self.lookup_direct(name, page.rest) {
      Some(value) =>
        rest = rest.add_dict_entry(
          name,
          self.pdf_page_change_box_object(value, transform),
        )
      None => ()
    }
  }
  {
    ..page,
    mediabox: self.pdf_page_change_box_object(page.mediabox, transform),
    rest,
  }
}

///|
/// Compatibility wrapper for `PdfDocument::change_boxes`.
pub fn pdf_change_boxes(
  document : PdfDocument,
  page : PdfPage,
  transform : (Double, Double, Double, Double) -> (
    Double,
    Double,
    Double,
    Double,
  ),
) -> PdfPage raise PdfError {
  document.change_boxes(page, transform)
}

///|
/// Compatibility wrapper matching cpdfpage's `change_boxes` argument order.
pub fn pdf_change_boxes_cpdf_order(
  transform : (Double, Double, Double, Double) -> (
    Double,
    Double,
    Double,
    Double,
  ),
  document : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  document.change_boxes(page, transform)
}

///|
/// Set `/MediaBox` on selected pages from a page-indexed `(x, y, width, height)`
/// list.
///
/// `boxes` must contain one entry for every page in the document, matching
/// cpdf's rectangle parser. `page_numbers` selects which page entries are
/// applied, and each selected page uses `boxes[page_number - 1]`.
pub fn PdfDocument::set_mediaboxes(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  boxes : ArrayView[(Double, Double, Double, Double)],
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "set_mediaboxes",
  )
  pdf_page_box_validate_xywh_boxes(boxes, pages.length())
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      rewritten.push(
        self.pdf_page_set_mediabox_page(page_number, pages[index], boxes),
      )
    } else {
      rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility alias for `PdfDocument::set_mediaboxes`.
pub fn PdfDocument::set_mediabox(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  boxes : ArrayView[(Double, Double, Double, Double)],
) -> PdfDocument raise PdfError {
  self.set_mediaboxes(page_numbers, boxes)
}

///|
/// Compatibility wrapper for `PdfDocument::set_mediaboxes`.
pub fn pdf_set_mediaboxes(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  boxes : ArrayView[(Double, Double, Double, Double)],
) -> PdfDocument raise PdfError {
  document.set_mediaboxes(page_numbers, boxes)
}

///|
/// Compatibility wrapper matching cpdfpage's `set_mediabox` argument order.
pub fn pdf_set_mediabox(
  boxes : ArrayView[(Double, Double, Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.set_mediaboxes(page_numbers, boxes)
}

///|
/// Set a named page box on selected pages from a page-indexed `(x, y, width,
/// height)` list.
///
/// This ports cpdf's `crop_pdf`. By default it writes `/CropBox`; `box_name`
/// can target another page-box dictionary entry. The selected pages use
/// `boxes[page_number - 1]`.
pub fn PdfDocument::crop_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  boxes : ArrayView[(Double, Double, Double, Double)],
  box_name? : PdfName = pdf_page_cropbox_key(),
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "crop_pages")
  pdf_page_box_validate_xywh_boxes_with_context(
    boxes,
    pages.length(),
    "crop_pages",
  )
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      rewritten.push(
        self.pdf_page_crop_page(page_number, pages[index], boxes, box_name),
      )
    } else {
      rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::crop_pages`.
pub fn pdf_crop_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  boxes : ArrayView[(Double, Double, Double, Double)],
  box_name? : PdfName = pdf_page_cropbox_key(),
) -> PdfDocument raise PdfError {
  document.crop_pages(page_numbers, boxes, box_name~)
}

///|
/// Compatibility wrapper using cpdfpage's string page-box names.
pub fn PdfDocument::crop_pdf_string(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  boxes : ArrayView[(Double, Double, Double, Double)],
  box_name? : String = "/CropBox",
) -> PdfDocument raise PdfError {
  self.crop_pages(
    page_numbers,
    boxes,
    box_name=pdf_page_box_name_of_string(box_name),
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `crop_pdf` value argument order.
pub fn pdf_crop_pdf_string(
  boxes : ArrayView[(Double, Double, Double, Double)],
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name? : String = "/CropBox",
) -> PdfDocument raise PdfError {
  document.crop_pdf_string(page_numbers, boxes, box_name~)
}

///|
/// Set a fixed named page box on selected pages.
///
/// The scalar argument order mirrors cpdf's historical `setBox`:
/// `(min_x, max_x, min_y, max_y)`.
pub fn PdfDocument::set_page_box(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : PdfName,
  min_x : Double,
  max_x : Double,
  min_y : Double,
  max_y : Double,
) -> PdfDocument raise PdfError {
  self.pdf_page_box_rewrite_pages(page_numbers, "set_page_box", (_, _, page) => {
    self.pdf_page_set_box_page(page, box_name, min_x, max_x, min_y, max_y)
  })
}

///|
/// Compatibility wrapper for `PdfDocument::set_page_box`.
pub fn pdf_set_box(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : PdfName,
  min_x : Double,
  max_x : Double,
  min_y : Double,
  max_y : Double,
) -> PdfDocument raise PdfError {
  document.set_page_box(page_numbers, box_name, min_x, max_x, min_y, max_y)
}

///|
/// Compatibility wrapper using cpdfpage's string page-box names.
pub fn PdfDocument::set_box_string(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : String,
  min_x : Double,
  max_x : Double,
  min_y : Double,
  max_y : Double,
) -> PdfDocument raise PdfError {
  self.set_page_box(
    page_numbers,
    pdf_page_box_name_of_string(box_name),
    min_x,
    max_x,
    min_y,
    max_y,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `setBox` scalar argument order.
pub fn pdf_set_box_string(
  box_name : String,
  min_x : Double,
  max_x : Double,
  min_y : Double,
  max_y : Double,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.set_box_string(page_numbers, box_name, min_x, max_x, min_y, max_y)
}
