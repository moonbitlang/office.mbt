///|
let pdf_page_trimbox_key_name : PdfName = pdf_page_name("/TrimBox")

///|
let pdf_page_artbox_key_name : PdfName = pdf_page_name("/ArtBox")

///|
let pdf_page_bleedbox_key_name : PdfName = pdf_page_name("/BleedBox")

///|
fn pdf_page_trimbox_key() -> PdfName {
  pdf_page_trimbox_key_name
}

///|
fn pdf_page_artbox_key() -> PdfName {
  pdf_page_artbox_key_name
}

///|
fn pdf_page_bleedbox_key() -> PdfName {
  pdf_page_bleedbox_key_name
}

///|
fn pdf_page_box_name_text(name : PdfName) -> String {
  @ascii.decode(name.bytes()) catch {
    _ => "<box>"
  }
}

///|
fn pdf_page_box_name_of_string(text : String) -> PdfName {
  pdf_page_name(text)
}

///|
fn pdf_page_box_validate_page_numbers(
  page_numbers : ArrayView[Int],
  end_page : Int,
  context : String,
) -> Unit raise PdfError {
  for page_number in page_numbers {
    if page_number < 1 || page_number > end_page {
      raise BadPageSpecification(
        context + ": range contains pages not present in pdf",
      )
    }
  }
}

///|
fn PdfDocument::pdf_page_box_rewrite_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  context : String,
  rewrite : (PdfDocument, Int, @page.PdfPage) -> @page.PdfPage raise PdfError,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), context)
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      rewritten.push(rewrite(self, page_number, pages[index]))
    } else {
      rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
fn pdf_page_box_validate_xywh_boxes(
  boxes : ArrayView[(Double, Double, Double, Double)],
  end_page : Int,
) -> Unit raise PdfError {
  if boxes.length() != end_page {
    raise BadPageSpecification(
      "set_mediaboxes: box count must match page count",
    )
  }
}

///|
fn pdf_page_box_validate_xywh_boxes_with_context(
  boxes : ArrayView[(Double, Double, Double, Double)],
  end_page : Int,
  context : String,
) -> Unit raise PdfError {
  if boxes.length() != end_page {
    raise BadPageSpecification(context + ": box count must match page count")
  }
}

///|
fn pdf_page_box_validate_offsets(
  offsets : ArrayView[(Double, Double)],
  end_page : Int,
) -> Unit raise PdfError {
  if offsets.length() != end_page {
    raise BadPageSpecification(
      "shift_boxes: offset count must match page count",
    )
  }
}

///|
fn pdf_page_box_xywh_object(
  box : (Double, Double, Double, Double),
) -> @syntax.PdfObject {
  let (x, y, width, height) = box
  PdfArray([PdfReal(x), PdfReal(y), PdfReal(x + width), PdfReal(y + height)])
}

///|
fn pdf_page_box_bounds_object(
  bounds : (Double, Double, Double, Double),
) -> @syntax.PdfObject {
  let (min_x, min_y, max_x, max_y) = bounds
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}
