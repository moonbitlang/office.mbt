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
    let items : Array[PdfObject] = Array::new(capacity=(stop - start) * 2)
    for i in start..<stop {
      items.push(PdfString(entries[i].0))
      items.push(entries[i].1)
    }
    let dict_capacity = if is_root { 1 } else { 2 }
    let dict_entries : Array[(PdfName, PdfObject)] = Array::new(
      capacity=dict_capacity,
    )
    dict_entries.push((pdf_tree_names_key(), PdfArray(items)))
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
    let kids : Array[PdfObject] = Array::new(capacity=groups)
    for group in 0..<groups {
      let child_start = start + group * count / groups
      let child_stop = start + (group + 1) * count / groups
      let child = self.pdf_tree_build_name_tree_range(
        entries, child_start, child_stop, false,
      )
      kids.push(PdfIndirect(self.add_object(child)))
    }
    let dict_capacity = if is_root { 1 } else { 2 }
    let dict_entries : Array[(PdfName, PdfObject)] = Array::new(
      capacity=dict_capacity,
    )
    dict_entries.push((pdf_tree_kids_key(), PdfArray(kids)))
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
/// integers before building a number tree; invalid keys raise `PdfError::NumberExpected`.
pub fn pdf_build_name_tree(
  is_number : Bool,
  document : PdfDocument,
  entries : ArrayView[(PdfBytes, PdfObject)],
) -> PdfObject raise PdfError {
  if is_number {
    let number_entries : Array[(Int, PdfObject)] = Array::new(
      capacity=entries.length(),
    )
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
    let items : Array[PdfObject] = Array::new(capacity=(stop - start) * 2)
    for i in start..<stop {
      items.push(PdfInteger(entries[i].0))
      items.push(entries[i].1)
    }
    let dict_capacity = if is_root { 1 } else { 2 }
    let dict_entries : Array[(PdfName, PdfObject)] = Array::new(
      capacity=dict_capacity,
    )
    dict_entries.push((pdf_tree_nums_key(), PdfArray(items)))
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
    let kids : Array[PdfObject] = Array::new(capacity=groups)
    for group in 0..<groups {
      let child_start = start + group * count / groups
      let child_stop = start + (group + 1) * count / groups
      let child = self.pdf_tree_build_number_tree_range(
        entries, child_start, child_stop, false,
      )
      kids.push(PdfIndirect(self.add_object(child)))
    }
    let dict_capacity = if is_root { 1 } else { 2 }
    let dict_entries : Array[(PdfName, PdfObject)] = Array::new(
      capacity=dict_capacity,
    )
    dict_entries.push((pdf_tree_kids_key(), PdfArray(kids)))
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
