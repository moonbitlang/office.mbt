///|
/// Calculate the cpdf add-rectangle lower-left origin after placement.
pub fn pdf_addtext_rectangle_origin(
  bounds : PdfRectangle,
  position : PdfPosition,
  width : Double,
  height : Double,
) -> (Double, Double) {
  let placed = pdf_calculate_position(false, width, bounds, position)
  let y = match position {
    PdfPositionTop(_) | PdfPositionTopLeft(_, _) | PdfPositionTopRight(_, _) =>
      placed.y - height
    PdfPositionCentre | PdfPositionPosCentre(_, _) => placed.y - height / 2.0
    _ => placed.y
  }
  (placed.x, y)
}

///|
fn PdfDocument::pdf_addtext_rectangle_bounds(
  self : PdfDocument,
  page : PdfPage,
  relative_to_box : PdfName,
) -> PdfRectangle raise PdfError {
  if relative_to_box == pdf_page_mediabox_key() {
    self.parse_rectangle(page.mediabox)
  } else {
    match self.lookup_direct(relative_to_box, page.rest) {
      Some(box_object) => self.parse_rectangle(box_object)
      None => self.parse_rectangle(page.mediabox)
    }
  }
}

///|
fn PdfDocument::pdf_addtext_rectangle_dimensions(
  self : PdfDocument,
  page : PdfPage,
  coord : String,
) -> (Double, Double) raise PdfError {
  match self.parse_units_string(page, coord) {
    [width, height] => (width, height)
    _ => raise SoftError("bad coordinate specification")
  }
}

///|
fn PdfDocument::pdf_addtext_rectangle_page(
  self : PdfDocument,
  page : PdfPage,
  coord : String,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box : PdfName,
  outline : Bool,
  line_width : Double,
  opacity : Double,
  underneath : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
  let (resources, extgstate_name) = self.pdf_addtext_opacity_resources(
    page.resources,
    opacity,
  )
  let bounds = self.pdf_addtext_rectangle_bounds(page, relative_to_box)
  let (width, height) = self.pdf_addtext_rectangle_dimensions(page, coord)
  let (x, y) = pdf_addtext_rectangle_origin(bounds, position, width, height)
  let ops = pdf_addtext_rectangle_ops(
    x, y, width, height, colour, outline, line_width, extgstate_name,
  )
  let page = { ..page, resources, }
  if underneath {
    self.prepend_operators(page, ops, fast~)
  } else {
    self.postpend_operators(page, ops, fast~)
  }
}

///|
/// Add a cpdf-style rectangle stamp to selected one-based pages.
///
/// The rectangle dimensions are parsed with cpdf coordinate syntax, placed
/// relative to `relative_to_box`, wrapped as `/CPDFSTAMP` artifact content, and
/// appended unless `underneath` is set.
pub fn PdfDocument::addtext_rectangle(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  coord : String,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  outline? : Bool = false,
  line_width? : Double = 1.0,
  opacity? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_addtext_validate_page_numbers(
    page_numbers,
    pages.length(),
    "addtext_rectangle",
  )
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      rewritten.push(
        self.pdf_addtext_rectangle_page(
          page, coord, colour, position, relative_to_box, outline, line_width, opacity,
          underneath, fast,
        ),
      )
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_rectangle`.
pub fn pdf_addtext_rectangle(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  coord : String,
  colour : PdfContentColour,
  position : PdfPosition,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  outline? : Bool = false,
  line_width? : Double = 1.0,
  opacity? : Double = 1.0,
  underneath? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.addtext_rectangle(
    page_numbers,
    coord,
    colour,
    position,
    relative_to_box~,
    outline~,
    line_width~,
    opacity~,
    underneath~,
    fast~,
  )
}

///|
/// Source-spelled compatibility wrapper matching cpdfaddtext's `addrectangle`.
pub fn pdf_addrectangle(
  fast : Bool,
  coord : String,
  colour : PdfContentColour,
  outline : Bool,
  line_width : Double,
  opacity : Double,
  position : PdfPosition,
  relative_to_box : String,
  underneath : Bool,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.addtext_rectangle(
    page_numbers,
    coord,
    colour,
    position,
    relative_to_box=pdf_page_box_name_of_string(relative_to_box),
    outline~,
    line_width~,
    opacity~,
    underneath~,
    fast~,
  )
}
