///|
fn pdf_page_is_reserved_key(key : PdfName) -> Bool {
  key == pdf_page_type_key() ||
  key == pdf_page_parent_key() ||
  key == pdf_page_resources_key() ||
  key == pdf_page_mediabox_key() ||
  key == pdf_page_rotate_key() ||
  key == pdf_page_contents_key()
}

///|
fn pdf_page_rest_entries(
  rest : PdfObject,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match rest {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (key, _) = entry
        if !pdf_page_is_reserved_key(key) {
          output.push(entry)
        }
      }
      output
    }
    _ => raise DictionaryExpected
  }
}

///|
fn pdf_page_rest_object_from_page(page : PdfObject) -> PdfObject raise PdfError {
  match page {
    PdfDictionary(entries) => {
      let rest : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (key, _) = entry
        if !pdf_page_is_reserved_key(key) {
          rest.push(entry)
        }
      }
      PdfDictionary(rest)
    }
    _ => raise DictionaryExpected
  }
}

///|
fn PdfDocument::pdf_page_content_references(
  self : PdfDocument,
  content : ArrayView[PdfObject],
) -> Array[PdfObject] {
  let refs : Array[PdfObject] = Array::new(capacity=content.length())
  for object in content {
    match object {
      PdfIndirect(_) => refs.push(object)
      _ => refs.push(PdfIndirect(self.add_object(object)))
    }
  }
  refs
}

///|
fn PdfDocument::pdf_page_object(
  self : PdfDocument,
  page : PdfPage,
  parent : Int,
) -> PdfObject raise PdfError {
  let rest_entries = pdf_page_rest_entries(page.rest)
  let entries : Array[(PdfName, PdfObject)] = Array::new(
    capacity=6 + rest_entries.length(),
  )
  entries.push((pdf_page_type_key(), PdfNameObject(pdf_page_type_page())))
  entries.push((pdf_page_parent_key(), PdfIndirect(parent)))
  entries.push((pdf_page_resources_key(), page.resources))
  entries.push((pdf_page_mediabox_key(), page.mediabox))
  match pdf_page_int_of_rotation(page.rotate) {
    0 => ()
    value => entries.push((pdf_page_rotate_key(), PdfInteger(value)))
  }
  let content_refs = self.pdf_page_content_references(page.content)
  if content_refs.length() > 0 {
    entries.push((pdf_page_contents_key(), PdfArray(content_refs)))
  }
  for entry in rest_entries {
    entries.push(entry)
  }
  PdfDictionary(entries)
}

///|
fn pdf_page_slice(
  pages : ArrayView[PdfPage],
  start : Int,
  stop : Int,
) -> Array[PdfPage] {
  let output : Array[PdfPage] = Array::new(capacity=stop - start)
  for i in start..<stop {
    output.push(pages[i])
  }
  output
}

///|
fn pdf_page_pages_node_object(
  kids : ArrayView[Int],
  count : Int,
  parent : Int,
) -> PdfObject {
  let kid_refs : Array[PdfObject] = Array::new(capacity=kids.length())
  for number in kids {
    kid_refs.push(PdfIndirect(number))
  }
  let entries : Array[(PdfName, PdfObject)] = Array::new(
    capacity=if parent == 0 { 3 } else { 4 },
  )
  entries.push((pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())))
  entries.push((pdf_page_kids_key(), PdfArray(kid_refs)))
  entries.push((pdf_page_count_key(), PdfInteger(count)))
  if parent != 0 {
    entries.push((pdf_page_parent_key(), PdfIndirect(parent)))
  }
  PdfDictionary(entries)
}

///|
fn PdfDocument::pdf_page_add_pagetree_node(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
  parent : Int,
  node_number : Int,
) -> Unit raise PdfError {
  if pages.length() < 10 {
    let page_numbers : Array[Int] = Array::new(capacity=pages.length())
    for page in pages {
      page_numbers.push(
        self.add_object(self.pdf_page_object(page, node_number)),
      )
    }
    self.add_object_given_number(
      node_number,
      pdf_page_pages_node_object(page_numbers, pages.length(), parent),
    )
  } else {
    let middle_count = 5
    let left_count = (pages.length() - middle_count) / 2
    let middle_end = left_count + middle_count
    let left_number = self.add_object(PdfNull)
    self.pdf_page_add_pagetree_node(
      pdf_page_slice(pages, 0, left_count),
      node_number,
      left_number,
    )
    let kid_numbers : Array[Int] = Array::new(capacity=middle_count + 2)
    kid_numbers.push(left_number)
    for i in left_count..<middle_end {
      kid_numbers.push(
        self.add_object(self.pdf_page_object(pages[i], node_number)),
      )
    }
    let right_number = self.add_object(PdfNull)
    self.pdf_page_add_pagetree_node(
      pdf_page_slice(pages, middle_end, pages.length()),
      node_number,
      right_number,
    )
    kid_numbers.push(right_number)
    self.add_object_given_number(
      node_number,
      pdf_page_pages_node_object(kid_numbers, pages.length(), parent),
    )
  }
}

///|
/// Add a balanced page tree for `pages` and return its root object number.
///
/// Page content objects that are not already indirect are inserted into the
/// document. The document is mutated in place.
pub fn PdfDocument::add_pagetree(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
) -> Int raise PdfError {
  let page_root_number = self.add_object(PdfNull)
  self.pdf_page_add_pagetree_node(pages, 0, page_root_number)
  page_root_number
}

///|
/// Copy a document, add a page tree, and return the copy with the tree root.
pub fn pdf_add_pagetree(
  pages : ArrayView[PdfPage],
  document : PdfDocument,
) -> (PdfDocument, Int) raise PdfError {
  let pdf = document.copy()
  let page_root_number = pdf.add_pagetree(pages)
  (pdf, page_root_number)
}

///|
fn pdf_page_root_entries_without_catalog_keys(
  object : PdfObject,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match object {
    PdfNull => []
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (key, _) = entry
        if key != pdf_page_type_key() && key != pdf_page_pages_key() {
          output.push(entry)
        }
      }
      output
    }
    _ => raise DictionaryExpected
  }
}

///|
/// Add or replace the catalog root pointing at a page-tree root.
///
/// Existing catalog entries are preserved except `/Type` and `/Pages`; `extras`
/// can add or replace other catalog entries. The document trailer `/Root` is
/// updated and the document is mutated in place.
pub fn PdfDocument::add_root(
  self : PdfDocument,
  page_root_number : Int,
  extras : ArrayView[(PdfName, PdfObject)],
) -> Int raise PdfError {
  let mut root = PdfDictionary([
    (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
    (pdf_page_pages_key(), PdfIndirect(page_root_number)),
  ])
  let current_root = match self.pdf_page_active_catalog() {
    Some((catalog, _)) => catalog
    None => PdfNull
  }
  for entry in pdf_page_root_entries_without_catalog_keys(current_root) {
    let (key, value) = entry
    root = root.add_dict_entry(key, value)
  }
  for entry in extras {
    let (key, value) = entry
    if key != pdf_page_type_key() && key != pdf_page_pages_key() {
      root = root.add_dict_entry(key, value)
    }
  }
  let root_number = self.add_object(root)
  self.set_root(root_number)
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_page_root_key(), PdfIndirect(root_number)),
  )
  root_number
}

///|
/// Copy a document, add a catalog root, and return the copy.
pub fn pdf_add_root(
  page_root_number : Int,
  extras : ArrayView[(PdfName, PdfObject)],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  let pdf = document.copy()
  ignore(pdf.add_root(page_root_number, extras))
  pdf
}

///|
/// Build the smallest useful PDF document: one blank A4 page and a catalog.
pub fn pdf_minimum_valid_pdf() -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let page_root_number = document.add_pagetree([pdf_page_blank(paper_a4)])
  ignore(document.add_root(page_root_number, []))
  document
}

///|
fn pdf_page_default_mediabox() -> PdfObject {
  PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(612), PdfInteger(792)])
}

///|
fn PdfDocument::pdf_page_direct_child(
  self : PdfDocument,
  kid : PdfObject,
) -> PdfObject raise PdfError {
  match kid {
    PdfIndirect(number) => {
      let child = self.lookup_object_or_null(number)
      if child == PdfNull {
        raise PageTreeExpected
      }
      child
    }
    PdfDictionary(_) => kid
    _ => raise PageTreeExpected
  }
}

///|
fn PdfDocument::pdf_pages_of_branch(
  self : PdfDocument,
  node : PdfObject,
  inherited_resources : PdfObject?,
  inherited_mediabox : PdfObject?,
  inherited_cropbox : PdfObject?,
  inherited_rotate : PdfPageRotation,
  last_mediabox : Ref[PdfObject],
  depth : Int,
) -> Array[PdfPage] raise PdfError {
  let resources = pdf_page_inherited_object(
    self.lookup_direct(pdf_page_resources_key(), node),
    inherited_resources,
  )
  let mediabox = pdf_page_inherited_object(
    self.lookup_direct(pdf_page_mediabox_key(), node),
    inherited_mediabox,
  )
  let cropbox = pdf_page_inherited_object(
    self.lookup_direct(pdf_page_cropbox_key(), node),
    inherited_cropbox,
  )
  let rotate = self.pdf_page_inherited_rotation(node, inherited_rotate)
  match self.lookup_direct(pdf_page_kids_key(), node) {
    Some(PdfArray(kids)) => {
      let pages : Array[PdfPage] = Array::new(capacity=kids.length())
      for kid in kids {
        for
          page in self.pdf_pages_of_node(
            self.pdf_page_direct_child(kid),
            resources,
            mediabox,
            cropbox,
            rotate,
            last_mediabox,
            depth + 1,
          ) {
          pages.push(page)
        }
      }
      pages
    }
    _ => raise PageTreeExpected
  }
}

///|
fn pdf_page_inherited_object(
  current : PdfObject?,
  inherited : PdfObject?,
) -> PdfObject? {
  match current {
    Some(value) => Some(value)
    None => inherited
  }
}

///|
fn PdfDocument::pdf_page_inherited_rotation(
  self : PdfDocument,
  node : PdfObject,
  inherited : PdfPageRotation,
) -> PdfPageRotation raise PdfError {
  match self.lookup_direct(pdf_page_rotate_key(), node) {
    Some(PdfInteger(value)) => pdf_page_rotation_of_int(value)
    _ => inherited
  }
}

///|
fn PdfDocument::pdf_page_find_inherited_attribute(
  self : PdfDocument,
  object : PdfObject,
  key : PdfName,
  depth : Int,
) -> PdfObject? raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(key, object) {
    Some(_) => None
    None =>
      match self.lookup_direct(pdf_page_parent_key(), object) {
        Some(parent) =>
          match parent.lookup_immediate(key) {
            Some(value) => Some(value)
            None =>
              self.pdf_page_find_inherited_attribute(parent, key, depth + 1)
          }
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_page_replace_inherited_key(
  self : PdfDocument,
  object : PdfObject,
  key : PdfName,
) -> PdfObject? raise PdfError {
  match self.pdf_page_find_inherited_attribute(object, key, 0) {
    Some(value) => Some(object.add_dict_entry(key, value))
    None => None
  }
}

///|
/// Materialize inherited page attributes onto page dictionaries.
///
/// For each object number, inherited `/MediaBox`, `/CropBox`, `/Rotate`, and
/// `/Resources` values are copied onto the page object when available. This is
/// useful before page extraction or object-level rewriting.
pub fn PdfDocument::replace_inherit(
  self : PdfDocument,
  object_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  let keys = [
    pdf_page_mediabox_key(),
    pdf_page_cropbox_key(),
    pdf_page_rotate_key(),
    pdf_page_resources_key(),
  ]
  for number in object_numbers {
    let original = self.lookup_object_or_null(number)
    let mut updated = original
    for key in keys {
      match self.pdf_page_replace_inherited_key(updated, key) {
        Some(next) => updated = next
        None => ()
      }
    }
    if updated != original {
      self.add_object_given_number(number, updated)
    }
  }
}

///|
fn PdfDocument::pdf_page_content_object(
  self : PdfDocument,
  page : PdfObject,
) -> PdfObject? {
  match self.direct(page).lookup_immediate(pdf_page_contents_key()) {
    Some(PdfIndirect(number) as indirect) =>
      match self.lookup_object_or_null(number) {
        PdfArray(items) => Some(PdfArray(items))
        _ => Some(PdfArray([indirect]))
      }
    Some(value) => Some(value)
    None => None
  }
}

///|
fn PdfDocument::pdf_page_content_list(
  self : PdfDocument,
  contents : PdfObject?,
) -> Array[PdfObject] {
  let output : Array[PdfObject] = Array::new(
    capacity=match contents {
      Some(PdfArray(items)) => items.length()
      Some(_) => 1
      None => 0
    },
  )
  match contents {
    None => ()
    Some(PdfArray(items)) =>
      for item in items {
        match self.direct(item) {
          PdfStreamObject(_) => output.push(item)
          _ => ()
        }
      }
    Some(object) =>
      match self.direct(object) {
        PdfStreamObject(_) => output.push(object)
        _ => ()
      }
  }
  output
}

///|
fn PdfDocument::pdf_page_leaf(
  self : PdfDocument,
  page_node : PdfObject,
  inherited_resources : PdfObject?,
  inherited_mediabox : PdfObject?,
  inherited_cropbox : PdfObject?,
  inherited_rotate : PdfPageRotation,
  last_mediabox : Ref[PdfObject],
) -> PdfPage raise PdfError {
  let page = self.direct(page_node)
  let resources = match
    pdf_page_inherited_object(
      self.lookup_direct(pdf_page_resources_key(), page),
      inherited_resources,
    ) {
    Some(value) => value
    None => PdfDictionary([])
  }
  let mediabox = match
    pdf_page_inherited_object(
      self.lookup_direct(pdf_page_mediabox_key(), page),
      inherited_mediabox,
    ) {
    Some(value) => {
      last_mediabox.val = value
      value
    }
    None => last_mediabox.val
  }
  let rotate = self.pdf_page_inherited_rotation(page, inherited_rotate)
  let rest = match
    pdf_page_inherited_object(
      self.lookup_direct(pdf_page_cropbox_key(), page),
      inherited_cropbox,
    ) {
    Some(cropbox) =>
      pdf_page_rest_object_from_page(page).add_dict_entry(
        pdf_page_cropbox_key(),
        cropbox,
      )
    None => pdf_page_rest_object_from_page(page)
  }
  {
    content: self.pdf_page_content_list(self.pdf_page_content_object(page)),
    mediabox,
    resources,
    rotate,
    rest,
  }
}

///|
fn PdfDocument::pdf_pages_of_node(
  self : PdfDocument,
  node : PdfObject,
  inherited_resources : PdfObject?,
  inherited_mediabox : PdfObject?,
  inherited_cropbox : PdfObject?,
  inherited_rotate : PdfPageRotation,
  last_mediabox : Ref[PdfObject],
  depth : Int,
) -> Array[PdfPage] raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(pdf_page_type_key(), node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_pages() =>
      self.pdf_pages_of_branch(
        node, inherited_resources, inherited_mediabox, inherited_cropbox, inherited_rotate,
        last_mediabox, depth,
      )
    None =>
      match self.lookup_direct(pdf_page_kids_key(), node) {
        Some(PdfArray(_)) =>
          self.pdf_pages_of_branch(
            node, inherited_resources, inherited_mediabox, inherited_cropbox, inherited_rotate,
            last_mediabox, depth,
          )
        _ => {
          let page = self.pdf_page_leaf(
            node, inherited_resources, inherited_mediabox, inherited_cropbox, inherited_rotate,
            last_mediabox,
          )
          [page]
        }
      }
    _ => {
      let page = self.pdf_page_leaf(
        node, inherited_resources, inherited_mediabox, inherited_cropbox, inherited_rotate,
        last_mediabox,
      )
      [page]
    }
  }
}

///|
/// Read the document page tree into `PdfPage` records.
///
/// Inherited resources, media boxes, crop boxes, and rotation are resolved
/// while walking the tree. Malformed page-tree structure raises `PdfError`.
pub fn PdfDocument::pages_of_pagetree(
  self : PdfDocument,
) -> Array[PdfPage] raise PdfError {
  let last_mediabox : Ref[PdfObject] = { val: pdf_page_default_mediabox() }
  self.pdf_pages_of_node(
    pdf_page_root_pages_node(self),
    None,
    None,
    None,
    Rotate0,
    last_mediabox,
    0,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::pages_of_pagetree`.
pub fn pdf_pages_of_pagetree(
  document : PdfDocument,
) -> Array[PdfPage] raise PdfError {
  document.pages_of_pagetree()
}
