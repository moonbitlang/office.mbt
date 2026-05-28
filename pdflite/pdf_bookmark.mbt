///|
fn pdf_bookmark_is_path_separator(code_unit : UInt16) -> Bool {
  let value = code_unit.to_int()
  value == 47 || value == 92
}

///|
fn pdf_bookmark_basename(path : String) -> String {
  let mut start = 0
  for index in 0..<path.length() {
    if pdf_bookmark_is_path_separator(path.at(index)) {
      start = index + 1
    }
  }
  path[start:].to_owned()
}

///|
fn PdfDocument::pdf_bookmark_has_outlines(
  self : PdfDocument,
) -> Bool raise PdfError {
  let root = self.pdf_bookmark_catalog()
  self.lookup_direct(pdf_bookmark_outlines_key(), root) is Some(_)
}

///|
fn pdf_bookmark_mark_ancestors(
  bookmarks : ArrayView[PdfBookmark],
  keep : Array[Bool],
  index : Int,
) -> Unit {
  let mut wanted_level = bookmarks[index].level - 1
  let mut current = index - 1
  while current >= 0 && wanted_level >= 0 {
    if bookmarks[current].level == wanted_level {
      keep[current] = true
      wanted_level -= 1
    }
    current -= 1
  }
}

///|
fn PdfDocument::pdf_bookmarks_for_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[PdfBookmark] raise PdfError {
  let bookmarks = self.read_bookmarks(preserve_actions=true)
  let page_reference_numbers = self.page_reference_numbers()
  let page_number_lookup = pdf_page_number_lookup(page_reference_numbers)
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let keep = [ for _ in bookmarks => false ]
  for index in 0..<bookmarks.length() {
    let page_number = self.pdf_destination_page_number_with_lookup(
      bookmarks[index].target,
      page_number_lookup,
    )
    if selected_pages.contains(page_number) {
      keep[index] = true
      pdf_bookmark_mark_ancestors(bookmarks, keep, index)
    }
  }
  let output : Array[PdfBookmark] = Array::new(capacity=bookmarks.length())
  for index in 0..<bookmarks.length() {
    if keep[index] {
      output.push(bookmarks[index])
    }
  }
  output
}

///|
fn PdfDocument::pdf_bookmark_document_title(self : PdfDocument) -> String {
  let info_title = self.info_utf8(pdf_bookmark_title_key())
  let xmp_title = self.xmp_info(pdf_bookmark_title_key())
  if info_title == "" {
    xmp_title
  } else if xmp_title == "" {
    info_title
  } else {
    xmp_title
  }
}

///|
/// Add a top-level title bookmark pointing at page one.
///
/// Existing bookmarks are indented by one level. When `use_title` is true,
/// the document metadata title is preferred, matching cpdf's XMP-over-Info
/// precedence; otherwise the basename of `filename` is used.
pub fn PdfDocument::add_bookmark_title(
  self : PdfDocument,
  filename : String,
  use_title : Bool,
) -> PdfDocument raise PdfError {
  let title = if use_title {
    self.pdf_bookmark_document_title()
  } else {
    pdf_bookmark_basename(filename)
  }
  let page_object = match self.page_object_number(1) {
    Some(number) => number
    None => raise SoftError("add_bookmark_title: page not found")
  }
  let bookmarks = self.read_bookmarks(preserve_actions=true)
  let indented : Array[PdfBookmark] = [
    {
      level: 0,
      text: pdf_pdfdocstring_of_utf8(@utf8.encode(title)),
      target: DestXYZ(TargetPageObject(page_object), None, None, None),
      is_open: false,
      colour: pdf_bookmark_black,
      flags: 0,
    },
  ]
  for bookmark in bookmarks {
    indented.push({ ..bookmark, level: bookmark.level + 1 })
  }
  self.add_bookmarks(indented)
}

///|
/// Compatibility wrapper for `PdfDocument::add_bookmark_title`.
pub fn pdf_add_bookmark_title(
  filename : String,
  use_title : Bool,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.add_bookmark_title(filename, use_title)
}

///|
/// Return a copy of the document whose bookmarks are open below `level`.
pub fn PdfDocument::bookmarks_open_to_level(
  self : PdfDocument,
  level : Int,
) -> PdfDocument raise PdfError {
  let bookmarks = self.read_bookmarks(preserve_actions=true)
  let updated : Array[PdfBookmark] = []
  for bookmark in bookmarks {
    updated.push({ ..bookmark, is_open: bookmark.level < level })
  }
  self.add_bookmarks(updated)
}

///|
/// Compatibility wrapper for `PdfDocument::bookmarks_open_to_level`.
pub fn pdf_bookmarks_open_to_level(
  level : Int,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.bookmarks_open_to_level(level)
}

///|
fn pdf_bookmark_replacement_number(
  changes : ArrayView[(Int, Int)],
  number : Int,
) -> Int? {
  for change in changes {
    if change.0 == number {
      break Some(change.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_bookmark_change_target_page(
  changes : ArrayView[(Int, Int)],
  target : PdfTargetPage,
) -> PdfTargetPage? {
  match target {
    TargetPageObject(number) =>
      match pdf_bookmark_replacement_number(changes, number) {
        Some(replacement) => Some(TargetPageObject(replacement))
        None => None
      }
    TargetOtherDocPageNumber(_) => None
  }
}

///|
fn pdf_bookmark_change_destination(
  changes : ArrayView[(Int, Int)],
  destination : PdfDestination,
) -> PdfDestination? {
  match destination {
    DestXYZ(target, left, top, zoom) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestXYZ(target, left, top, zoom))
        None => None
      }
    DestFit(target) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFit(target))
        None => None
      }
    DestFitH(target, top) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitH(target, top))
        None => None
      }
    DestFitV(target, left) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitV(target, left))
        None => None
      }
    DestFitR(target, left, bottom, right, top) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitR(target, left, bottom, right, top))
        None => None
      }
    DestFitB(target) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFit(target))
        None => None
      }
    DestFitBH(target, top) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitBH(target, top))
        None => None
      }
    DestFitBV(target, left) =>
      match pdf_bookmark_change_target_page(changes, target) {
        Some(target) => Some(DestFitBV(target, left))
        None => None
      }
    _ => None
  }
}

///|
/// Renumber page-object targets in one bookmark.
///
/// `changes` contains `(old_object_number, new_object_number)` pairs. Targets
/// without a matching page-object number are preserved.
pub fn pdf_change_bookmark(
  changes : ArrayView[(Int, Int)],
  bookmark : PdfBookmark,
) -> PdfBookmark {
  match pdf_bookmark_change_destination(changes, bookmark.target) {
    Some(target) => { ..bookmark, target, }
    None => bookmark
  }
}

///|
/// Transform a bookmark destination by a matrix.
///
/// Only the destination is changed; level, text, open state, colour, and flags
/// are preserved.
pub fn PdfDocument::transform_bookmark(
  self : PdfDocument,
  matrix : TransformMatrix,
  bookmark : PdfBookmark,
) -> PdfBookmark raise PdfError {
  { ..bookmark, target: self.transform_destination(matrix, bookmark.target) }
}

///|
/// Compatibility wrapper for `PdfDocument::transform_bookmark`.
pub fn pdf_transform_bookmark(
  document : PdfDocument,
  matrix : TransformMatrix,
  bookmark : PdfBookmark,
) -> PdfBookmark raise PdfError {
  document.transform_bookmark(matrix, bookmark)
}
