///|
fn pdf_page_stamp_identity_changes(count : Int) -> Array[(Int, Int)] {
  [
    for page_number in 1..<=count => (page_number, page_number)
  ]
}

///|
fn pdf_page_stamp_all_but_last(
  pages : ArrayView[@page.PdfPage],
) -> Array[@page.PdfPage] {
  [
    for index in 0..<(pages.length() - 1) => pages[index]
  ]
}

///|
fn PdfDocument::pdf_page_stamp_overlay_first_page(
  self : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  let pages = self.pages_of_pagetree()
  guard pages.length() > 0 else { raise SoftError("empty PDF") }
  self.change_pages([pages[0]], change_references=true, changes=[(1, 1)])
}

///|
/// Stamp the first page of `overlay` onto selected pages by merging content.
pub fn PdfDocument::stamp_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  overlay : PdfDocument,
  relative_to_box? : @core.PdfName = pdf_page_mediabox_key(),
  position? : @geometry.PdfPosition = PdfPositionBottomLeft(0.0, 0.0),
  topline? : Bool = false,
  midline? : Bool = false,
  fast? : Bool = false,
  scale_to_fit? : Bool = false,
  is_over? : Bool = true,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise @core.PdfError {
  let overlay = if process_struct_tree {
    overlay.remove_struct_tree().mark_all_as_artifact()
  } else {
    overlay.copy()
  }
  let prefix = self.shortest_unused_prefix()
  overlay.add_prefix(prefix)
  let bookmarks = self.read_bookmarks(preserve_actions=true) catch { _ => [] }
  let bookmark_page_numbers = self.page_reference_numbers()
  let base = self.remove_bookmarks()
  let overlay_without_bookmarks = overlay.remove_bookmarks()
  let base_pages = base.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    base_pages.length(),
    "stamp_pages",
  )
  let merged = pdf_merge_pdfs(
    false,
    false,
    ["a", "b"],
    [base, overlay_without_bookmarks.pdf_page_stamp_overlay_first_page()],
    [pdf_xobject_all_page_range(base), [1]],
  )
  merged.set_saved_encryption(self.saved_encryption())
  merged.pdf_xobject_copy_trailer_id_from(self)
  let merged_pages = merged.pages_of_pagetree()
  guard merged_pages.length() > 0 else { raise PageTreeExpected }
  let overlay_page = merged_pages[merged_pages.length() - 1]
  let under_pages = pdf_page_stamp_all_but_last(merged_pages)
  let selected_pages = @core.pdf_number_set(page_numbers)
  let new_pages : Array[@page.PdfPage] = Array::new(
    capacity=under_pages.length(),
  )
  for index in 0..<under_pages.length() {
    let page_number = index + 1
    let stamp_page = if selected_pages.contains(page_number) {
      overlay_page
    } else {
      @page.pdf_page_blank(@geometry.paper_a4)
    }
    new_pages.push(
      merged.pdf_page_stamp_pair(
        stamp_page,
        under_pages[index],
        relative_to_box,
        position,
        topline,
        midline,
        scale_to_fit,
        is_over,
        fast,
      ),
    )
  }
  let changed = merged.change_pages(
    new_pages,
    change_references=true,
    changes=pdf_page_stamp_identity_changes(new_pages.length()),
  )
  let final_page_numbers = changed.page_reference_numbers()
  if bookmarks.length() > 0 {
    changed.add_bookmarks(
      pdf_xobject_retained_bookmarks(
        bookmarks, bookmark_page_numbers, final_page_numbers,
      ),
    )
  } else {
    changed
  }
}
