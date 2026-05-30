///|
fn pdf_bookmark_colour_is_black(colour : @bookmark.PdfBookmarkColour) -> Bool {
  colour.red == 0.0 && colour.green == 0.0 && colour.blue == 0.0
}

///|
fn pdf_bookmark_node_object(
  bookmark : @bookmark.PdfBookmark,
) -> @syntax.PdfObject {
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
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
  bookmarks : ArrayView[@bookmark.PdfBookmark],
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
  bookmarks : ArrayView[@bookmark.PdfBookmark],
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
  object : @syntax.PdfObject,
  children : ArrayView[PdfBookmarkNode],
  is_open : Bool,
) -> @syntax.PdfObject raise @core.PdfError {
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
) -> Array[PdfBookmarkNode] raise @core.PdfError {
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
  output : Array[(Int, @syntax.PdfObject)],
) -> Unit {
  for node in nodes {
    output.push((node.number, node.object))
    pdf_bookmark_flatten_nodes(node.children, output)
  }
}

///|
fn pdf_bookmark_outline_root_object(
  nodes : ArrayView[PdfBookmarkNode],
) -> @syntax.PdfObject {
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
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
/// Return a copy of the document with catalog `/Outlines` removed.
///
/// The original document is not mutated; the returned document has a new root
/// object and trailer root reference.
pub fn PdfDocument::remove_bookmarks(
  self : PdfDocument,
) -> PdfDocument raise @core.PdfError {
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
) -> PdfDocument raise @core.PdfError {
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
  bookmarks : ArrayView[@bookmark.PdfBookmark],
) -> PdfDocument raise @core.PdfError {
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
    let pairs : Array[(Int, @syntax.PdfObject)] = []
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
  bookmarks : ArrayView[@bookmark.PdfBookmark],
  document : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  document.add_bookmarks(bookmarks)
}
