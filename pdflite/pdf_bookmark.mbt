///|
fn pdf_bookmark_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_bookmark_outlines_key() -> PdfName {
  pdf_bookmark_name("/Outlines")
}

///|
fn pdf_bookmark_root_key() -> PdfName {
  pdf_bookmark_name("/Root")
}

///|
fn pdf_bookmark_first_key() -> PdfName {
  pdf_bookmark_name("/First")
}

///|
fn pdf_bookmark_next_key() -> PdfName {
  pdf_bookmark_name("/Next")
}

///|
fn pdf_bookmark_prev_key() -> PdfName {
  pdf_bookmark_name("/Prev")
}

///|
fn pdf_bookmark_parent_key() -> PdfName {
  pdf_bookmark_name("/Parent")
}

///|
fn pdf_bookmark_title_key() -> PdfName {
  pdf_bookmark_name("/Title")
}

///|
fn pdf_bookmark_last_key() -> PdfName {
  pdf_bookmark_name("/Last")
}

///|
fn pdf_bookmark_dest_key() -> PdfName {
  pdf_bookmark_name("/Dest")
}

///|
fn pdf_bookmark_action_key() -> PdfName {
  pdf_bookmark_name("/A")
}

///|
fn pdf_bookmark_d_key() -> PdfName {
  pdf_bookmark_name("/D")
}

///|
fn pdf_bookmark_count_key() -> PdfName {
  pdf_bookmark_name("/Count")
}

///|
fn pdf_bookmark_colour_key() -> PdfName {
  pdf_bookmark_name("/C")
}

///|
fn pdf_bookmark_flags_key() -> PdfName {
  pdf_bookmark_name("/F")
}

///|
fn PdfDocument::pdf_bookmark_catalog(
  self : PdfDocument,
) -> PdfObject raise PdfError {
  self.catalog()
}

///|
pub(all) struct PdfBookmarkColour {
  red : Double
  green : Double
  blue : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfBookmark {
  level : Int
  text : PdfBytes
  target : PdfDestination
  is_open : Bool
  colour : PdfBookmarkColour
  flags : Int
} derive(Debug, Eq, ToJson)

///|
struct PdfBookmarkNode {
  number : Int
  object : PdfObject
  children : Array[PdfBookmarkNode]
  is_open : Bool
} derive(Debug, Eq, ToJson)

///|
pub let pdf_bookmark_black : PdfBookmarkColour = {
  red: 0.0,
  green: 0.0,
  blue: 0.0,
}

///|
pub fn pdf_string_of_bookmark(
  bookmark : PdfBookmark,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_writer_push_ascii(output, bookmark.level.to_string())
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_view(output, bookmark.text[:])
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_view(
    output,
    pdf_write_object(pdf_object_of_destination(bookmark.target))[:],
  )
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_ascii(output, if bookmark.is_open { "true" } else { "false" })
  pdf_writer_push_byte(output, 10)
  Bytes::from_array(output)
}

///|
fn PdfDocument::pdf_bookmark_title(
  self : PdfDocument,
  outline : PdfObject,
) -> PdfBytes {
  match self.lookup_direct(pdf_bookmark_title_key(), outline) {
    Some(PdfString(title)) => title
    _ => @ascii.encode("")
  }
}

///|
fn PdfDocument::pdf_bookmark_target(
  self : PdfDocument,
  outline : PdfObject,
  preserve_actions : Bool,
) -> PdfDestination raise PdfError {
  match self.lookup_direct(pdf_bookmark_dest_key(), outline) {
    Some(PdfString(key)) if preserve_actions => DestString(key)
    Some(destination) =>
      self.read_destination(destination, shallow=preserve_actions)
    None =>
      match self.lookup_direct(pdf_bookmark_action_key(), outline) {
        None => DestNull
        Some(action) =>
          if preserve_actions {
            match self.lookup_direct(pdf_bookmark_d_key(), action) {
              Some(PdfArray(_) as destination) =>
                self.read_destination(destination, shallow=true)
              _ => DestAction(self.direct(action))
            }
          } else {
            match self.lookup_direct(pdf_bookmark_d_key(), action) {
              Some(destination) => self.read_destination(destination)
              None => DestAction(self.direct(action))
            }
          }
      }
  }
}

///|
fn PdfDocument::pdf_bookmark_is_open(
  self : PdfDocument,
  outline : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_bookmark_count_key(), outline) {
    Some(PdfInteger(count)) => count > 0
    _ => false
  }
}

///|
fn PdfDocument::pdf_bookmark_colour_number(
  self : PdfDocument,
  object : PdfObject,
) -> Double? {
  try self.get_number(object) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn PdfDocument::pdf_bookmark_colour(
  self : PdfDocument,
  outline : PdfObject,
) -> PdfBookmarkColour {
  match self.lookup_direct(pdf_bookmark_colour_key(), outline) {
    Some(PdfArray([red, green, blue])) =>
      match
        (
          self.pdf_bookmark_colour_number(red),
          self.pdf_bookmark_colour_number(green),
          self.pdf_bookmark_colour_number(blue),
        ) {
        (Some(red), Some(green), Some(blue)) => { red, green, blue }
        _ => pdf_bookmark_black
      }
    _ => pdf_bookmark_black
  }
}

///|
fn PdfDocument::pdf_bookmark_flags(
  self : PdfDocument,
  outline : PdfObject,
) -> Int {
  match self.lookup_direct(pdf_bookmark_flags_key(), outline) {
    Some(PdfInteger(flags)) => flags
    _ => 0
  }
}

///|
fn pdf_bookmark_colour_is_black(colour : PdfBookmarkColour) -> Bool {
  colour.red == 0.0 && colour.green == 0.0 && colour.blue == 0.0
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
fn PdfDocument::pdf_bookmark_of_outline(
  self : PdfDocument,
  level : Int,
  outline : PdfObject,
  preserve_actions : Bool,
) -> PdfBookmark raise PdfError {
  {
    level,
    text: self.pdf_bookmark_title(outline),
    target: self.pdf_bookmark_target(outline, preserve_actions),
    is_open: self.pdf_bookmark_is_open(outline),
    colour: self.pdf_bookmark_colour(outline),
    flags: self.pdf_bookmark_flags(outline),
  }
}

///|
fn PdfDocument::pdf_bookmark_traverse_siblings(
  self : PdfDocument,
  level : Int,
  first : PdfObject,
  preserve_actions : Bool,
  output : Array[PdfBookmark],
  depth : Int,
) -> Unit raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  output.push(self.pdf_bookmark_of_outline(level, first, preserve_actions))
  self.pdf_bookmark_traverse_children(
    level + 1,
    first,
    preserve_actions,
    output,
    depth + 1,
  )
  match self.lookup_direct(pdf_bookmark_next_key(), first) {
    Some(next) =>
      self.pdf_bookmark_traverse_siblings(
        level,
        next,
        preserve_actions,
        output,
        depth + 1,
      )
    None => ()
  }
}

///|
fn PdfDocument::pdf_bookmark_traverse_children(
  self : PdfDocument,
  level : Int,
  outline : PdfObject,
  preserve_actions : Bool,
  output : Array[PdfBookmark],
  depth : Int,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_bookmark_first_key(), outline) {
    Some(first) =>
      self.pdf_bookmark_traverse_siblings(
        level,
        first,
        preserve_actions,
        output,
        depth + 1,
      )
    None => ()
  }
}

///|
pub fn PdfDocument::read_bookmarks(
  self : PdfDocument,
  preserve_actions? : Bool = false,
) -> Array[PdfBookmark] raise PdfError {
  let output : Array[PdfBookmark] = []
  let root = self.pdf_bookmark_catalog()
  match self.lookup_direct(pdf_bookmark_outlines_key(), root) {
    Some(outlines) =>
      self.pdf_bookmark_traverse_children(
        0, outlines, preserve_actions, output, 0,
      )
    None => ()
  }
  output
}

///|
fn PdfDocument::pdf_bookmark_has_outlines(
  self : PdfDocument,
) -> Bool raise PdfError {
  let root = self.pdf_bookmark_catalog()
  self.lookup_direct(pdf_bookmark_outlines_key(), root) is Some(_)
}

///|
fn pdf_bookmark_page_member(
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
  let keep = [ for _ in bookmarks => false ]
  for index in 0..<bookmarks.length() {
    let page_number = self.pdf_destination_page_number(
      bookmarks[index].target,
      page_reference_numbers,
    )
    if pdf_bookmark_page_member(page_numbers, page_number) {
      keep[index] = true
      pdf_bookmark_mark_ancestors(bookmarks, keep, index)
    }
  }
  let output : Array[PdfBookmark] = []
  for index in 0..<bookmarks.length() {
    if keep[index] {
      output.push(bookmarks[index])
    }
  }
  output
}

///|
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
pub fn PdfDocument::transform_bookmark(
  self : PdfDocument,
  matrix : TransformMatrix,
  bookmark : PdfBookmark,
) -> PdfBookmark raise PdfError {
  { ..bookmark, target: self.transform_destination(matrix, bookmark.target) }
}
