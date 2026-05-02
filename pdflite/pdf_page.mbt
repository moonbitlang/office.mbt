///|
fn pdf_page_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_page_type_key() -> PdfName {
  pdf_page_name("/Type")
}

///|
fn pdf_page_pages_key() -> PdfName {
  pdf_page_name("/Pages")
}

///|
fn pdf_page_root_key() -> PdfName {
  pdf_page_name("/Root")
}

///|
fn pdf_page_kids_key() -> PdfName {
  pdf_page_name("/Kids")
}

///|
fn pdf_page_parent_key() -> PdfName {
  pdf_page_name("/Parent")
}

///|
fn pdf_page_count_key() -> PdfName {
  pdf_page_name("/Count")
}

///|
fn pdf_page_resources_key() -> PdfName {
  pdf_page_name("/Resources")
}

///|
fn pdf_page_mediabox_key() -> PdfName {
  pdf_page_name("/MediaBox")
}

///|
fn pdf_page_cropbox_key() -> PdfName {
  pdf_page_name("/CropBox")
}

///|
fn pdf_page_rotate_key() -> PdfName {
  pdf_page_name("/Rotate")
}

///|
fn pdf_page_contents_key() -> PdfName {
  pdf_page_name("/Contents")
}

///|
fn pdf_page_names_key() -> PdfName {
  pdf_page_name("/Names")
}

///|
fn pdf_page_dests_key() -> PdfName {
  pdf_page_name("/Dests")
}

///|
fn pdf_page_annots_key() -> PdfName {
  pdf_page_name("/Annots")
}

///|
fn pdf_page_open_action_key() -> PdfName {
  pdf_page_name("/OpenAction")
}

///|
fn pdf_page_dest_key() -> PdfName {
  pdf_page_name("/Dest")
}

///|
fn pdf_page_action_key() -> PdfName {
  pdf_page_name("/A")
}

///|
fn pdf_page_subtype_key() -> PdfName {
  pdf_page_name("/Subtype")
}

///|
fn pdf_page_xobject_key() -> PdfName {
  pdf_page_name("/XObject")
}

///|
fn pdf_page_filter_key() -> PdfName {
  pdf_page_name("/Filter")
}

///|
fn pdf_page_popup_key() -> PdfName {
  pdf_page_name("/Popup")
}

///|
fn pdf_page_type_catalog() -> PdfName {
  pdf_page_name("/Catalog")
}

///|
fn pdf_page_type_pages() -> PdfName {
  pdf_page_name("/Pages")
}

///|
fn pdf_page_type_page() -> PdfName {
  pdf_page_name("/Page")
}

///|
fn pdf_page_type_link() -> PdfName {
  pdf_page_name("/Link")
}

///|
fn pdf_page_type_form() -> PdfName {
  pdf_page_name("/Form")
}

///|
fn pdf_page_resource_keys() -> Array[PdfName] {
  [
    pdf_page_name("/Font"),
    pdf_page_name("/ExtGState"),
    pdf_page_name("/ColorSpace"),
    pdf_page_name("/Pattern"),
    pdf_page_name("/Shading"),
    pdf_page_name("/XObject"),
    pdf_page_name("/Properties"),
  ]
}

///|
pub(all) enum PdfPageRotation {
  Rotate0
  Rotate90
  Rotate180
  Rotate270
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfPage {
  content : Array[PdfObject]
  mediabox : PdfObject
  resources : PdfObject
  rotate : PdfPageRotation
  rest : PdfObject
} derive(Debug, Eq, ToJson)

///|
pub fn pdf_page_int_of_rotation(rotation : PdfPageRotation) -> Int {
  match rotation {
    Rotate0 => 0
    Rotate90 => 90
    Rotate180 => 180
    Rotate270 => 270
  }
}

///|
pub fn pdf_page_rotation_of_int(value : Int) -> PdfPageRotation raise PdfError {
  match value % 360 {
    0 => Rotate0
    90 | -270 => Rotate90
    180 | -180 => Rotate180
    270 | -90 => Rotate270
    _ => raise PageRotationExpected(value)
  }
}

///|
pub fn pdf_page_rectangle_of_paper(paper : PaperSize) -> PdfObject {
  PdfArray([
    PdfReal(0.0),
    PdfReal(0.0),
    PdfReal(unit_points(paper.width(), paper.unit())),
    PdfReal(unit_points(paper.height(), paper.unit())),
  ])
}

///|
pub fn pdf_page_custom(rectangle : PdfObject) -> PdfPage {
  {
    content: [],
    mediabox: rectangle,
    resources: PdfDictionary([]),
    rotate: Rotate0,
    rest: PdfDictionary([]),
  }
}

///|
pub fn pdf_page_blank(paper : PaperSize) -> PdfPage {
  pdf_page_custom(pdf_page_rectangle_of_paper(paper))
}

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
      let output : Array[(PdfName, PdfObject)] = []
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
      let rest : Array[(PdfName, PdfObject)] = []
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
  let refs : Array[PdfObject] = []
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
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_page_type_key(), PdfNameObject(pdf_page_type_page())),
    (pdf_page_parent_key(), PdfIndirect(parent)),
    (pdf_page_resources_key(), page.resources),
    (pdf_page_mediabox_key(), page.mediabox),
  ]
  match pdf_page_int_of_rotation(page.rotate) {
    0 => ()
    value => entries.push((pdf_page_rotate_key(), PdfInteger(value)))
  }
  let content_refs = self.pdf_page_content_references(page.content)
  if content_refs.length() > 0 {
    entries.push((pdf_page_contents_key(), PdfArray(content_refs)))
  }
  for entry in pdf_page_rest_entries(page.rest) {
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
  let output : Array[PdfPage] = []
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
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())),
    (
      pdf_page_kids_key(),
      PdfArray([ for number in kids => PdfIndirect(number) ]),
    ),
    (pdf_page_count_key(), PdfInteger(count)),
  ]
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
    let page_numbers : Array[Int] = []
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
    let kid_numbers : Array[Int] = [left_number]
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
pub fn PdfDocument::add_pagetree(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
) -> Int raise PdfError {
  let page_root_number = self.add_object(PdfNull)
  self.pdf_page_add_pagetree_node(pages, 0, page_root_number)
  page_root_number
}

///|
fn pdf_page_root_entries_without_catalog_keys(
  object : PdfObject,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match object {
    PdfNull => []
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
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
  let rotate = self.pdf_page_inherited_rotation(node, inherited_rotate)
  match self.lookup_direct(pdf_page_kids_key(), node) {
    Some(PdfArray(kids)) => {
      let pages : Array[PdfPage] = []
      for kid in kids {
        for
          page in self.pdf_pages_of_node(
            self.pdf_page_direct_child(kid),
            resources,
            mediabox,
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
  let output : Array[PdfObject] = []
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
  {
    content: self.pdf_page_content_list(self.pdf_page_content_object(page)),
    mediabox,
    resources,
    rotate,
    rest: pdf_page_rest_object_from_page(page),
  }
}

///|
fn PdfDocument::pdf_pages_of_node(
  self : PdfDocument,
  node : PdfObject,
  inherited_resources : PdfObject?,
  inherited_mediabox : PdfObject?,
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
        node, inherited_resources, inherited_mediabox, inherited_rotate, last_mediabox,
        depth,
      )
    None =>
      match self.lookup_direct(pdf_page_kids_key(), node) {
        Some(PdfArray(_)) =>
          self.pdf_pages_of_branch(
            node, inherited_resources, inherited_mediabox, inherited_rotate, last_mediabox,
            depth,
          )
        _ => {
          let page = self.pdf_page_leaf(
            node, inherited_resources, inherited_mediabox, inherited_rotate, last_mediabox,
          )
          [page]
        }
      }
    _ => {
      let page = self.pdf_page_leaf(
        node, inherited_resources, inherited_mediabox, inherited_rotate, last_mediabox,
      )
      [page]
    }
  }
}

///|
pub fn PdfDocument::pages_of_pagetree(
  self : PdfDocument,
) -> Array[PdfPage] raise PdfError {
  let last_mediabox : Ref[PdfObject] = { val: pdf_page_default_mediabox() }
  self.pdf_pages_of_node(
    pdf_page_root_pages_node(self),
    None,
    None,
    Rotate0,
    last_mediabox,
    0,
  )
}

///|
fn pdf_page_concat_ops(
  first : ArrayView[PdfContentOp],
  second : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in first {
    output.push(op)
  }
  for op in second {
    output.push(op)
  }
  output
}

///|
fn pdf_page_concat3_ops(
  first : ArrayView[PdfContentOp],
  second : ArrayView[PdfContentOp],
  third : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  pdf_page_concat_ops(pdf_page_concat_ops(first, second), third)
}

///|
pub fn pdf_page_protect(ops : ArrayView[PdfContentOp]) -> Array[PdfContentOp] {
  let mut saves = 0
  let mut restores = 0
  for op in ops {
    match op {
      Op_q => saves += 1
      Op_Q => restores += 1
      _ => ()
    }
  }
  let output : Array[PdfContentOp] = []
  if saves > restores {
    for _ in 0..<(saves - restores) {
      output.push(Op_Q)
    }
  }
  output
}

///|
fn PdfDocument::pdf_page_parse_content_ops(
  self : PdfDocument,
  resources : PdfObject,
  content : ArrayView[PdfObject],
) -> Array[PdfContentOp] raise PdfError {
  self.parse_content_ops_with_resources(resources, content) catch {
    DictionaryKeyNotFound(_) | ColourSpaceExpected =>
      self.parse_content_ops(content)
    error => raise error
  }
}

///|
pub fn PdfDocument::prepend_operators(
  self : PdfDocument,
  page : PdfPage,
  ops : ArrayView[PdfContentOp],
  fast? : Bool = false,
) -> PdfPage raise PdfError {
  if fast {
    { ..page, content: [pdf_content_stream_of_ops(ops), ..page.content] }
  } else {
    let old_ops = self.pdf_page_parse_content_ops(page.resources, page.content)
    {
      ..page,
      content: [pdf_content_stream_of_ops(pdf_page_concat_ops(ops, old_ops))],
    }
  }
}

///|
pub fn PdfDocument::postpend_operators(
  self : PdfDocument,
  page : PdfPage,
  ops : ArrayView[PdfContentOp],
  fast? : Bool = false,
) -> PdfPage raise PdfError {
  if fast {
    {
      ..page,
      content: [
        ..page.content,
        pdf_content_stream_of_ops(pdf_page_concat3_ops([Op_q], ops, [Op_Q])),
      ],
    }
  } else {
    let existing_ops = self.pdf_page_parse_content_ops(
      page.resources,
      page.content,
    )
    if existing_ops.length() == 0 {
      { ..page, content: [pdf_content_stream_of_ops(ops)] }
    } else {
      let before_ops : Array[PdfContentOp] = [Op_q]
      let after_ops = pdf_page_concat3_ops(
        pdf_page_protect(existing_ops),
        [Op_Q],
        ops,
      )
      {
        ..page,
        content: [
          pdf_content_stream_of_ops(
            pdf_page_concat3_ops(before_ops, existing_ops, after_ops),
          ),
        ],
      }
    }
  }
}

///|
fn pdf_page_changed_reference(
  changes : ArrayView[(Int, Int)],
  number : Int,
) -> Int {
  for change in changes {
    let (old_number, new_number) = change
    if number == old_number {
      break new_number
    }
  } nobreak {
    number
  }
}

///|
fn pdf_page_renumber_object(
  object : PdfObject,
  changes : ArrayView[(Int, Int)],
) -> PdfObject {
  match object {
    PdfIndirect(number) =>
      PdfIndirect(pdf_page_changed_reference(changes, number))
    PdfArray(items) => {
      let output : Array[PdfObject] = []
      for item in items {
        output.push(pdf_page_renumber_object(item, changes))
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (key, value) = entry
        output.push((key, pdf_page_renumber_object(value, changes)))
      }
      PdfDictionary(output)
    }
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: pdf_page_renumber_object(stream.dictionary, changes),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn pdf_page_renumber_entry(
  entry : PdfObjectEntry,
  changes : ArrayView[(Int, Int)],
) -> PdfObjectEntry {
  match entry.data {
    ObjectParsed(object) =>
      {
        data: ObjectParsed(pdf_page_renumber_object(object, changes)),
        generation: entry.generation,
      }
    ObjectParsedAlreadyDecrypted(object) =>
      {
        data: ObjectParsedAlreadyDecrypted(
          pdf_page_renumber_object(object, changes),
        ),
        generation: entry.generation,
      }
    _ => { data: entry.data, generation: entry.generation }
  }
}

///|
fn PdfDocument::pdf_page_renumber_references(
  self : PdfDocument,
  changes : ArrayView[(Int, Int)],
) -> Unit {
  for number in self.object_numbers() {
    let entry = self.objects.get_entry(number).unwrap()
    self.objects.set_entry(number, pdf_page_renumber_entry(entry, changes))
  }
}

///|
fn pdf_page_reference_changes(
  old_numbers : ArrayView[Int],
  new_numbers : ArrayView[Int],
) -> Array[(Int, Int)] raise PdfError {
  if old_numbers.length() != new_numbers.length() {
    raise PageTreeExpected
  }
  let changes : Array[(Int, Int)] = []
  for i in 0..<old_numbers.length() {
    changes.push((old_numbers[i], new_numbers[i]))
  }
  changes
}

///|
fn pdf_page_reference_changes_from_serials(
  old_numbers : ArrayView[Int],
  new_numbers : ArrayView[Int],
  changes : ArrayView[(Int, Int)],
) -> Array[(Int, Int)] raise PdfError {
  let output : Array[(Int, Int)] = []
  for change in changes {
    let (old_page, new_page) = change
    if old_page < 1 ||
      old_page > old_numbers.length() ||
      new_page < 1 ||
      new_page > new_numbers.length() {
      raise PageTreeExpected
    }
    output.push((old_numbers[old_page - 1], new_numbers[new_page - 1]))
  }
  output
}

///|
fn pdf_page_matrix_for_page_number(
  matrices : ArrayView[(Int, TransformMatrix)],
  page_number : Int,
) -> TransformMatrix? {
  for entry in matrices {
    let (matrix_page_number, matrix) = entry
    if matrix_page_number == page_number {
      break Some(matrix)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_page_matrix_page_number_of_target(
  page_reference_numbers : ArrayView[Int],
  target : PdfTargetPage,
) -> Int {
  match target {
    TargetPageObject(object_number) =>
      for index in 0..<page_reference_numbers.length() {
        if page_reference_numbers[index] == object_number {
          break index + 1
        }
      } nobreak {
        0
      }
    TargetOtherDocPageNumber(_) => 0
  }
}

///|
fn PdfDocument::pdf_page_matrix_for_destination(
  self : PdfDocument,
  destination : PdfDestination,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> TransformMatrix? raise PdfError {
  let page_number = self.pdf_page_matrix_page_number_for_destination(
    destination, page_reference_numbers,
  )
  if page_number == 0 {
    None
  } else {
    pdf_page_matrix_for_page_number(matrices, page_number)
  }
}

///|
fn PdfDocument::pdf_page_matrix_page_number_for_destination(
  self : PdfDocument,
  destination : PdfDestination,
  page_reference_numbers : ArrayView[Int],
) -> Int raise PdfError {
  match destination {
    DestNamed(_) | DestString(_) => {
      let resolved = self.read_destination(
        pdf_object_of_destination(destination),
      )
      if resolved == destination {
        0
      } else {
        self.pdf_page_matrix_page_number_for_destination(
          resolved, page_reference_numbers,
        )
      }
    }
    DestAction(action) =>
      match
        (
          self.lookup_direct(pdf_dest_s_key(), action),
          self.lookup_direct(pdf_dest_d_key(), action),
        ) {
        (Some(PdfNameObject(name)), Some(raw_destination)) if name ==
          pdf_dest_goto_name() =>
          self.pdf_page_matrix_page_number_for_destination(
            self.read_destination(raw_destination),
            page_reference_numbers,
          )
        _ => 0
      }
    DestXYZ(target, _, _, _)
    | DestFitH(target, _)
    | DestFitV(target, _)
    | DestFitR(target, _, _, _, _)
    | DestFitBH(target, _)
    | DestFitBV(target, _) =>
      pdf_page_matrix_page_number_of_target(page_reference_numbers, target)
    _ => 0
  }
}

///|
fn PdfDocument::pdf_page_transform_destination_object(
  self : PdfDocument,
  raw_destination : PdfObject,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> PdfObject? raise PdfError {
  match
    self.pdf_page_transform_destination_object_with_shallow(
      raw_destination, matrices, page_reference_numbers, false,
    ) {
    Some(destination) => Some(PdfIndirect(self.add_object(destination)))
    None => None
  }
}

///|
fn PdfDocument::pdf_page_transform_destination_object_with_shallow(
  self : PdfDocument,
  raw_destination : PdfObject,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
  shallow : Bool,
) -> PdfObject? raise PdfError {
  let destination = self.read_destination(raw_destination, shallow~)
  match
    self.pdf_page_matrix_for_destination(
      destination, matrices, page_reference_numbers,
    ) {
    Some(matrix) if matrix != transform_identity_matrix =>
      Some(
        pdf_object_of_destination(
          self.transform_destination(matrix, destination),
        ),
      )
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_transform_catalog_destinations_object(
  self : PdfDocument,
  dests : PdfObject,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> PdfObject? raise PdfError {
  match dests {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      let mut changed = false
      for entry in entries {
        let (key, destination) = entry
        match
          self.pdf_page_transform_destination_object_with_shallow(
            destination, matrices, page_reference_numbers, true,
          ) {
          Some(transformed) => {
            output.push((key, transformed))
            changed = true
          }
          None => output.push(entry)
        }
      }
      if changed {
        Some(PdfDictionary(output))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_active_catalog(
  self : PdfDocument,
) -> (PdfObject, Bool)? {
  let uses_trailer_root = self
    .trailer_dict()
    .lookup_immediate(pdf_page_root_key())
    is Some(_)
  Some((self.catalog(), uses_trailer_root)) catch {
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_replace_active_catalog_entry(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  catalog : PdfObject,
  uses_trailer_root : Bool,
) -> Unit raise PdfError {
  if uses_trailer_root {
    self.replace_chain([pdf_page_root_key(), key], value)
  } else {
    self.add_object_given_number(
      self.root(),
      catalog.add_dict_entry(key, value),
    )
  }
}

///|
fn PdfDocument::pdf_page_transform_catalog_destinations_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_dests_key()) {
        Some(PdfIndirect(dests_number)) =>
          match
            self.pdf_page_transform_catalog_destinations_object(
              self.lookup_object_or_null(dests_number),
              matrices,
              page_reference_numbers,
            ) {
            Some(dests) => self.add_object_given_number(dests_number, dests)
            None => ()
          }
        Some(dests) =>
          match
            self.pdf_page_transform_catalog_destinations_object(
              dests, matrices, page_reference_numbers,
            ) {
            Some(transformed) =>
              self.pdf_page_replace_active_catalog_entry(
                pdf_page_dests_key(),
                transformed,
                root_object,
                uses_trailer_root,
              )
            None => ()
          }
        None => ()
      }
    None => ()
  }
}

///|
fn PdfDocument::pdf_page_transform_name_tree_destination_entries(
  self : PdfDocument,
  dests_tree : PdfObject,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Array[(PdfBytes, PdfObject)]? raise PdfError {
  let output : Array[(PdfBytes, PdfObject)] = []
  let mut changed = false
  for entry in self.read_name_tree(dests_tree) {
    let (key, destination) = entry
    match
      self.pdf_page_transform_destination_object_with_shallow(
        destination, matrices, page_reference_numbers, true,
      ) {
      Some(transformed) => {
        output.push((key, transformed))
        changed = true
      }
      None => output.push(entry)
    }
  }
  if changed {
    Some(output)
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_page_transform_destination_name_tree_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_names_key()) {
        Some(PdfIndirect(names_number)) => {
          let names_object = self.lookup_object_or_null(names_number)
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              match
                self.pdf_page_transform_name_tree_destination_entries(
                  dests_tree, matrices, page_reference_numbers,
                ) {
                Some(entries) =>
                  self.add_object_given_number(
                    names_number,
                    names_object.add_dict_entry(
                      pdf_page_dests_key(),
                      self.build_name_tree(entries),
                    ),
                  )
                None => ()
              }
            None => ()
          }
        }
        Some(PdfDictionary(_) as names_object) =>
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              match
                self.pdf_page_transform_name_tree_destination_entries(
                  dests_tree, matrices, page_reference_numbers,
                ) {
                Some(entries) =>
                  self.pdf_page_replace_active_catalog_entry(
                    pdf_page_names_key(),
                    names_object.add_dict_entry(
                      pdf_page_dests_key(),
                      self.build_name_tree(entries),
                    ),
                    root_object,
                    uses_trailer_root,
                  )
                None => ()
              }
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_page_transform_action_object(
  self : PdfDocument,
  raw_action : PdfObject,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> PdfObject? raise PdfError {
  let action = self.direct(raw_action)
  match
    (
      self.lookup_direct(pdf_dest_s_key(), action),
      action.lookup_immediate(pdf_dest_d_key()),
    ) {
    (Some(PdfNameObject(name)), Some(raw_destination)) if name ==
      pdf_dest_goto_name() =>
      match
        self.pdf_page_transform_destination_object(
          raw_destination, matrices, page_reference_numbers,
        ) {
        Some(destination) =>
          Some(action.add_dict_entry(pdf_dest_d_key(), destination))
        None => None
      }
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_transform_bookmarks_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let bookmarks = self.read_bookmarks(preserve_actions=true)
  let output : Array[PdfBookmark] = []
  let mut changed = false
  for bookmark in bookmarks {
    let target = match
      self.pdf_page_matrix_for_destination(
        bookmark.target,
        matrices,
        page_reference_numbers,
      ) {
      Some(matrix) if matrix != transform_identity_matrix => {
        changed = true
        self.transform_destination(matrix, bookmark.target)
      }
      _ => bookmark.target
    }
    output.push({ ..bookmark, target, })
  }
  if changed {
    self.add_bookmarks(output)
  } else {
    self
  }
}

///|
fn PdfDocument::pdf_page_transform_link_annotation_for_matrices(
  self : PdfDocument,
  annotation_number : Int,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  let annotation = self.lookup_object_or_null(annotation_number)
  match
    self.pdf_page_transform_link_annotation_object_for_matrices(
      annotation, matrices, page_reference_numbers,
    ) {
    Some(updated) => self.add_object_given_number(annotation_number, updated)
    None => ()
  }
}

///|
fn PdfDocument::pdf_page_transform_link_annotation_object_for_matrices(
  self : PdfDocument,
  annotation : PdfObject,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> PdfObject? raise PdfError {
  match self.lookup_direct(pdf_page_subtype_key(), annotation) {
    Some(PdfNameObject(kind)) if kind == pdf_page_type_link() =>
      match annotation.lookup_immediate(pdf_page_dest_key()) {
        Some(raw_destination) =>
          match
            self.pdf_page_transform_destination_object(
              raw_destination, matrices, page_reference_numbers,
            ) {
            Some(destination) =>
              Some(annotation.add_dict_entry(pdf_page_dest_key(), destination))
            None => None
          }
        None =>
          match annotation.lookup_immediate(pdf_page_action_key()) {
            Some(raw_action) =>
              match
                self.pdf_page_transform_action_object(
                  raw_action, matrices, page_reference_numbers,
                ) {
                Some(action) =>
                  Some(annotation.add_dict_entry(pdf_page_action_key(), action))
                None => None
              }
            None => None
          }
      }
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_transform_link_annotations_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  for page_number in self.page_reference_numbers() {
    let page_object = self.lookup_object_or_null(page_number)
    match self.lookup_direct(pdf_page_annots_key(), page_object) {
      Some(PdfArray(annotations)) =>
        for index in 0..<annotations.length() {
          match annotations[index] {
            PdfIndirect(annotation_number) =>
              self.pdf_page_transform_link_annotation_for_matrices(
                annotation_number, matrices, page_reference_numbers,
              )
            PdfDictionary(_) as annotation =>
              match
                self.pdf_page_transform_link_annotation_object_for_matrices(
                  annotation, matrices, page_reference_numbers,
                ) {
                Some(updated) => annotations[index] = updated
                None => ()
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn PdfDocument::pdf_page_transform_open_action_for_matrices(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_open_action_key()) {
        Some(raw_open_action) =>
          match self.direct(raw_open_action) {
            PdfArray(_) as raw_destination =>
              match
                self.pdf_page_transform_destination_object(
                  raw_destination, matrices, page_reference_numbers,
                ) {
                Some(destination) =>
                  self.pdf_page_replace_active_catalog_entry(
                    pdf_page_open_action_key(),
                    destination,
                    root_object,
                    uses_trailer_root,
                  )
                None => ()
              }
            PdfDictionary(_) as raw_action =>
              match
                self.pdf_page_transform_action_object(
                  raw_action, matrices, page_reference_numbers,
                ) {
                Some(action) =>
                  self.pdf_page_replace_active_catalog_entry(
                    pdf_page_open_action_key(),
                    action,
                    root_object,
                    uses_trailer_root,
                  )
                None => ()
              }
            _ => ()
          }
        None => ()
      }
    None => ()
  }
}

///|
fn PdfDocument::pdf_page_transform_matrix_destinations(
  self : PdfDocument,
  matrices : ArrayView[(Int, TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
  transform_bookmarks : Bool,
) -> PdfDocument raise PdfError {
  let pdf = if transform_bookmarks {
    self.pdf_page_transform_bookmarks_for_matrices(
      matrices, page_reference_numbers,
    )
  } else {
    self
  }
  pdf.pdf_page_transform_link_annotations_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf.pdf_page_transform_open_action_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf.pdf_page_transform_catalog_destinations_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf.pdf_page_transform_destination_name_tree_for_matrices(
    matrices, page_reference_numbers,
  )
  pdf
}

///|
pub fn PdfDocument::change_pages(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
  change_references? : Bool = false,
  matrices? : ArrayView[(Int, TransformMatrix)] = [],
  changes? : ArrayView[(Int, Int)] = [],
) -> PdfDocument raise PdfError {
  let old_page_numbers = self.page_reference_numbers()
  let pdf = self.copy()
  let page_root_number = pdf.add_pagetree(pages)
  ignore(pdf.add_root(page_root_number, []))
  if change_references {
    let new_page_numbers = pdf.page_reference_numbers()
    let reference_changes = if changes.length() > 0 {
      pdf_page_reference_changes_from_serials(
        old_page_numbers, new_page_numbers, changes,
      )
    } else if old_page_numbers.length() != new_page_numbers.length() {
      []
    } else {
      pdf_page_reference_changes(old_page_numbers, new_page_numbers)
    }
    pdf.pdf_page_renumber_references(reference_changes)
    if matrices.length() > 0 {
      pdf.pdf_page_transform_matrix_destinations(
        matrices,
        new_page_numbers,
        old_page_numbers.length() == new_page_numbers.length(),
      )
    } else {
      pdf
    }
  } else {
    pdf
  }
}

///|
fn pdf_page_select_pages(
  pages : ArrayView[PdfPage],
  page_numbers : ArrayView[Int],
) -> Array[PdfPage] raise PdfError {
  if page_numbers.length() == 0 {
    raise PageTreeExpected
  }
  let selected : Array[PdfPage] = []
  for page_number in page_numbers {
    if page_number < 1 || page_number > pages.length() {
      raise PageTreeExpected
    }
    selected.push(pages[page_number - 1])
  }
  selected
}

///|
fn pdf_page_select_numbers(
  numbers : ArrayView[Int],
  page_numbers : ArrayView[Int],
) -> Array[Int] raise PdfError {
  if page_numbers.length() == 0 {
    raise PageTreeExpected
  }
  let selected : Array[Int] = []
  for page_number in page_numbers {
    if page_number < 1 || page_number > numbers.length() {
      raise PageTreeExpected
    }
    selected.push(numbers[page_number - 1])
  }
  selected
}

///|
fn pdf_page_number_index(numbers : ArrayView[Int], number : Int) -> Int? {
  for i in 0..<numbers.length() {
    if numbers[i] == number {
      break Some(i)
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::pdf_page_annotation_numbers(
  self : PdfDocument,
  page_object : PdfObject,
) -> Array[Int] {
  let annots_object = match
    page_object.lookup_immediate(pdf_page_annots_key()) {
    Some(PdfIndirect(number)) => self.lookup_object_or_null(number)
    Some(value) => value
    None => PdfNull
  }
  let numbers : Array[Int] = []
  match annots_object {
    PdfArray(items) =>
      for item in items {
        match item {
          PdfIndirect(number) => numbers.push(number)
          _ => ()
        }
      }
    _ => ()
  }
  numbers
}

///|
fn pdf_page_fixup_annotation_link(
  object : PdfObject,
  key : PdfName,
  old_numbers : ArrayView[Int],
  new_numbers : ArrayView[Int],
) -> PdfObject raise PdfError {
  match object.lookup_immediate(key) {
    Some(PdfIndirect(old_number)) =>
      match pdf_page_number_index(old_numbers, old_number) {
        Some(index) =>
          object.add_dict_entry(key, PdfIndirect(new_numbers[index]))
        None => object
      }
    _ => object
  }
}

///|
fn PdfDocument::pdf_page_fixup_annotation_links(
  self : PdfDocument,
  old_numbers : ArrayView[Int],
  new_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  for number in new_numbers {
    let object = self.lookup_object_or_null(number)
    let with_popup = pdf_page_fixup_annotation_link(
      object,
      pdf_page_popup_key(),
      old_numbers,
      new_numbers,
    )
    let with_parent = pdf_page_fixup_annotation_link(
      with_popup,
      pdf_page_parent_key(),
      old_numbers,
      new_numbers,
    )
    if with_parent != object {
      self.add_object_given_number(number, with_parent)
    }
  }
}

///|
fn PdfDocument::pdf_page_fixup_duplicate_annots(
  self : PdfDocument,
) -> Unit raise PdfError {
  let page_numbers = self.page_reference_numbers()
  let existing_annots : Array[Array[Int]] = []
  for page_number in page_numbers {
    existing_annots.push(
      self.pdf_page_annotation_numbers(self.lookup_object_or_null(page_number)),
    )
  }
  let seen : Array[Int] = []
  let new_annots : Array[Array[Int]] = []
  for annots in existing_annots {
    let page_annots : Array[Int] = []
    for annotation_number in annots {
      if pdf_page_number_member(seen, annotation_number) {
        page_annots.push(
          self.add_object(self.lookup_object_or_null(annotation_number)),
        )
      } else {
        page_annots.push(annotation_number)
      }
    }
    for annotation_number in annots {
      seen.push(annotation_number)
    }
    for annotation_number in page_annots {
      seen.push(annotation_number)
    }
    new_annots.push(page_annots)
  }
  for i in 0..<new_annots.length() {
    let annots = new_annots[i]
    if annots.length() > 0 {
      self.pdf_page_fixup_annotation_links(existing_annots[i], annots)
      self.add_object_given_number(
        page_numbers[i],
        self
        .lookup_object_or_null(page_numbers[i])
        .add_dict_entry(
          pdf_page_annots_key(),
          PdfArray([ for number in annots => PdfIndirect(number) ]),
        ),
      )
    }
  }
}

///|
fn PdfDocument::pdf_page_destination_was_nulled(
  self : PdfDocument,
  destination : PdfObject,
) -> Bool {
  match self.direct(destination) {
    PdfArray(items) if items.length() > 0 =>
      match items[0] {
        PdfNull => true
        PdfIndirect(number) => self.lookup_object_or_null(number) == PdfNull
        _ => false
      }
    _ => false
  }
}

///|
fn PdfDocument::pdf_page_live_destinations(
  self : PdfDocument,
  dests_tree : PdfObject,
) -> Array[(PdfBytes, PdfObject)] {
  let output : Array[(PdfBytes, PdfObject)] = []
  for entry in self.read_name_tree(dests_tree) {
    let (_, destination) = entry
    if !self.pdf_page_destination_was_nulled(destination) {
      output.push(entry)
    }
  }
  output
}

///|
fn PdfDocument::pdf_page_live_catalog_destinations(
  self : PdfDocument,
  dests : PdfObject,
) -> PdfObject {
  match dests {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (_, destination) = entry
        if !self.pdf_page_destination_was_nulled(destination) {
          output.push(entry)
        }
      }
      PdfDictionary(output)
    }
    _ => dests
  }
}

///|
fn PdfDocument::pdf_page_fixup_catalog_destinations(
  self : PdfDocument,
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_dests_key()) {
        Some(PdfIndirect(dests_number)) =>
          self.add_object_given_number(
            dests_number,
            self.pdf_page_live_catalog_destinations(
              self.lookup_object_or_null(dests_number),
            ),
          )
        Some(dests) =>
          self.pdf_page_replace_active_catalog_entry(
            pdf_page_dests_key(),
            self.pdf_page_live_catalog_destinations(dests),
            root_object,
            uses_trailer_root,
          )
        None => ()
      }
    None => ()
  }
}

///|
fn PdfDocument::pdf_page_fixup_destination_name_tree(
  self : PdfDocument,
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_names_key()) {
        Some(PdfIndirect(names_number)) => {
          let names_object = self.lookup_object_or_null(names_number)
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              self.add_object_given_number(
                names_number,
                names_object.add_dict_entry(
                  pdf_page_dests_key(),
                  self.build_name_tree(
                    self.pdf_page_live_destinations(dests_tree),
                  ),
                ),
              )
            None => ()
          }
        }
        Some(PdfDictionary(_) as names_object) =>
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              self.pdf_page_replace_active_catalog_entry(
                pdf_page_names_key(),
                names_object.add_dict_entry(
                  pdf_page_dests_key(),
                  self.build_name_tree(
                    self.pdf_page_live_destinations(dests_tree),
                  ),
                ),
                root_object,
                uses_trailer_root,
              )
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn pdf_page_root_pages_number(pdf : PdfDocument) -> Int raise PdfError {
  let root = match pdf.pdf_page_active_catalog() {
    Some((catalog, _)) => catalog
    None => raise RootExpected
  }
  match root.lookup_immediate(pdf_page_pages_key()) {
    Some(PdfIndirect(number)) => number
    _ => raise PageTreeExpected
  }
}

///|
fn PdfDocument::pdf_page_tree_nodes_not_pages_inner(
  self : PdfDocument,
  node : PdfObject,
  node_number : Int,
  depth : Int,
) -> Array[Int] raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(pdf_page_type_key(), node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_page() => []
    _ =>
      match self.lookup_direct(pdf_page_kids_key(), node) {
        Some(PdfArray(kids)) => {
          let nodes : Array[Int] = [node_number]
          for kid in kids {
            match kid {
              PdfIndirect(number) =>
                for
                  nested in self.pdf_page_tree_nodes_not_pages_inner(
                    self.direct(kid),
                    number,
                    depth + 1,
                  ) {
                  nodes.push(nested)
                }
              _ => ()
            }
          }
          nodes
        }
        _ => []
      }
  }
}

///|
fn PdfDocument::pdf_page_tree_nodes_not_pages(
  self : PdfDocument,
) -> Array[Int] raise PdfError {
  let pages_number = pdf_page_root_pages_number(self)
  self.pdf_page_tree_nodes_not_pages_inner(
    self.lookup_object_or_null(pages_number),
    pages_number,
    0,
  )
}

///|
fn PdfDocument::pdf_page_reference_numbers_unordered_inner(
  self : PdfDocument,
  node : PdfObject,
  node_number : Int,
  depth : Int,
) -> Array[Int] raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(pdf_page_type_key(), node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_page() => [node_number]
    _ =>
      match self.lookup_direct(pdf_page_kids_key(), node) {
        Some(PdfArray(kids)) => {
          let numbers : Array[Int] = []
          for kid in kids {
            match kid {
              PdfIndirect(number) =>
                for
                  page_number in self.pdf_page_reference_numbers_unordered_inner(
                    self.direct(kid),
                    number,
                    depth + 1,
                  ) {
                  numbers.push(page_number)
                }
              _ => ()
            }
          }
          numbers
        }
        _ => [node_number]
      }
  }
}

///|
fn PdfDocument::pdf_page_reference_numbers_unordered(
  self : PdfDocument,
) -> Array[Int] raise PdfError {
  let pages_number = pdf_page_root_pages_number(self)
  self.pdf_page_reference_numbers_unordered_inner(
    self.lookup_object_or_null(pages_number),
    pages_number,
    0,
  )
}

///|
fn pdf_page_first_duplicate_number(numbers : ArrayView[Int]) -> Int? {
  let sorted = numbers.to_owned()
  sorted.sort()
  for i in 1..<sorted.length() {
    if sorted[i - 1] == sorted[i] {
      break Some(sorted[i])
    }
  } nobreak {
    None
  }
}

///|
fn pdf_page_rewrite_first_kid(
  kids : ArrayView[PdfObject],
  old_number : Int,
  new_number : Int,
) -> (Array[PdfObject], Bool) {
  let output : Array[PdfObject] = []
  let mut rewritten = false
  for kid in kids {
    match kid {
      PdfIndirect(number) if !rewritten && number == old_number => {
        output.push(PdfIndirect(new_number))
        rewritten = true
      }
      _ => output.push(kid)
    }
  }
  (output, rewritten)
}

///|
fn PdfDocument::pdf_page_rewrite_first_indirect(
  self : PdfDocument,
  node_number : Int,
  old_number : Int,
  new_number : Int,
) -> Bool raise PdfError {
  let node = self.lookup_object_or_null(node_number)
  match node.lookup_immediate(pdf_page_kids_key()) {
    Some(PdfArray(kids)) => {
      let (rewritten_kids, rewritten) = pdf_page_rewrite_first_kid(
        kids, old_number, new_number,
      )
      if rewritten {
        self.add_object_given_number(
          node_number,
          node.add_dict_entry(pdf_page_kids_key(), PdfArray(rewritten_kids)),
        )
      }
      rewritten
    }
    _ => false
  }
}

///|
fn PdfDocument::pdf_page_rewrite_page_tree_first(
  self : PdfDocument,
  nodes : ArrayView[Int],
  page_number : Int,
) -> Unit raise PdfError {
  let new_number = self.add_object(self.lookup_object_or_null(page_number))
  let mut rewritten = false
  for node_number in nodes {
    if !rewritten {
      rewritten = self.pdf_page_rewrite_first_indirect(
        node_number, page_number, new_number,
      )
    }
  }
  if !rewritten {
    self.remove_object(new_number)
    raise PageTreeExpected
  }
}

///|
fn PdfDocument::pdf_page_fixup_duplicate_pages(
  self : PdfDocument,
) -> Unit raise PdfError {
  let nodes = self.pdf_page_tree_nodes_not_pages()
  let mut done = false
  while !done {
    match
      pdf_page_first_duplicate_number(
        self.pdf_page_reference_numbers_unordered(),
      ) {
      Some(page_number) =>
        self.pdf_page_rewrite_page_tree_first(nodes, page_number)
      None => done = true
    }
  }
}

///|
fn PdfDocument::pdf_page_fixup_parents_inner(
  self : PdfDocument,
  parent_number : Int,
  node_number : Int,
  depth : Int,
) -> Unit raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  let node = self.lookup_object_or_null(node_number)
  match node.lookup_immediate(pdf_page_parent_key()) {
    Some(PdfIndirect(_)) =>
      self.add_object_given_number(
        node_number,
        node.add_dict_entry(pdf_page_parent_key(), PdfIndirect(parent_number)),
      )
    _ => ()
  }
  match self.lookup_direct(pdf_page_kids_key(), node) {
    Some(PdfArray(kids)) =>
      for kid in kids {
        match kid {
          PdfIndirect(number) =>
            self.pdf_page_fixup_parents_inner(node_number, number, depth + 1)
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_page_fixup_parents(
  self : PdfDocument,
) -> Unit raise PdfError {
  self.pdf_page_fixup_parents_inner(0, pdf_page_root_pages_number(self), 0)
}

///|
pub fn PdfDocument::pdf_of_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  retain_numbering? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  let source = self.copy()
  let all_page_numbers = source.page_reference_numbers()
  let old_page_numbers = pdf_page_select_numbers(all_page_numbers, page_numbers)
  source.replace_inherit(old_page_numbers)
  let has_page_labels = source.pdf_page_label_has_labels()
  let retained_page_labels = if retain_numbering && has_page_labels {
    pdf_page_label_merge([source], [
      [
        for page_number in page_numbers => page_number
      ],
    ])
  } else {
    []
  }
  let has_bookmarks = source.pdf_bookmark_has_outlines()
  let retained_bookmarks = if has_bookmarks {
    source.pdf_bookmarks_for_pages(page_numbers)
  } else {
    []
  }
  let selected = pdf_page_select_pages(source.pages_of_pagetree(), page_numbers)
  let deleted_page_numbers = if process_struct_tree {
    pdf_page_deleted_numbers(all_page_numbers, old_page_numbers)
  } else {
    []
  }
  let pdf = source.change_pages(selected)
  let pdf = if has_bookmarks {
    pdf.add_bookmarks(retained_bookmarks)
  } else {
    pdf
  }
  pdf.pdf_page_renumber_references(
    pdf_page_reference_changes(old_page_numbers, pdf.page_reference_numbers()),
  )
  if process_struct_tree {
    pdf.pdf_structure_trim_deleted_pages(deleted_page_numbers)
  }
  pdf.pdf_page_fixup_duplicate_pages()
  pdf.pdf_page_fixup_parents()
  pdf.pdf_page_fixup_duplicate_annots()
  pdf.remove_unreferenced()
  pdf.pdf_page_fixup_destination_name_tree()
  pdf.pdf_page_fixup_catalog_destinations()
  let pdf = if has_page_labels {
    if retain_numbering {
      pdf.write_page_labels(retained_page_labels)
    } else {
      pdf.remove_page_labels()
    }
  } else {
    pdf
  }
  pdf.remove_unreferenced()
  pdf
}

///|
fn pdf_page_number_member(numbers : ArrayView[Int], number : Int) -> Bool {
  for candidate in numbers {
    if candidate == number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_page_deleted_numbers(
  all_page_numbers : ArrayView[Int],
  active_page_numbers : ArrayView[Int],
) -> Array[Int] {
  let deleted : Array[Int] = []
  for number in all_page_numbers {
    if !pdf_page_number_member(active_page_numbers, number) {
      deleted.push(number)
    }
  }
  deleted
}

///|
fn PdfDocument::pdf_page_object_numbers_in_map(
  self : PdfDocument,
) -> Array[Int] {
  let page_numbers : Array[Int] = []
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    match object.lookup_immediate(pdf_page_type_key()) {
      Some(PdfNameObject(name)) if name == pdf_page_type_page() =>
        page_numbers.push(number)
      _ => ()
    }
  }
  page_numbers
}

///|
fn pdf_page_nullify_references(
  object : PdfObject,
  deleted_pages : ArrayView[Int],
) -> PdfObject {
  match object {
    PdfIndirect(number) if pdf_page_number_member(deleted_pages, number) =>
      PdfNull
    PdfArray(items) => {
      let output : Array[PdfObject] = []
      for item in items {
        output.push(pdf_page_nullify_references(item, deleted_pages))
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (key, value) = entry
        output.push((key, pdf_page_nullify_references(value, deleted_pages)))
      }
      PdfDictionary(output)
    }
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: pdf_page_nullify_references(
          stream.dictionary,
          deleted_pages,
        ),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn pdf_page_nullify_entry(
  entry : PdfObjectEntry,
  deleted_pages : ArrayView[Int],
) -> PdfObjectEntry {
  match entry.data {
    ObjectParsed(object) =>
      {
        data: ObjectParsed(pdf_page_nullify_references(object, deleted_pages)),
        generation: entry.generation,
      }
    ObjectParsedAlreadyDecrypted(object) =>
      {
        data: ObjectParsedAlreadyDecrypted(
          pdf_page_nullify_references(object, deleted_pages),
        ),
        generation: entry.generation,
      }
    _ => { data: entry.data, generation: entry.generation }
  }
}

///|
fn PdfDocument::pdf_page_nullify_deleted_page_references(
  self : PdfDocument,
) -> Unit raise PdfError {
  let page_numbers = self.pdf_page_object_numbers_in_map()
  let active_page_numbers = self.page_reference_numbers()
  if page_numbers.length() != active_page_numbers.length() {
    let deleted_pages = pdf_page_deleted_numbers(
      page_numbers, active_page_numbers,
    )
    for number in self.object_numbers() {
      let entry = self.objects.get_entry(number).unwrap()
      self.objects.set_entry(
        number,
        pdf_page_nullify_entry(entry, deleted_pages),
      )
    }
  }
}

///|
fn PdfDocument::pdf_referenced_from_object(
  self : PdfDocument,
  found : @hashmap.HashMap[Int, Bool],
  object : PdfObject,
) -> Unit {
  match object {
    PdfIndirect(number) =>
      if number > 0 && !found.contains(number) {
        found[number] = true
        let resolved = self.lookup_object_or_null(number)
        if resolved != PdfNull {
          self.pdf_referenced_from_object(found, resolved)
        }
      }
    PdfArray(items) =>
      for item in items {
        self.pdf_referenced_from_object(found, item)
      }
    PdfDictionary(entries) =>
      for entry in entries {
        let (_, value) = entry
        self.pdf_referenced_from_object(found, value)
      }
    PdfStreamObject(stream) =>
      self.pdf_referenced_from_object(found, stream.dictionary)
    _ => ()
  }
}

///|
pub fn PdfDocument::remove_unreferenced(
  self : PdfDocument,
) -> Unit raise PdfError {
  self.pdf_page_nullify_deleted_page_references()
  let found : @hashmap.HashMap[Int, Bool] = @hashmap.HashMap::new()
  if self.trailer_dict().lookup_immediate(pdf_page_root_key()) is None &&
    self.root() > 0 {
    found[self.root()] = true
    self.pdf_referenced_from_object(
      found,
      self.lookup_object_or_null(self.root()),
    )
  }
  self.pdf_referenced_from_object(found, self.trailer_dict())
  let to_remove : Array[Int] = []
  for number in self.object_numbers() {
    if !found.contains(number) {
      to_remove.push(number)
    }
  }
  for number in to_remove {
    self.remove_object(number)
  }
}

///|
fn pdf_page_name_text_without_slash(name : PdfName) -> String {
  let bytes = name.bytes()
  let view = if bytes.length() > 0 && bytes[0].to_int() == 47 {
    bytes[1:]
  } else {
    bytes[:]
  }
  @ascii.decode(view) catch {
    _ => ""
  }
}

///|
fn pdf_page_string_has_prefix(text : String, prefix : String) -> Bool {
  let text_bytes = @ascii.encode(text)
  let prefix_bytes = @ascii.encode(prefix)
  if prefix_bytes.length() > text_bytes.length() {
    false
  } else {
    for i in 0..<prefix_bytes.length() {
      if text_bytes[i] != prefix_bytes[i] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_page_next_prefix(prefix : String) -> String {
  if prefix == "" {
    "a"
  } else {
    let bytes = @ascii.encode(prefix)
    if bytes[0].to_int() == 122 {
      "a" + prefix
    } else {
      let output = bytes.to_array()
      output[0] = (output[0].to_int() + 1).to_byte()
      try! @ascii.decode(Bytes::from_array(output)[:])
    }
  }
}

///|
fn pdf_page_prefix_is_unused(
  names : ArrayView[String],
  prefix : String,
) -> Bool {
  for name in names {
    if pdf_page_string_has_prefix(name, prefix) {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn PdfDocument::pdf_page_resource_names(
  self : PdfDocument,
  resources : PdfObject,
) -> Array[String] {
  let names : Array[String] = []
  for resource_key in pdf_page_resource_keys() {
    match self.lookup_direct(resource_key, resources) {
      Some(PdfDictionary(entries)) =>
        for entry in entries {
          let (name, _) = entry
          names.push(pdf_page_name_text_without_slash(name))
        }
      _ => ()
    }
  }
  names
}

///|
fn pdf_page_is_resource_key(key : PdfName) -> Bool {
  for resource_key in pdf_page_resource_keys() {
    if key == resource_key {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_page_unknown_resource_entries(
  resources : PdfObject,
) -> Array[(PdfName, PdfObject)] {
  let output : Array[(PdfName, PdfObject)] = []
  match resources {
    PdfDictionary(entries) =>
      for entry in entries {
        let (key, _) = entry
        if !pdf_page_is_resource_key(key) {
          output.push(entry)
        }
      }
    _ => ()
  }
  output
}

///|
fn PdfDocument::pdf_page_resource_entries(
  self : PdfDocument,
  resources : PdfObject,
  key : PdfName,
) -> Array[(PdfName, PdfObject)] {
  match self.lookup_direct(key, resources) {
    Some(PdfDictionary(entries)) => [ for entry in entries => entry ]
    _ => []
  }
}

///|
pub fn PdfDocument::combine_pdf_resources(
  self : PdfDocument,
  first : PdfObject,
  second : PdfObject,
) -> PdfObject {
  let output : Array[(PdfName, PdfObject)] = []
  for entry in pdf_page_unknown_resource_entries(first) {
    output.push(entry)
  }
  for entry in pdf_page_unknown_resource_entries(second) {
    output.push(entry)
  }
  for key in pdf_page_resource_keys() {
    let entries = self.pdf_page_resource_entries(first, key)
    for entry in self.pdf_page_resource_entries(second, key) {
      entries.push(entry)
    }
    if entries.length() > 0 {
      output.push((key, PdfDictionary(entries)))
    }
  }
  PdfDictionary(output)
}

///|
fn PdfDocument::pdf_page_object_uses_page_resources(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_page_type_key(), object) {
    Some(PdfNameObject(name)) =>
      name == pdf_page_type_page() || name == pdf_page_type_pages()
    _ => false
  }
}

///|
fn pdf_page_merge_dictionary_objects(
  first : PdfObject,
  second : PdfObject,
) -> PdfObject raise PdfError {
  let mut output = first
  match second {
    PdfDictionary(entries) =>
      for entry in entries {
        let (key, value) = entry
        output = output.add_dict_entry(key, value)
      }
    _ => raise DictionaryExpected
  }
  output
}

///|
fn PdfDocument::pdf_page_process_form_xobject(
  self : PdfDocument,
  resources : PdfObject,
  object_number : Int,
  process : (PdfDocument, PdfObject, ArrayView[PdfObject]) -> Array[PdfObject] raise PdfError,
) -> Unit raise PdfError {
  let xobject = self.lookup_object_or_null(object_number)
  match self.lookup_direct(pdf_page_subtype_key(), xobject) {
    Some(PdfNameObject(name)) if name == pdf_page_type_form() =>
      match xobject {
        PdfStreamObject(stream) => {
          xobject.get_stream()
          let processed = process(self, resources, [PdfStreamObject(stream)])
          if processed.length() != 1 {
            raise ParseStreamExpected
          }
          match processed[0] {
            PdfStreamObject(processed_stream) => {
              let dictionary = pdf_page_merge_dictionary_objects(
                stream.dictionary,
                processed_stream.dictionary,
              ).remove_dict_entry(pdf_page_filter_key())
              self.add_object_given_number(
                object_number,
                PdfStreamObject({ dictionary, data: processed_stream.data }),
              )
            }
            _ => raise ParseStreamExpected
          }
        }
        _ => raise ParseStreamExpected
      }
    Some(_) => ()
    None => raise DictionaryKeyNotFound(pdf_page_subtype_key())
  }
}

///|
pub fn[A, B, C] pdf_page_process_stub(
  process : (A, B) -> C raise,
  number : A,
  page : B,
) -> (C, A, TransformMatrix) raise {
  (process(number, page), number, transform_identity_matrix)
}

///|
pub fn PdfDocument::process_xobjects(
  self : PdfDocument,
  page : PdfPage,
  process : (PdfDocument, PdfObject, ArrayView[PdfObject]) -> Array[PdfObject] raise PdfError,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_page_xobject_key(), page.resources) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        let (_, value) = entry
        match value {
          PdfIndirect(number) =>
            self.pdf_page_process_form_xobject(page.resources, number, process)
          _ => raise DictionaryExpected
        }
      }
    _ => ()
  }
}

///|
pub fn PdfDocument::shortest_unused_prefix(self : PdfDocument) -> String {
  let names : Array[String] = []
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    if self.pdf_page_object_uses_page_resources(object) {
      match self.lookup_direct(pdf_page_resources_key(), object) {
        Some(resources) =>
          for name in self.pdf_page_resource_names(resources) {
            names.push(name)
          }
        None => ()
      }
    }
  }
  let mut prefix = "a"
  while !pdf_page_prefix_is_unused(names, prefix) {
    prefix = pdf_page_next_prefix(prefix)
  }
  prefix
}

///|
fn pdf_page_prefixed_name(prefix : String, name : PdfName) -> PdfName {
  let output : Array[Byte] = [47]
  for byte in @ascii.encode(prefix) {
    output.push(byte)
  }
  let bytes = name.bytes()
  let start = if bytes.length() > 0 && bytes[0].to_int() == 47 { 1 } else { 0 }
  for i in start..<bytes.length() {
    output.push(bytes[i])
  }
  pdf_name_of_bytes(Bytes::from_array(output))
}

///|
fn pdf_page_name_member(names : ArrayView[PdfName], name : PdfName) -> Bool {
  for candidate in names {
    if candidate == name {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_page_direct_color_names() -> Array[PdfName] {
  [
    pdf_page_name("/DeviceGray"),
    pdf_page_name("/DeviceRGB"),
    pdf_page_name("/DeviceCMYK"),
    pdf_page_name("/Pattern"),
  ]
}

///|
fn pdf_page_direct_inline_color_names() -> Array[PdfName] {
  [
    pdf_page_name("/DeviceGray"),
    pdf_page_name("/DeviceRGB"),
    pdf_page_name("/DeviceCMYK"),
    pdf_page_name("/G"),
    pdf_page_name("/RGB"),
    pdf_page_name("/CMYK"),
  ]
}

///|
fn PdfDocument::pdf_page_prefix_inline_image_dictionary(
  self : PdfDocument,
  prefix : String,
  dictionary : PdfObject,
) -> PdfObject raise PdfError {
  match
    self.lookup_direct_or_else(
      pdf_page_name("/CS"),
      pdf_page_name("/ColorSpace"),
      dictionary,
    ) {
    Some(PdfNameObject(name)) if !pdf_page_name_member(
        pdf_page_direct_inline_color_names(),
        name,
      ) =>
      dictionary
      .remove_dict_entry(pdf_page_name("/ColorSpace"))
      .remove_dict_entry(pdf_page_name("/CS"))
      .add_dict_entry(
        pdf_page_name("/CS"),
        PdfNameObject(pdf_page_prefixed_name(prefix, name)),
      )
    _ => dictionary
  }
}

///|
fn PdfDocument::pdf_page_prefix_content_op(
  self : PdfDocument,
  prefix : String,
  op : PdfContentOp,
) -> PdfContentOp raise PdfError {
  match op {
    Op_Tf(font, size) => Op_Tf(pdf_page_prefixed_name(prefix, font), size)
    Op_gs(name) => Op_gs(pdf_page_prefixed_name(prefix, name))
    Op_CS(name) =>
      if pdf_page_name_member(pdf_page_direct_color_names(), name) {
        op
      } else {
        Op_CS(pdf_page_prefixed_name(prefix, name))
      }
    Op_cs(name) =>
      if pdf_page_name_member(pdf_page_direct_color_names(), name) {
        op
      } else {
        Op_cs(pdf_page_prefixed_name(prefix, name))
      }
    Op_SCNName(name, values) =>
      Op_SCNName(pdf_page_prefixed_name(prefix, name), values)
    Op_scnName(name, values) =>
      Op_scnName(pdf_page_prefixed_name(prefix, name), values)
    Op_sh(name) => Op_sh(pdf_page_prefixed_name(prefix, name))
    Op_Do(name) => Op_Do(pdf_page_prefixed_name(prefix, name))
    Op_DP(tag, PdfNameObject(name)) =>
      Op_DP(tag, PdfNameObject(pdf_page_prefixed_name(prefix, name)))
    Op_BDC(tag, PdfNameObject(name)) =>
      Op_BDC(tag, PdfNameObject(pdf_page_prefixed_name(prefix, name)))
    Op_InlineImage(dictionary, decode_parms, data) =>
      Op_InlineImage(
        self.pdf_page_prefix_inline_image_dictionary(prefix, dictionary),
        decode_parms,
        data,
      )
    _ => op
  }
}

///|
fn PdfDocument::pdf_page_prefix_content_ops(
  self : PdfDocument,
  prefix : String,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = []
  for op in ops {
    output.push(self.pdf_page_prefix_content_op(prefix, op))
  }
  output
}

///|
fn PdfDocument::pdf_page_prefix_resource_dictionary(
  self : PdfDocument,
  prefix : String,
  resources : PdfObject,
) -> PdfObject raise PdfError {
  let mut output = resources
  for resource_key in pdf_page_resource_keys() {
    let new_entries : Array[(PdfName, PdfObject)] = []
    match self.lookup_direct(resource_key, resources) {
      Some(PdfDictionary(entries)) =>
        for entry in entries {
          let (name, value) = entry
          new_entries.push((pdf_page_prefixed_name(prefix, name), value))
        }
      _ => ()
    }
    output = output.add_dict_entry(resource_key, PdfDictionary(new_entries))
  }
  output
}

///|
fn PdfDocument::pdf_page_renumber_resource_changes(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
) -> Array[(PdfName, Int, PdfName, PdfName)] {
  let changes : Array[(PdfName, Int, PdfName, PdfName)] = []
  let mut serial = 1
  for resource_key in pdf_page_resource_keys() {
    for page_index in 0..<pages.length() {
      match self.lookup_direct(resource_key, pages[page_index].resources) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            let (old_name, _) = entry
            changes.push(
              (
                resource_key,
                page_index + 1,
                old_name,
                pdf_page_name("/r" + serial.to_string()),
              ),
            )
            serial += 1
          }
        _ => ()
      }
    }
  }
  changes
}

///|
fn pdf_page_renumber_lookup_optional(
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  resource_key : PdfName,
  page_number : Int,
  old_name : PdfName,
) -> PdfName? {
  for change in changes {
    let (change_key, change_page, change_old_name, new_name) = change
    if change_key == resource_key &&
      change_page == page_number &&
      change_old_name == old_name {
      break Some(new_name)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_page_renumber_lookup(
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  resource_key : PdfName,
  page_number : Int,
  old_name : PdfName,
) -> PdfName raise PdfError {
  match
    pdf_page_renumber_lookup_optional(
      changes, resource_key, page_number, old_name,
    ) {
    Some(new_name) => new_name
    None => raise DictionaryKeyNotFound(old_name)
  }
}

///|
fn PdfDocument::pdf_page_renumber_inline_image_dictionary(
  self : PdfDocument,
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  page_number : Int,
  dictionary : PdfObject,
) -> PdfObject raise PdfError {
  match
    self.lookup_direct_or_else(
      pdf_page_name("/CS"),
      pdf_page_name("/ColorSpace"),
      dictionary,
    ) {
    Some(PdfNameObject(name)) if !pdf_page_name_member(
        pdf_page_direct_inline_color_names(),
        name,
      ) =>
      dictionary
      .remove_dict_entry(pdf_page_name("/ColorSpace"))
      .remove_dict_entry(pdf_page_name("/CS"))
      .add_dict_entry(
        pdf_page_name("/CS"),
        PdfNameObject(
          pdf_page_renumber_lookup(
            changes,
            pdf_page_name("/ColorSpace"),
            page_number,
            name,
          ),
        ),
      )
    _ => dictionary
  }
}

///|
fn PdfDocument::pdf_page_renumber_content_op(
  self : PdfDocument,
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  page_number : Int,
  op : PdfContentOp,
) -> PdfContentOp raise PdfError {
  match op {
    Op_Tf(font, size) =>
      Op_Tf(
        pdf_page_renumber_lookup(
          changes,
          pdf_page_name("/Font"),
          page_number,
          font,
        ),
        size,
      )
    Op_gs(name) =>
      Op_gs(
        pdf_page_renumber_lookup(
          changes,
          pdf_page_name("/ExtGState"),
          page_number,
          name,
        ),
      )
    Op_CS(name) =>
      if pdf_page_name_member(pdf_page_direct_color_names(), name) {
        op
      } else {
        match
          pdf_page_renumber_lookup_optional(
            changes,
            pdf_page_name("/ColorSpace"),
            page_number,
            name,
          ) {
          Some(new_name) => Op_CS(new_name)
          None => op
        }
      }
    Op_cs(name) =>
      if pdf_page_name_member(pdf_page_direct_color_names(), name) {
        op
      } else {
        match
          pdf_page_renumber_lookup_optional(
            changes,
            pdf_page_name("/ColorSpace"),
            page_number,
            name,
          ) {
          Some(new_name) => Op_cs(new_name)
          None => op
        }
      }
    Op_SCNName(name, values) =>
      Op_SCNName(
        pdf_page_renumber_lookup(
          changes,
          pdf_page_name("/Pattern"),
          page_number,
          name,
        ),
        values,
      )
    Op_scnName(name, values) =>
      Op_scnName(
        pdf_page_renumber_lookup(
          changes,
          pdf_page_name("/Pattern"),
          page_number,
          name,
        ),
        values,
      )
    Op_sh(name) =>
      Op_sh(
        pdf_page_renumber_lookup(
          changes,
          pdf_page_name("/Shading"),
          page_number,
          name,
        ),
      )
    Op_Do(name) =>
      Op_Do(
        pdf_page_renumber_lookup(
          changes,
          pdf_page_name("/XObject"),
          page_number,
          name,
        ),
      )
    Op_DP(tag, PdfNameObject(name)) =>
      Op_DP(
        tag,
        PdfNameObject(
          pdf_page_renumber_lookup(
            changes,
            pdf_page_name("/Properties"),
            page_number,
            name,
          ),
        ),
      )
    Op_BDC(tag, PdfNameObject(name)) =>
      match
        pdf_page_renumber_lookup_optional(
          changes,
          pdf_page_name("/Properties"),
          page_number,
          name,
        ) {
        Some(new_name) => Op_BDC(tag, PdfNameObject(new_name))
        None => op
      }
    Op_InlineImage(dictionary, decode_parms, data) =>
      Op_InlineImage(
        self.pdf_page_renumber_inline_image_dictionary(
          changes, page_number, dictionary,
        ),
        decode_parms,
        data,
      )
    _ => op
  }
}

///|
fn PdfDocument::pdf_page_renumber_content_ops(
  self : PdfDocument,
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  page_number : Int,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = []
  for op in ops {
    output.push(self.pdf_page_renumber_content_op(changes, page_number, op))
  }
  output
}

///|
fn PdfDocument::pdf_page_renumber_resource_dictionary(
  self : PdfDocument,
  changes : ArrayView[(PdfName, Int, PdfName, PdfName)],
  page_number : Int,
  resources : PdfObject,
) -> PdfObject raise PdfError {
  let mut output = resources
  for resource_key in pdf_page_resource_keys() {
    let new_entries : Array[(PdfName, PdfObject)] = []
    match self.lookup_direct(resource_key, resources) {
      Some(PdfDictionary(entries)) =>
        for entry in entries {
          let (old_name, value) = entry
          new_entries.push(
            (
              pdf_page_renumber_lookup(
                changes, resource_key, page_number, old_name,
              ),
              value,
            ),
          )
        }
      _ => ()
    }
    output = output.add_dict_entry(resource_key, PdfDictionary(new_entries))
  }
  output
}

///|
pub fn PdfDocument::renumber_pages(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
) -> Array[PdfPage] raise PdfError {
  if pages.length() == 0 {
    []
  } else {
    let changes = self.pdf_page_renumber_resource_changes(pages)
    let output : Array[PdfPage] = []
    for page_index in 0..<pages.length() {
      let page = pages[page_index]
      let page_number = page_index + 1
      let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
      let renamed_ops = self.pdf_page_renumber_content_ops(
        changes, page_number, ops,
      )
      output.push({
        ..page,
        content: [pdf_content_stream_of_ops(renamed_ops)],
        resources: self.pdf_page_renumber_resource_dictionary(
          changes,
          page_number,
          page.resources,
        ),
      })
    }
    output
  }
}

///|
fn PdfDocument::pdf_page_prefix_content_streams(
  self : PdfDocument,
  prefix : String,
  page_object : PdfObject,
  fixed_streams : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  let resources = match
    self.lookup_direct(pdf_page_resources_key(), page_object) {
    Some(resources) => resources
    None => PdfDictionary([])
  }
  let contents = self.pdf_page_content_list(
    self.pdf_page_content_object(page_object),
  )
  for content in contents {
    match content {
      PdfIndirect(number) if !fixed_streams.contains(number) => {
        let ops = self.pdf_page_parse_content_ops(resources, [content])
        self.add_object_given_number(
          number,
          pdf_content_stream_of_ops(
            self.pdf_page_prefix_content_ops(prefix, ops),
          ),
        )
        fixed_streams[number] = true
      }
      _ => ()
    }
  }
}

///|
fn PdfDocument::pdf_page_prefix_object(
  self : PdfDocument,
  prefix : String,
  object : PdfObject,
) -> PdfObject raise PdfError {
  match self.lookup_direct(pdf_page_resources_key(), object) {
    Some(resources) =>
      object.add_dict_entry(
        pdf_page_resources_key(),
        self.pdf_page_prefix_resource_dictionary(prefix, resources),
      )
    None => object
  }
}

///|
fn PdfDocument::pdf_page_merged_content_stream(
  self : PdfDocument,
  contents : ArrayView[PdfObject],
) -> PdfObject raise PdfError {
  let decoded_streams : Array[PdfBytes] = []
  for content in contents {
    match self.direct(content) {
      PdfStreamObject(stream) =>
        decoded_streams.push(
          pdf_stream_data_bytes(
            self.pdf_decode_stream_value_direct(stream).data,
          ),
        )
      _ => raise ParseStreamExpected
    }
  }
  let data = pdf_content_concat_streams(decoded_streams)
  pdf_stream(
    PdfDictionary([(pdf_page_name("/Length"), PdfInteger(data.length()))]),
    StreamGot(data),
  )
}

///|
fn PdfDocument::pdf_page_merge_content_object(
  self : PdfDocument,
  object : PdfObject,
) -> PdfObject raise PdfError {
  match object.lookup_immediate(pdf_page_contents_key()) {
    Some(PdfArray(contents)) if contents.length() != 1 => {
      let stream_number = self.add_object(
        self.pdf_page_merged_content_stream(contents),
      )
      object.add_dict_entry(pdf_page_contents_key(), PdfIndirect(stream_number))
    }
    _ => object
  }
}

///|
pub fn PdfDocument::merge_content_streams(
  self : PdfDocument,
) -> Unit raise PdfError {
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    if self.pdf_page_object_uses_page_resources(object) {
      let updated = self.pdf_page_merge_content_object(object)
      if updated != object {
        self.add_object_given_number(number, updated)
      }
    }
  }
}

///|
fn PdfDocument::pdf_page_split_contents_need_merge(
  self : PdfDocument,
  resources : PdfObject,
  contents : ArrayView[PdfObject],
) -> Bool {
  if contents.length() <= 1 {
    false
  } else {
    for content in contents {
      try self.pdf_page_parse_content_ops(resources, [content]) catch {
        _ => break true
      } noraise {
        _ => ()
      }
    } nobreak {
      false
    }
  }
}

///|
fn PdfDocument::pdf_page_object_needs_content_merge(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  if !self.pdf_page_object_uses_page_resources(object) {
    false
  } else {
    let resources = match self.lookup_direct(pdf_page_resources_key(), object) {
      Some(resources) => resources
      None => PdfDictionary([])
    }
    match object.lookup_immediate(pdf_page_contents_key()) {
      Some(PdfArray(contents)) =>
        self.pdf_page_split_contents_need_merge(resources, contents)
      _ => false
    }
  }
}

///|
fn PdfDocument::pdf_page_needs_content_merge(self : PdfDocument) -> Bool {
  for number in self.object_numbers() {
    if self.pdf_page_object_needs_content_merge(
        self.lookup_object_or_null(number),
      ) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn PdfDocument::pdf_page_add_prefix(
  self : PdfDocument,
  prefix : String,
) -> Unit raise PdfError {
  let fixed_streams : @hashmap.HashMap[Int, Bool] = @hashmap.HashMap::new()
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    if self.pdf_page_object_uses_page_resources(object) {
      self.pdf_page_prefix_content_streams(prefix, object, fixed_streams)
      self.add_object_given_number(
        number,
        self.pdf_page_prefix_object(prefix, object),
      )
    }
  }
}

///|
pub fn PdfDocument::add_prefix(
  self : PdfDocument,
  prefix : String,
) -> Unit raise PdfError {
  if self.pdf_page_needs_content_merge() {
    self.merge_content_streams()
  }
  self.pdf_page_add_prefix(prefix)
}

///|
fn pdf_page_reference_numbers_inner(
  pdf : PdfDocument,
  pages_node : PdfObject,
  node_number : Int,
  depth : Int,
) -> Array[Int] raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match pdf.lookup_direct(pdf_page_type_key(), pages_node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_page() => [node_number]
    _ =>
      match pdf.lookup_direct(pdf_page_kids_key(), pages_node) {
        Some(PdfArray(kids)) => {
          let output : Array[Int] = []
          for kid in kids {
            match kid {
              PdfIndirect(number) => {
                let child = pdf.direct(kid)
                if child != PdfNull {
                  for
                    page_number in pdf_page_reference_numbers_inner(
                      pdf,
                      child,
                      number,
                      depth + 1,
                    ) {
                    output.push(page_number)
                  }
                }
              }
              _ => ()
            }
          }
          output
        }
        _ => [node_number]
      }
  }
}

///|
fn PdfDocument::pdf_pages_of_pagetree_quick_node(
  self : PdfDocument,
  node : PdfObject,
  depth : Int,
) -> Int raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  if node == PdfNull {
    0
  } else {
    match self.lookup_direct(pdf_page_type_key(), node) {
      Some(PdfNameObject(name)) if name != pdf_page_type_pages() => 1
      _ =>
        match self.lookup_direct(pdf_page_kids_key(), node) {
          Some(PdfArray(kids)) => {
            let mut count = 0
            for kid in kids {
              match kid {
                PdfIndirect(number) => {
                  let child = self.lookup_object_or_null(number)
                  if child == PdfNull {
                    raise PageTreeExpected
                  }
                  count += self.pdf_pages_of_pagetree_quick_node(
                    child,
                    depth + 1,
                  )
                }
                PdfDictionary(_) =>
                  count += self.pdf_pages_of_pagetree_quick_node(kid, depth + 1)
                _ => raise PageTreeExpected
              }
            }
            count
          }
          _ => raise PageTreeExpected
        }
    }
  }
}

///|
fn pdf_page_root_pages_node(pdf : PdfDocument) -> PdfObject raise PdfError {
  let root = match pdf.pdf_page_active_catalog() {
    Some((catalog, _)) => catalog
    None => raise RootExpected
  }
  match pdf.lookup_direct(pdf_page_pages_key(), root) {
    Some(pages) => pages
    None => raise PageTreeExpected
  }
}

///|
pub fn PdfDocument::page_reference_numbers(
  self : PdfDocument,
) -> Array[Int] raise PdfError {
  pdf_page_reference_numbers_inner(self, pdf_page_root_pages_node(self), -1, 0)
}

///|
pub fn PdfDocument::pages_of_pagetree_quick(
  self : PdfDocument,
) -> Int raise PdfError {
  self.pdf_pages_of_pagetree_quick_node(pdf_page_root_pages_node(self), 0)
}

///|
pub fn PdfDocument::page_object_number(
  self : PdfDocument,
  page_number : Int,
) -> Int? raise PdfError {
  let references = self.page_reference_numbers()
  if page_number < 1 || page_number > references.length() {
    None
  } else {
    Some(references[page_number - 1])
  }
}

///|
pub fn PdfDocument::page_number_of_target(
  self : PdfDocument,
  destination : PdfDestination,
) -> Int raise PdfError {
  self.pdf_destination_page_number(destination, self.page_reference_numbers())
}

///|
pub fn PdfDocument::target_of_page_number(
  self : PdfDocument,
  page_number : Int,
) -> PdfDestination raise PdfError {
  match self.page_object_number(page_number) {
    Some(object_number) => DestFit(TargetPageObject(object_number))
    None => DestNull
  }
}

///|
pub fn PdfDocument::endpage(self : PdfDocument) -> Int raise PdfError {
  self.pages_of_pagetree_quick()
}

///|
pub fn PdfDocument::endpage_fast(self : PdfDocument) -> Int raise PdfError {
  match
    self.lookup_direct(pdf_page_count_key(), pdf_page_root_pages_node(self)) {
    Some(PdfInteger(count)) => count
    _ => 0
  }
}
