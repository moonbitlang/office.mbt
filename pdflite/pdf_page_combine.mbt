///|
fn pdf_page_combine_take_pages(
  pages : ArrayView[PdfPage],
  count : Int,
) -> Array[PdfPage] {
  [
    for index in 0..<count => pages[index]
  ]
}

///|
fn pdf_page_combine_with_blank_pages(
  pages : ArrayView[PdfPage],
  count : Int,
) -> Array[PdfPage] {
  let output : Array[PdfPage] = []
  for page in pages {
    output.push(page)
  }
  for _ in 0..<count {
    output.push(pdf_page_blank(paper_a4))
  }
  output
}

///|
fn pdf_page_combine_equalize_overlay(
  overlay : PdfDocument,
  under_length : Int,
) -> PdfDocument raise PdfError {
  let overlay_pages = overlay.pages_of_pagetree()
  let overlay_length = overlay_pages.length()
  if overlay_length > under_length {
    overlay.change_pages(
      pdf_page_combine_take_pages(overlay_pages, under_length),
      change_references=true,
      changes=pdf_page_stamp_identity_changes(under_length),
    )
  } else if under_length > overlay_length {
    overlay.change_pages(
      pdf_page_combine_with_blank_pages(
        overlay_pages,
        under_length - overlay_length,
      ),
      change_references=true,
      changes=pdf_page_stamp_identity_changes(overlay_length),
    )
  } else {
    overlay
  }
}

///|
fn pdf_page_combine_output_changes(count : Int) -> Array[(Int, Int)] {
  let output : Array[(Int, Int)] = []
  for page_number in 1..<=count {
    output.push((page_number, page_number))
  }
  for page_number in 1..<=count {
    output.push((count + page_number, page_number))
  }
  output
}

///|
fn pdf_page_combine_retained_bookmarks(
  bookmarks : ArrayView[PdfBookmark],
  old_page_numbers : ArrayView[Int],
  final_page_numbers : ArrayView[Int],
) -> Array[PdfBookmark] {
  let changes : Array[(Int, Int)] = []
  let count = if old_page_numbers.length() < final_page_numbers.length() {
    old_page_numbers.length()
  } else {
    final_page_numbers.length()
  }
  for index in 0..<count {
    changes.push((old_page_numbers[index], final_page_numbers[index]))
  }
  let change_map = pdf_page_reference_map(changes)
  [
    for bookmark in bookmarks => {
      pdf_merge_renumber_bookmark_with_map(bookmark, change_map)
    }
  ]
}

///|
fn pdf_page_combine_append_bookmarks(
  first : ArrayView[PdfBookmark],
  second : ArrayView[PdfBookmark],
) -> Array[PdfBookmark] {
  let output : Array[PdfBookmark] = []
  for bookmark in first {
    output.push(bookmark)
  }
  for bookmark in second {
    output.push(bookmark)
  }
  output
}

///|
/// Combine each page in this document with the corresponding page of `overlay`.
///
/// The overlay is truncated or padded with blank A4 pages to match the under
/// document length. Overlay resources are prefixed before merging, and
/// bookmarks from both inputs are retained on the paired output pages.
pub fn PdfDocument::combine_pages(
  self : PdfDocument,
  overlay : PdfDocument,
  fast? : Bool = false,
  scale_to_fit? : Bool = false,
  overlay_is_under? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  let overlay = if process_struct_tree {
    overlay.remove_struct_tree().mark_all_as_artifact()
  } else {
    overlay.copy()
  }
  overlay.add_prefix(self.shortest_unused_prefix())
  let under_bookmarks = self.read_bookmarks(preserve_actions=true) catch {
    _ => []
  }
  let overlay_bookmarks = overlay.read_bookmarks(preserve_actions=true) catch {
    _ => []
  }
  let under_page_numbers = self.page_reference_numbers()
  let overlay_page_numbers = overlay.page_reference_numbers()
  let under = self.remove_bookmarks()
  let under_pages = under.pages_of_pagetree()
  let under_length = under_pages.length()
  let overlay = pdf_page_combine_equalize_overlay(
    overlay.remove_bookmarks(),
    under_length,
  )
  let overlay_length = overlay.pages_of_pagetree().length()
  if under_length != overlay_length {
    raise SoftError("combine_pages: not of equal length")
  }
  let merged = pdf_merge_pdfs(false, false, ["a", "b"], [under, overlay], [
    pdf_xobject_all_page_range(under),
    pdf_xobject_all_page_range(overlay),
  ])
  let merged_pages = merged.pages_of_pagetree()
  if merged_pages.length() != under_length * 2 {
    raise PageTreeExpected
  }
  let new_pages : Array[PdfPage] = []
  for index in 0..<under_length {
    new_pages.push(
      merged.pdf_page_stamp_pair(
        merged_pages[under_length + index],
        merged_pages[index],
        pdf_page_mediabox_key(),
        PdfPositionBottomLeft(0.0, 0.0),
        false,
        false,
        scale_to_fit,
        !overlay_is_under,
        fast,
      ),
    )
  }
  let changed = merged.change_pages(
    new_pages,
    change_references=true,
    changes=pdf_page_combine_output_changes(under_length),
  )
  let final_page_numbers = changed.page_reference_numbers()
  let retained_under = pdf_page_combine_retained_bookmarks(
    under_bookmarks, under_page_numbers, final_page_numbers,
  )
  let retained_overlay = pdf_page_combine_retained_bookmarks(
    overlay_bookmarks, overlay_page_numbers, final_page_numbers,
  )
  let bookmarks = pdf_page_combine_append_bookmarks(
    retained_under, retained_overlay,
  )
  if bookmarks.length() > 0 {
    changed.add_bookmarks(bookmarks)
  } else {
    changed
  }
}

///|
/// Compatibility wrapper for `PdfDocument::combine_pages`.
pub fn pdf_combine_pages(
  under : PdfDocument,
  overlay : PdfDocument,
  fast? : Bool = false,
  scale_to_fit? : Bool = false,
  overlay_is_under? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  under.combine_pages(
    overlay,
    fast~,
    scale_to_fit~,
    overlay_is_under~,
    process_struct_tree~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `combine_pages` argument order.
pub fn pdf_combine_pages_cpdf_order(
  process_struct_tree : Bool,
  fast : Bool,
  under : PdfDocument,
  overlay : PdfDocument,
  scale_to_fit : Bool,
  overlay_is_under : Bool,
) -> PdfDocument raise PdfError {
  under.combine_pages(
    overlay,
    fast~,
    scale_to_fit~,
    overlay_is_under~,
    process_struct_tree~,
  )
}
