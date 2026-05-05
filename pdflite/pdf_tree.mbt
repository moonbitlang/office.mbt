///|
fn pdf_tree_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_tree_names_key() -> PdfName {
  pdf_tree_name("/Names")
}

///|
fn pdf_tree_nums_key() -> PdfName {
  pdf_tree_name("/Nums")
}

///|
fn pdf_tree_kids_key() -> PdfName {
  pdf_tree_name("/Kids")
}

///|
fn pdf_tree_limits_key() -> PdfName {
  pdf_tree_name("/Limits")
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
pub fn PdfDocument::contents_of_name_tree(
  self : PdfDocument,
  tree : PdfObject,
) -> Array[(PdfObject, PdfObject)] {
  match
    self.lookup_direct_or_else(pdf_tree_names_key(), pdf_tree_nums_key(), tree) {
    Some(PdfArray(items)) => pdf_tree_array_pairs(items[:])
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
pub fn PdfDocument::name_tree_lookup_object(
  self : PdfDocument,
  key : PdfObject,
  tree : PdfObject,
) -> PdfObject? {
  match self.lookup_direct(pdf_tree_limits_key(), tree) {
    Some(PdfArray(limits)) if !pdf_tree_limits_contain(key, limits[:]) =>
      return None
    Some(PdfArray(_)) | None => ()
    Some(_) => return None
  }
  match self.lookup_direct(pdf_tree_kids_key(), tree) {
    Some(PdfArray(kids)) => self.pdf_tree_lookup_kids(key, kids[:])
    Some(_) => None
    None =>
      match
        self.lookup_direct_or_else(
          pdf_tree_names_key(),
          pdf_tree_nums_key(),
          tree,
        ) {
        Some(PdfArray(items)) => self.pdf_tree_lookup_array(key, items[:])
        _ => None
      }
  }
}

///|
pub fn PdfDocument::name_tree_lookup(
  self : PdfDocument,
  key : BytesView,
  tree : PdfObject,
) -> PdfObject? {
  self.name_tree_lookup_object(PdfString(key.to_owned()), tree)
}

///|
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
