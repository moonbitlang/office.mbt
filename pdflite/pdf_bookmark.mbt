///|
fn pdf_bookmark_colour_is_black(colour : PdfBookmarkColour) -> Bool {
  colour.red == 0.0 && colour.green == 0.0 && colour.blue == 0.0
}

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
fn pdf_bookmark_node_object(bookmark : PdfBookmark) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_bookmark_title_key(), PdfString(bookmark.text)),
  ]
  let destination = pdf_object_of_destination(bookmark.target)
  if destination != PdfNull {
    match bookmark.target {
      DestAction(action) => entries.push((pdf_bookmark_action_key(), action))
      _ => entries.push((pdf_bookmark_dest_key(), destination))
    }
  }
  if !pdf_bookmark_colour_is_black(bookmark.colour) {
    entries.push(
      (
        pdf_bookmark_colour_key(),
        PdfArray([
          PdfReal(bookmark.colour.red),
          PdfReal(bookmark.colour.green),
          PdfReal(bookmark.colour.blue),
        ]),
      ),
    )
  }
  if bookmark.flags != 0 {
    entries.push((pdf_bookmark_flags_key(), PdfInteger(bookmark.flags)))
  }
  PdfDictionary(entries)
}

///|
fn pdf_bookmark_child_stop(
  bookmarks : ArrayView[PdfBookmark],
  start : Int,
  stop : Int,
  level : Int,
) -> Int {
  let mut index = start
  while index < stop && bookmarks[index].level > level {
    index += 1
  }
  index
}

///|
fn pdf_bookmark_make_nodes(
  bookmarks : ArrayView[PdfBookmark],
  start : Int,
  stop : Int,
  base_object_number : Int,
  source : Ref[Int],
) -> Array[PdfBookmarkNode] {
  let nodes : Array[PdfBookmarkNode] = []
  let mut index = start
  while index < stop {
    let bookmark = bookmarks[index]
    source.val += 1
    let number = base_object_number + source.val
    let child_start = index + 1
    let child_stop = pdf_bookmark_child_stop(
      bookmarks,
      child_start,
      stop,
      bookmark.level,
    )
    nodes.push({
      number,
      object: pdf_bookmark_node_object(bookmark),
      children: pdf_bookmark_make_nodes(
        bookmarks, child_start, child_stop, base_object_number, source,
      ),
      is_open: bookmark.is_open,
    })
    index = child_stop
  }
  nodes
}

///|
fn pdf_bookmark_any_open(nodes : ArrayView[PdfBookmarkNode]) -> Bool {
  for node in nodes {
    if node.is_open || pdf_bookmark_any_open(node.children) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_bookmark_total_visible(nodes : ArrayView[PdfBookmarkNode]) -> Int {
  let mut total = 0
  for node in nodes {
    total += 1
    if node.is_open {
      total += pdf_bookmark_total_visible(node.children)
    }
  }
  total
}

///|
fn pdf_bookmark_add_count(
  object : PdfObject,
  children : ArrayView[PdfBookmarkNode],
  is_open : Bool,
) -> PdfObject raise PdfError {
  if children.length() == 0 {
    object
  } else {
    let visible = pdf_bookmark_total_visible(children)
    object.add_dict_entry(
      pdf_bookmark_count_key(),
      PdfInteger(if is_open { visible } else { -visible }),
    )
  }
}

///|
fn pdf_bookmark_finalize_nodes(
  nodes : ArrayView[PdfBookmarkNode],
  parent_number : Int,
) -> Array[PdfBookmarkNode] raise PdfError {
  let output : Array[PdfBookmarkNode] = []
  for index in 0..<nodes.length() {
    let node = nodes[index]
    let children = pdf_bookmark_finalize_nodes(node.children, node.number)
    let mut object = node.object.add_dict_entry(
      pdf_bookmark_parent_key(),
      PdfIndirect(parent_number),
    )
    if children.length() > 0 {
      object = object
        .add_dict_entry(
          pdf_bookmark_first_key(),
          PdfIndirect(children[0].number),
        )
        .add_dict_entry(
          pdf_bookmark_last_key(),
          PdfIndirect(children[children.length() - 1].number),
        )
    }
    object = pdf_bookmark_add_count(object, children, node.is_open)
    if index > 0 {
      object = object.add_dict_entry(
        pdf_bookmark_prev_key(),
        PdfIndirect(nodes[index - 1].number),
      )
    }
    if index + 1 < nodes.length() {
      object = object.add_dict_entry(
        pdf_bookmark_next_key(),
        PdfIndirect(nodes[index + 1].number),
      )
    }
    output.push({ ..node, object, children })
  }
  output
}

///|
fn pdf_bookmark_flatten_nodes(
  nodes : ArrayView[PdfBookmarkNode],
  output : Array[(Int, PdfObject)],
) -> Unit {
  for node in nodes {
    output.push((node.number, node.object))
    pdf_bookmark_flatten_nodes(node.children, output)
  }
}

///|
fn pdf_bookmark_outline_root_object(
  nodes : ArrayView[PdfBookmarkNode],
) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_bookmark_first_key(), PdfIndirect(nodes[0].number)),
    (pdf_bookmark_last_key(), PdfIndirect(nodes[nodes.length() - 1].number)),
  ]
  if pdf_bookmark_any_open(nodes) {
    entries.push(
      (pdf_bookmark_count_key(), PdfInteger(pdf_bookmark_total_visible(nodes))),
    )
  }
  PdfDictionary(entries)
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
/// Return a copy of the document with catalog `/Outlines` removed.
///
/// The original document is not mutated; the returned document has a new root
/// object and trailer root reference.
pub fn PdfDocument::remove_bookmarks(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_bookmark_catalog()
  let pdf = self.copy()
  let root_without_outlines = root.remove_dict_entry(
    pdf_bookmark_outlines_key(),
  )
  let new_root = pdf.add_object(root_without_outlines)
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf
    .trailer_dict()
    .add_dict_entry(pdf_bookmark_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::remove_bookmarks`.
pub fn pdf_remove_bookmarks(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_bookmarks()
}

///|
/// Return a copy of the document with its outline tree replaced.
///
/// The input must be in preorder using zero-based `level` values. Empty input
/// removes existing bookmarks. New outline objects are allocated after the
/// current maximum object number.
pub fn PdfDocument::add_bookmarks(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
) -> PdfDocument raise PdfError {
  if bookmarks.length() == 0 {
    self.remove_bookmarks()
  } else {
    let root = self.pdf_bookmark_catalog()
    let pdf = self.copy()
    let base_object_number = self.objects.max_object_number()
    let source : Ref[Int] = { val: 0 }
    let nodes = pdf_bookmark_make_nodes(
      bookmarks,
      0,
      bookmarks.length(),
      base_object_number,
      source,
    )
    let outline_root_number = base_object_number + source.val + 1
    let nodes = pdf_bookmark_finalize_nodes(nodes, outline_root_number)
    pdf.add_object_given_number(
      outline_root_number,
      pdf_bookmark_outline_root_object(nodes),
    )
    let pairs : Array[(Int, PdfObject)] = []
    pdf_bookmark_flatten_nodes(nodes, pairs)
    for pair in pairs {
      let (number, object) = pair
      pdf.add_object_given_number(number, object)
    }
    let new_root = pdf.add_object(
      root.add_dict_entry(
        pdf_bookmark_outlines_key(),
        PdfIndirect(outline_root_number),
      ),
    )
    pdf.set_root(new_root)
    pdf.set_trailer_dict(
      pdf
      .trailer_dict()
      .add_dict_entry(pdf_bookmark_root_key(), PdfIndirect(new_root)),
    )
    pdf
  }
}

///|
/// Compatibility wrapper for `PdfDocument::add_bookmarks`.
pub fn pdf_add_bookmarks(
  bookmarks : ArrayView[PdfBookmark],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.add_bookmarks(bookmarks)
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
