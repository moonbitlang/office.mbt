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
fn pdf_page_rotate_key() -> PdfName {
  pdf_page_name("/Rotate")
}

///|
fn pdf_page_contents_key() -> PdfName {
  pdf_page_name("/Contents")
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
pub fn PdfDocument::add_pagetree(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
) -> Int raise PdfError {
  let page_root_number = self.add_object(PdfNull)
  let page_numbers : Array[Int] = []
  for page in pages {
    page_numbers.push(
      self.add_object(self.pdf_page_object(page, page_root_number)),
    )
  }
  self.add_object_given_number(
    page_root_number,
    PdfDictionary([
      (pdf_page_type_key(), PdfNameObject(pdf_page_type_pages())),
      (
        pdf_page_kids_key(),
        PdfArray([ for number in page_numbers => PdfIndirect(number) ]),
      ),
      (pdf_page_count_key(), PdfInteger(page_numbers.length())),
    ]),
  )
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
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_page_type_key(), PdfNameObject(pdf_page_type_catalog())),
    (pdf_page_pages_key(), PdfIndirect(page_root_number)),
  ]
  let current_root = self.lookup_object_or_null(self.root())
  for entry in pdf_page_root_entries_without_catalog_keys(current_root) {
    entries.push(entry)
  }
  for entry in extras {
    let (key, _) = entry
    if key != pdf_page_type_key() && key != pdf_page_pages_key() {
      entries.push(entry)
    }
  }
  let root_number = self.add_object(PdfDictionary(entries))
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
pub fn PdfDocument::prepend_operators(
  self : PdfDocument,
  page : PdfPage,
  ops : ArrayView[PdfContentOp],
  fast? : Bool = false,
) -> PdfPage raise PdfError {
  if fast {
    { ..page, content: [pdf_content_stream_of_ops(ops), ..page.content] }
  } else {
    let old_ops = self.parse_content_ops(page.content)
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
    let existing_ops = self.parse_content_ops(page.content)
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
    match self.objects.get_entry(number) {
      Some(entry) =>
        self.objects.set_entry(number, pdf_page_renumber_entry(entry, changes))
      None => ()
    }
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
pub fn PdfDocument::change_pages(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
  change_references? : Bool = false,
) -> PdfDocument raise PdfError {
  let old_page_numbers = self.page_reference_numbers()
  let pdf = self.copy()
  let page_root_number = pdf.add_pagetree(pages)
  ignore(pdf.add_root(page_root_number, []))
  if change_references {
    let new_page_numbers = pdf.page_reference_numbers()
    pdf.pdf_page_renumber_references(
      pdf_page_reference_changes(old_page_numbers, new_page_numbers),
    )
  }
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
      match self.objects.get_entry(number) {
        Some(entry) =>
          self.objects.set_entry(
            number,
            pdf_page_nullify_entry(entry, deleted_pages),
          )
        None => ()
      }
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
  if self.root() > 0 {
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
      @ascii.decode(Bytes::from_array(output)[:]) catch {
        _ => "a"
      }
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
fn pdf_page_root_pages_node(pdf : PdfDocument) -> PdfObject raise PdfError {
  let root = pdf.lookup_object_or_null(pdf.root())
  if root == PdfNull {
    raise RootExpected
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
pub fn PdfDocument::endpage(self : PdfDocument) -> Int raise PdfError {
  self.page_reference_numbers().length()
}

///|
pub fn PdfDocument::endpage_fast(self : PdfDocument) -> Int raise PdfError {
  match
    self.lookup_direct(pdf_page_count_key(), pdf_page_root_pages_node(self)) {
    Some(PdfInteger(count)) => count
    _ => 0
  }
}
