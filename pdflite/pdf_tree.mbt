///|
fn pdf_tree_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_tree_names_key_name : PdfName = pdf_tree_name("/Names")

///|
fn pdf_tree_names_key() -> PdfName {
  pdf_tree_names_key_name
}

///|
let pdf_tree_nums_key_name : PdfName = pdf_tree_name("/Nums")

///|
fn pdf_tree_nums_key() -> PdfName {
  pdf_tree_nums_key_name
}

///|
let pdf_tree_kids_key_name : PdfName = pdf_tree_name("/Kids")

///|
fn pdf_tree_kids_key() -> PdfName {
  pdf_tree_kids_key_name
}

///|
let pdf_tree_limits_key_name : PdfName = pdf_tree_name("/Limits")

///|
fn pdf_tree_limits_key() -> PdfName {
  pdf_tree_limits_key_name
}

///|
fn pdf_tree_byte_compare(left : Byte, right : Byte) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn pdf_tree_bytes_compare(left : Bytes, right : Bytes) -> Int {
  let shared = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<shared {
    let compared = pdf_tree_byte_compare(left[i], right[i])
    if compared != 0 {
      break compared
    }
  } nobreak {
    left.length().compare(right.length())
  }
}

///|
fn pdf_tree_raw_entries(
  pdf : PdfDocument,
  tree : PdfObject,
) -> Array[(PdfObject, PdfObject)] {
  let output : Array[(PdfObject, PdfObject)] = []
  match
    pdf.lookup_direct_or_else(pdf_tree_names_key(), pdf_tree_nums_key(), tree) {
    Some(PdfArray(items)) if items.length() % 2 == 0 =>
      for i in 0..<(items.length() / 2) {
        output.push((items[i * 2], items[i * 2 + 1]))
      }
    _ => ()
  }
  match pdf.lookup_direct(pdf_tree_kids_key(), tree) {
    Some(PdfArray(kids)) =>
      for kid in kids {
        for entry in pdf_tree_raw_entries(pdf, kid) {
          output.push(entry)
        }
      }
    _ => ()
  }
  output
}

///|
fn pdf_tree_array_pairs(
  items : ArrayView[PdfObject],
) -> Array[(PdfObject, PdfObject)] {
  let output : Array[(PdfObject, PdfObject)] = []
  for i in 0..<(items.length() / 2) {
    output.push((items[i * 2], items[i * 2 + 1]))
  }
  output
}

///|
fn pdf_tree_object_compare(left : PdfObject, right : PdfObject) -> Int? {
  match (left, right) {
    (PdfString(left), PdfString(right)) =>
      Some(pdf_tree_bytes_compare(left, right))
    (PdfInteger(left), PdfInteger(right)) => Some(left.compare(right))
    _ => None
  }
}

///|
fn pdf_tree_limits_contain(
  key : PdfObject,
  limits : ArrayView[PdfObject],
) -> Bool {
  guard limits.length() == 2 else { return false }
  match
    (
      pdf_tree_object_compare(key, limits[0]),
      pdf_tree_object_compare(key, limits[1]),
    ) {
    (Some(left), Some(right)) => left >= 0 && right <= 0
    _ => false
  }
}

///|
fn PdfDocument::pdf_tree_lookup_array(
  self : PdfDocument,
  key : PdfObject,
  items : ArrayView[PdfObject],
) -> PdfObject? {
  ignore(self)
  for i in 0..<(items.length() / 2) {
    if items[i * 2] == key {
      break Some(items[i * 2 + 1])
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::pdf_tree_lookup_kids(
  self : PdfDocument,
  key : PdfObject,
  kids : ArrayView[PdfObject],
) -> PdfObject? {
  for kid in kids {
    match self.name_tree_lookup_object(key, kid) {
      Some(value) => break Some(value)
      None => ()
    }
  } nobreak {
    None
  }
}

///|
/// Return the immediate key-value pairs contained in a name or number tree.
///
/// The tree may store entries directly in `/Names` or `/Nums`, or indirectly in
/// child nodes under `/Kids`. Entries are returned as raw `PdfObject` pairs, so
/// callers that need typed name or number keys should use `read_name_tree` or
/// `read_number_tree`.
pub fn PdfDocument::contents_of_name_tree(
  self : PdfDocument,
  tree : PdfObject,
) -> Array[(PdfObject, PdfObject)] {
  match
    self.lookup_direct_or_else(pdf_tree_names_key(), pdf_tree_nums_key(), tree) {
    Some(PdfArray(items)) => pdf_tree_array_pairs(items)
    _ =>
      match self.lookup_direct(pdf_tree_kids_key(), tree) {
        Some(PdfArray(kids)) => {
          let output : Array[(PdfObject, PdfObject)] = []
          for kid in kids {
            for entry in self.contents_of_name_tree(kid) {
              output.push(entry)
            }
          }
          output
        }
        _ => []
      }
  }
}

///|
/// Look up a raw key object in a PDF name tree or number tree.
///
/// `/Limits` entries are used to skip child nodes when they are comparable with
/// `key`. The lookup accepts both direct leaf arrays and nested `/Kids` nodes,
/// returning `None` for malformed nodes or missing keys.
pub fn PdfDocument::name_tree_lookup_object(
  self : PdfDocument,
  key : PdfObject,
  tree : PdfObject,
) -> PdfObject? {
  match self.lookup_direct(pdf_tree_limits_key(), tree) {
    Some(PdfArray(limits)) if !pdf_tree_limits_contain(key, limits) =>
      return None
    Some(PdfArray(_)) | None => ()
    Some(_) => return None
  }
  match self.lookup_direct(pdf_tree_kids_key(), tree) {
    Some(PdfArray(kids)) => self.pdf_tree_lookup_kids(key, kids)
    Some(_) => None
    None =>
      match
        self.lookup_direct_or_else(
          pdf_tree_names_key(),
          pdf_tree_nums_key(),
          tree,
        ) {
        Some(PdfArray(items)) => self.pdf_tree_lookup_array(key, items)
        _ => None
      }
  }
}

///|
/// Look up a byte-string key in a PDF name tree.
///
/// The `BytesView` key is copied into an owned `PdfString` because PDF objects
/// own their byte storage. Prefer this method when the key is already available
/// as PDF-encoded bytes.
pub fn PdfDocument::name_tree_lookup(
  self : PdfDocument,
  key : BytesView,
  tree : PdfObject,
) -> PdfObject? {
  self.name_tree_lookup_object(PdfString(key.to_owned()), tree)
}

///|
/// Look up an integer key in a PDF number tree.
pub fn PdfDocument::number_tree_lookup(
  self : PdfDocument,
  key : Int,
  tree : PdfObject,
) -> PdfObject? {
  self.name_tree_lookup_object(PdfInteger(key), tree)
}

///|
fn pdf_tree_sort_name_entries(
  entries : ArrayView[(PdfBytes, PdfObject)],
) -> Array[(PdfBytes, PdfObject)] {
  let sorted = [ for entry in entries => entry ]
  sorted.sort_by(fn(left, right) { pdf_tree_bytes_compare(left.0, right.0) })
  sorted
}

///|
fn pdf_tree_sort_number_entries(
  entries : ArrayView[(Int, PdfObject)],
) -> Array[(Int, PdfObject)] {
  let sorted = [ for entry in entries => entry ]
  sorted.sort_by(fn(left, right) { left.0.compare(right.0) })
  sorted
}

///|
fn pdf_tree_dedup_name_entries(
  entries : ArrayView[(PdfBytes, PdfObject)],
) -> Array[(PdfBytes, PdfObject)] {
  let output : Array[(PdfBytes, PdfObject)] = []
  for entry in entries {
    if output.length() > 0 &&
      pdf_tree_bytes_compare(output[output.length() - 1].0, entry.0) == 0 {
      output[output.length() - 1] = entry
    } else {
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_tree_dedup_number_entries(
  entries : ArrayView[(Int, PdfObject)],
) -> Array[(Int, PdfObject)] {
  let output : Array[(Int, PdfObject)] = []
  for entry in entries {
    if output.length() > 0 && output[output.length() - 1].0 == entry.0 {
      output[output.length() - 1] = entry
    } else {
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_tree_number_key_bytes(number : Int) -> PdfBytes {
  @ascii.encode(number.to_string())
}

///|
fn pdf_tree_number_key_of_bytes(key : BytesView) -> Int raise PdfError {
  if key.length() == 0 {
    raise NumberExpected
  }
  let mut index = 0
  let mut negative = false
  match key[0].to_int() {
    43 => index = 1
    45 => {
      negative = true
      index = 1
    }
    _ => ()
  }
  if index >= key.length() {
    raise NumberExpected
  }
  let limit : Int64 = if negative { 2147483648L } else { 2147483647L }
  let mut value : Int64 = 0L
  while index < key.length() {
    let byte = key[index].to_int()
    guard byte >= 48 && byte <= 57 else { raise NumberExpected }
    value = value * 10L + (byte - 48).to_int64()
    guard value <= limit else { raise NumberExpected }
    index += 1
  }
  if negative {
    (-value).to_int()
  } else {
    value.to_int()
  }
}

///|
/// Read all entries from a PDF name tree as sorted byte-string keys.
///
/// Malformed trees whose keys are not `PdfString` values return an empty array.
/// Well-formed entries are sorted by byte order and duplicate keys are collapsed
/// by the deduplication pass.
pub fn PdfDocument::read_name_tree(
  self : PdfDocument,
  tree : PdfObject,
) -> Array[(PdfBytes, PdfObject)] {
  let parsed : Array[(PdfBytes, PdfObject)] = []
  let mut malformed = false
  for entry in pdf_tree_raw_entries(self, tree) {
    match entry.0 {
      PdfString(key) => parsed.push((key, entry.1))
      _ => malformed = true
    }
  }
  if malformed {
    []
  } else {
    pdf_tree_dedup_name_entries(pdf_tree_sort_name_entries(parsed))
  }
}

///|
/// Compatibility wrapper for `PdfDocument::read_name_tree`.
pub fn pdf_read_name_tree(
  document : PdfDocument,
  tree : PdfObject,
) -> Array[(PdfBytes, PdfObject)] {
  document.read_name_tree(tree)
}

///|
/// Read all entries from a PDF number tree as sorted integer keys.
///
/// Malformed trees whose keys are not `PdfInteger` values return an empty
/// array. Well-formed entries are sorted numerically and duplicate keys are
/// collapsed by the deduplication pass.
pub fn PdfDocument::read_number_tree(
  self : PdfDocument,
  tree : PdfObject,
) -> Array[(Int, PdfObject)] {
  let parsed : Array[(Int, PdfObject)] = []
  let mut malformed = false
  for entry in pdf_tree_raw_entries(self, tree) {
    match entry.0 {
      PdfInteger(key) => parsed.push((key, entry.1))
      _ => malformed = true
    }
  }
  if malformed {
    []
  } else {
    pdf_tree_dedup_number_entries(pdf_tree_sort_number_entries(parsed))
  }
}

///|
/// Compatibility wrapper that returns number-tree keys as decimal ASCII bytes.
///
/// This mirrors APIs that represent both name and number tree keys as
/// `PdfBytes`; each integer key is encoded with `Int::to_string`.
pub fn pdf_read_number_tree(
  document : PdfDocument,
  tree : PdfObject,
) -> Array[(PdfBytes, PdfObject)] {
  [
    for entry in document.read_number_tree(tree) => {
      (pdf_tree_number_key_bytes(entry.0), entry.1)
    }
  ]
}

///|
fn pdf_tree_group_count(length : Int) -> Int {
  if length <= 10 {
    1
  } else if length <= 100 {
    (length + 9) / 10
  } else {
    10
  }
}

///|
fn PdfDocument::pdf_tree_build_name_tree_range(
  self : PdfDocument,
  entries : ArrayView[(PdfBytes, PdfObject)],
  start : Int,
  stop : Int,
  is_root : Bool,
) -> PdfObject {
  if stop - start <= 10 {
    let items : Array[PdfObject] = []
    for i in start..<stop {
      items.push(PdfString(entries[i].0))
      items.push(entries[i].1)
    }
    let dict_entries : Array[(PdfName, PdfObject)] = [
      (pdf_tree_names_key(), PdfArray(items)),
    ]
    if !is_root {
      dict_entries.push(
        (
          pdf_tree_limits_key(),
          PdfArray([PdfString(entries[start].0), PdfString(entries[stop - 1].0)]),
        ),
      )
    }
    PdfDictionary(dict_entries)
  } else {
    let count = stop - start
    let groups = pdf_tree_group_count(count)
    let kids : Array[PdfObject] = []
    for group in 0..<groups {
      let child_start = start + group * count / groups
      let child_stop = start + (group + 1) * count / groups
      let child = self.pdf_tree_build_name_tree_range(
        entries, child_start, child_stop, false,
      )
      kids.push(PdfIndirect(self.add_object(child)))
    }
    let dict_entries : Array[(PdfName, PdfObject)] = [
      (pdf_tree_kids_key(), PdfArray(kids)),
    ]
    if !is_root {
      dict_entries.push(
        (
          pdf_tree_limits_key(),
          PdfArray([PdfString(entries[start].0), PdfString(entries[stop - 1].0)]),
        ),
      )
    }
    PdfDictionary(dict_entries)
  }
}

///|
/// Build a PDF name tree from byte-string keys and object values.
///
/// Entries are sorted by byte order. Empty input produces a leaf tree with an
/// empty `/Names` array; larger inputs are split into child nodes with `/Limits`
/// entries, allocating child objects in `self` as needed.
pub fn PdfDocument::build_name_tree(
  self : PdfDocument,
  entries : ArrayView[(PdfBytes, PdfObject)],
) -> PdfObject {
  if entries.length() == 0 {
    PdfDictionary([(pdf_tree_names_key(), PdfArray([]))])
  } else {
    let sorted = pdf_tree_sort_name_entries(entries)
    self.pdf_tree_build_name_tree_range(sorted, 0, sorted.length(), true)
  }
}

///|
/// Build either a name tree or a number tree from byte-keyed entries.
///
/// When `is_number` is `false`, this delegates to `build_name_tree`. When it is
/// `true`, keys must be signed 32-bit decimal ASCII and are converted to
/// integers before building a number tree; invalid keys raise `NumberExpected`.
pub fn pdf_build_name_tree(
  is_number : Bool,
  document : PdfDocument,
  entries : ArrayView[(PdfBytes, PdfObject)],
) -> PdfObject raise PdfError {
  if is_number {
    let number_entries : Array[(Int, PdfObject)] = []
    for entry in entries {
      number_entries.push((pdf_tree_number_key_of_bytes(entry.0), entry.1))
    }
    document.build_number_tree(number_entries)
  } else {
    document.build_name_tree(entries)
  }
}

///|
fn PdfDocument::pdf_tree_build_number_tree_range(
  self : PdfDocument,
  entries : ArrayView[(Int, PdfObject)],
  start : Int,
  stop : Int,
  is_root : Bool,
) -> PdfObject {
  if stop - start <= 10 {
    let items : Array[PdfObject] = []
    for i in start..<stop {
      items.push(PdfInteger(entries[i].0))
      items.push(entries[i].1)
    }
    let dict_entries : Array[(PdfName, PdfObject)] = [
      (pdf_tree_nums_key(), PdfArray(items)),
    ]
    if !is_root {
      dict_entries.push(
        (
          pdf_tree_limits_key(),
          PdfArray([
            PdfInteger(entries[start].0),
            PdfInteger(entries[stop - 1].0),
          ]),
        ),
      )
    }
    PdfDictionary(dict_entries)
  } else {
    let count = stop - start
    let groups = pdf_tree_group_count(count)
    let kids : Array[PdfObject] = []
    for group in 0..<groups {
      let child_start = start + group * count / groups
      let child_stop = start + (group + 1) * count / groups
      let child = self.pdf_tree_build_number_tree_range(
        entries, child_start, child_stop, false,
      )
      kids.push(PdfIndirect(self.add_object(child)))
    }
    let dict_entries : Array[(PdfName, PdfObject)] = [
      (pdf_tree_kids_key(), PdfArray(kids)),
    ]
    if !is_root {
      dict_entries.push(
        (
          pdf_tree_limits_key(),
          PdfArray([
            PdfInteger(entries[start].0),
            PdfInteger(entries[stop - 1].0),
          ]),
        ),
      )
    }
    PdfDictionary(dict_entries)
  }
}

///|
/// Build a PDF number tree from integer keys and object values.
///
/// Entries are sorted numerically. Empty input produces a leaf tree with an
/// empty `/Nums` array; larger inputs are split into child nodes with `/Limits`
/// entries, allocating child objects in `self` as needed.
pub fn PdfDocument::build_number_tree(
  self : PdfDocument,
  entries : ArrayView[(Int, PdfObject)],
) -> PdfObject {
  if entries.length() == 0 {
    PdfDictionary([(pdf_tree_nums_key(), PdfArray([]))])
  } else {
    let sorted = pdf_tree_sort_number_entries(entries)
    self.pdf_tree_build_number_tree_range(sorted, 0, sorted.length(), true)
  }
}

///|
/// Merge several name trees when the caller guarantees there are no clashes.
///
/// Entries are read from every input tree and rebuilt into a single sorted name
/// tree. This function does not report duplicate keys; callers that require
/// conflict handling should check the inputs before calling it.
pub fn PdfDocument::merge_name_trees_no_clash(
  self : PdfDocument,
  trees : ArrayView[PdfObject],
) -> PdfObject {
  let entries : Array[(PdfBytes, PdfObject)] = []
  for tree in trees {
    for entry in self.read_name_tree(tree) {
      entries.push(entry)
    }
  }
  self.build_name_tree(entries)
}

///|
/// Compatibility wrapper for `PdfDocument::merge_name_trees_no_clash`.
pub fn pdf_merge_name_trees_no_clash(
  document : PdfDocument,
  trees : ArrayView[PdfObject],
) -> PdfObject {
  document.merge_name_trees_no_clash(trees)
}

///|
/// Merge several number trees when the caller guarantees there are no clashes.
///
/// Entries are read from every input tree and rebuilt into a single sorted
/// number tree. Duplicate-key handling follows the read/build helpers and is
/// not reported as an error.
pub fn PdfDocument::merge_number_trees_no_clash(
  self : PdfDocument,
  trees : ArrayView[PdfObject],
) -> PdfObject {
  let entries : Array[(Int, PdfObject)] = []
  for tree in trees {
    for entry in self.read_number_tree(tree) {
      entries.push(entry)
    }
  }
  self.build_number_tree(entries)
}

///|
/// Compatibility wrapper for `PdfDocument::merge_number_trees_no_clash`.
pub fn pdf_merge_number_trees_no_clash(
  document : PdfDocument,
  trees : ArrayView[PdfObject],
) -> PdfObject {
  document.merge_number_trees_no_clash(trees)
}
