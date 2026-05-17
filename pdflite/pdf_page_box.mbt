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
