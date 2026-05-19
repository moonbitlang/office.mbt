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
fn pdf_page_box_contains_page(
  page_numbers : ArrayView[Int],
  page_number : Int,
) -> Bool {
  for selected in page_numbers {
    if selected == page_number {
      break true
    }
  } nobreak {
    false
  }
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
  rewrite : (PdfDocument, Int, PdfPage) -> PdfPage raise PdfError,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), context)
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
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
) -> PdfObject {
  let (x, y, width, height) = box
  PdfArray([PdfReal(x), PdfReal(y), PdfReal(x + width), PdfReal(y + height)])
}

///|
fn pdf_page_box_bounds_object(
  bounds : (Double, Double, Double, Double),
) -> PdfObject {
  let (min_x, min_y, max_x, max_y) = bounds
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn PdfDocument::pdf_page_box_object(
  self : PdfDocument,
  page : PdfPage,
  box_name : PdfName,
  mediabox_if_missing : Bool,
) -> PdfObject raise PdfError {
  if box_name == pdf_page_mediabox_key() {
    page.mediabox
  } else {
    match self.lookup_direct(box_name, page.rest) {
      Some(value) => value
      None =>
        if mediabox_if_missing {
          page.mediabox
        } else {
          raise BadPageSpecification(
            "hard_box: box " + pdf_page_box_name_text(box_name) + " not found",
          )
        }
    }
  }
}

///|
fn PdfDocument::pdf_page_hard_box_page(
  self : PdfDocument,
  page : PdfPage,
  box_name : PdfName,
  mediabox_if_missing : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
  let bounds = self.parse_rectangle(
    self.pdf_page_box_object(page, box_name, mediabox_if_missing),
  )
  self.prepend_operators(
    page,
    [
      Op_re(
        bounds.min_x,
        bounds.min_y,
        bounds.max_x - bounds.min_x,
        bounds.max_y - bounds.min_y,
      ),
      Op_W,
      Op_n,
    ],
    fast~,
  )
}

///|
fn PdfDocument::pdf_page_remove_box_page(
  self : PdfDocument,
  page : PdfPage,
  box_name : PdfName,
) -> PdfPage raise PdfError {
  ignore(self)
  { ..page, rest: page.rest.remove_dict_entry(box_name) }
}

///|
fn PdfDocument::pdf_page_copy_box_source(
  self : PdfDocument,
  page : PdfPage,
  from_box : PdfName,
  mediabox_if_missing : Bool,
) -> PdfObject? {
  if from_box == pdf_page_mediabox_key() {
    Some(page.mediabox)
  } else {
    match self.lookup_direct(from_box, page.rest) {
      Some(value) => Some(value)
      None => if mediabox_if_missing { Some(page.mediabox) } else { None }
    }
  }
}

///|
fn PdfDocument::pdf_page_copy_box_page(
  self : PdfDocument,
  page : PdfPage,
  from_box : PdfName,
  to_box : PdfName,
  mediabox_if_missing : Bool,
) -> PdfPage raise PdfError {
  match self.pdf_page_copy_box_source(page, from_box, mediabox_if_missing) {
    Some(value) =>
      if to_box == pdf_page_mediabox_key() {
        { ..page, mediabox: value }
      } else {
        { ..page, rest: page.rest.add_dict_entry(to_box, value) }
      }
    None => page
  }
}

///|
fn PdfDocument::pdf_page_set_mediabox_page(
  self : PdfDocument,
  page_number : Int,
  page : PdfPage,
  boxes : ArrayView[(Double, Double, Double, Double)],
) -> PdfPage {
  ignore(self)
  { ..page, mediabox: pdf_page_box_xywh_object(boxes[page_number - 1]) }
}

///|
fn PdfDocument::pdf_page_crop_page(
  self : PdfDocument,
  page_number : Int,
  page : PdfPage,
  boxes : ArrayView[(Double, Double, Double, Double)],
  box_name : PdfName,
) -> PdfPage raise PdfError {
  ignore(self)
  {
    ..page,
    rest: page.rest.add_dict_entry(
      box_name,
      pdf_page_box_xywh_object(boxes[page_number - 1]),
    ),
  }
}

///|
fn PdfDocument::pdf_page_set_box_page(
  self : PdfDocument,
  page : PdfPage,
  box_name : PdfName,
  min_x : Double,
  max_x : Double,
  min_y : Double,
  max_y : Double,
) -> PdfPage raise PdfError {
  ignore(self)
  {
    ..page,
    rest: page.rest.add_dict_entry(
      box_name,
      pdf_page_box_bounds_object((min_x, min_y, max_x, max_y)),
    ),
  }
}

///|
fn PdfDocument::pdf_page_change_box_object(
  self : PdfDocument,
  object : PdfObject,
  transform : (Double, Double, Double, Double) -> (
    Double,
    Double,
    Double,
    Double,
  ),
) -> PdfObject raise PdfError {
  let bounds = self.parse_rectangle(object)
  pdf_page_box_bounds_object(
    transform(bounds.min_x, bounds.min_y, bounds.max_x, bounds.max_y),
  )
}

///|
/// Hard-clip selected pages to a page box by prepending a clipping rectangle.
///
/// `page_numbers` are 1-based. `box_name` is usually `/MediaBox`, `/CropBox`,
/// `/TrimBox`, `/ArtBox`, or `/BleedBox`. Missing non-media boxes raise unless
/// `mediabox_if_missing` is true. In `fast` mode the clip stream is prepended
/// without parsing existing content.
pub fn PdfDocument::hard_box(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : PdfName,
  mediabox_if_missing? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.pdf_page_box_rewrite_pages(page_numbers, "hard_box", (_, _, page) => {
    self.pdf_page_hard_box_page(page, box_name, mediabox_if_missing, fast)
  })
}

///|
/// Compatibility wrapper for `PdfDocument::hard_box`.
pub fn pdf_hard_box(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : PdfName,
  mediabox_if_missing? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.hard_box(page_numbers, box_name, mediabox_if_missing~, fast~)
}

///|
/// Return whether a 1-based page has a named non-media page box.
///
/// This mirrors cpdf's `hasbox`: invalid page numbers raise, and the check is
/// performed against the page's explicit dictionary entries rather than treating
/// `/MediaBox` as always present.
pub fn PdfDocument::has_page_box(
  self : PdfDocument,
  page_number : Int,
  box_name : PdfName,
) -> Bool raise PdfError {
  let pages = self.pages_of_pagetree()
  if page_number < 1 || page_number > pages.length() {
    raise BadPageSpecification("hasbox: bad page")
  }
  match self.lookup_direct(box_name, pages[page_number - 1].rest) {
    Some(_) => true
    None => false
  }
}

///|
/// Compatibility wrapper for `PdfDocument::has_page_box`.
pub fn pdf_hasbox(
  document : PdfDocument,
  page_number : Int,
  box_name : PdfName,
) -> Bool raise PdfError {
  document.has_page_box(page_number, box_name)
}

///|
/// Copy one page-box value to another on selected pages.
///
/// Missing source boxes leave the page unchanged unless `mediabox_if_missing`
/// is true, in which case the page `/MediaBox` is copied.
pub fn PdfDocument::copy_page_box(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  from_box : PdfName,
  to_box : PdfName,
  mediabox_if_missing? : Bool = false,
) -> PdfDocument raise PdfError {
  self.pdf_page_box_rewrite_pages(page_numbers, "copy_page_box", (_, _, page) => {
    self.pdf_page_copy_box_page(page, from_box, to_box, mediabox_if_missing)
  })
}

///|
/// Compatibility wrapper for `PdfDocument::copy_page_box`.
pub fn pdf_copy_page_box(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  from_box : PdfName,
  to_box : PdfName,
  mediabox_if_missing? : Bool = false,
) -> PdfDocument raise PdfError {
  document.copy_page_box(page_numbers, from_box, to_box, mediabox_if_missing~)
}

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
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
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
/// Compatibility wrapper for `PdfDocument::set_mediaboxes`.
pub fn pdf_set_mediaboxes(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  boxes : ArrayView[(Double, Double, Double, Double)],
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
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
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
/// Shift `/MediaBox` and known page boxes by page-indexed offsets.
///
/// This ports cpdf's `shift_boxes`: offsets are indexed by absolute page number
/// and content streams, annotations, and destination coordinates are not moved.
pub fn PdfDocument::shift_boxes(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  offsets : ArrayView[(Double, Double)],
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "shift_boxes",
  )
  pdf_page_box_validate_offsets(offsets, pages.length())
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
      let offset = offsets[page_number - 1]
      rewritten.push(
        self.change_boxes(pages[index], (min_x, min_y, max_x, max_y) => {
          (
            min_x + offset.0,
            min_y + offset.1,
            max_x + offset.0,
            max_y + offset.1,
          )
        }),
      )
    } else {
      rewritten.push(pages[index])
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Rectify a page so its media-box origin is `(0, 0)`.
///
/// Known page boxes are shifted by the same amount, and page content,
/// annotations, and pattern matrices receive the compensating translation.
pub fn PdfDocument::rectify_boxes(
  self : PdfDocument,
  page : PdfPage,
  fast? : Bool = false,
) -> PdfPage raise PdfError {
  let bounds = self.parse_rectangle(page.mediabox)
  let page = self.change_boxes(page, (min_x, min_y, max_x, max_y) => {
    (
      min_x - bounds.min_x,
      min_y - bounds.min_y,
      max_x - bounds.min_x,
      max_y - bounds.min_y,
    )
  })
  if bounds.min_x != 0.0 || bounds.min_y != 0.0 {
    self.pdf_page_shift_page(
      page,
      transform_translate(-bounds.min_x, -bounds.min_y),
      fast,
    )
  } else {
    page
  }
}

///|
/// Compatibility wrapper for `PdfDocument::rectify_boxes`.
pub fn pdf_rectify_boxes(
  document : PdfDocument,
  page : PdfPage,
  fast? : Bool = false,
) -> PdfPage raise PdfError {
  document.rectify_boxes(page, fast~)
}

///|
/// Compatibility wrapper for `PdfDocument::shift_boxes`.
pub fn pdf_shift_boxes(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  offsets : ArrayView[(Double, Double)],
) -> PdfDocument raise PdfError {
  document.shift_boxes(page_numbers, offsets)
}

///|
/// Remove one page-box dictionary entry from selected pages.
pub fn PdfDocument::remove_page_box(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : PdfName,
) -> PdfDocument raise PdfError {
  self.pdf_page_box_rewrite_pages(page_numbers, "remove_page_box", (_, _, page) => {
    self.pdf_page_remove_box_page(page, box_name)
  })
}

///|
/// Compatibility wrapper for `PdfDocument::remove_page_box`.
pub fn pdf_remove_page_box(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  box_name : PdfName,
) -> PdfDocument raise PdfError {
  document.remove_page_box(page_numbers, box_name)
}

///|
/// Remove `/CropBox` entries from selected pages.
pub fn PdfDocument::remove_cropping(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.remove_page_box(page_numbers, pdf_page_cropbox_key())
}

///|
/// Compatibility wrapper for `PdfDocument::remove_cropping`.
pub fn pdf_remove_cropping_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_cropping(page_numbers)
}

///|
/// Remove `/TrimBox` entries from selected pages.
pub fn PdfDocument::remove_trim(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.remove_page_box(page_numbers, pdf_page_trimbox_key())
}

///|
/// Compatibility wrapper for `PdfDocument::remove_trim`.
pub fn pdf_remove_trim_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_trim(page_numbers)
}

///|
/// Remove `/ArtBox` entries from selected pages.
pub fn PdfDocument::remove_art(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.remove_page_box(page_numbers, pdf_page_artbox_key())
}

///|
/// Compatibility wrapper for `PdfDocument::remove_art`.
pub fn pdf_remove_art_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_art(page_numbers)
}

///|
/// Remove `/BleedBox` entries from selected pages.
pub fn PdfDocument::remove_bleed(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.remove_page_box(page_numbers, pdf_page_bleedbox_key())
}

///|
/// Compatibility wrapper for `PdfDocument::remove_bleed`.
pub fn pdf_remove_bleed_pdf(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_bleed(page_numbers)
}
