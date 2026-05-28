///|
fn pdf_tree_raw_entries(
  pdf : PdfDocument,
  tree : PdfObject,
) -> Array[(PdfObject, PdfObject)] {
  let direct = pdf.lookup_direct_or_else(
    pdf_tree_names_key(),
    pdf_tree_nums_key(),
    tree,
  )
  let kids_object = pdf.lookup_direct(pdf_tree_kids_key(), tree)
  let direct_capacity = match direct {
    Some(PdfArray(items)) if items.length() % 2 == 0 => items.length() / 2
    _ => 0
  }
  let child_capacity = match kids_object {
    Some(PdfArray(kids)) => kids.length()
    _ => 0
  }
  let output : Array[(PdfObject, PdfObject)] = Array::new(
    capacity=direct_capacity + child_capacity,
  )
  match direct {
    Some(PdfArray(items)) if items.length() % 2 == 0 =>
      for i in 0..<(items.length() / 2) {
        output.push((items[i * 2], items[i * 2 + 1]))
      }
    _ => ()
  }
  match kids_object {
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
  let output : Array[(PdfObject, PdfObject)] = Array::new(
    capacity=items.length() / 2,
  )
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
          let output : Array[(PdfObject, PdfObject)] = Array::new(
            capacity=kids.length(),
          )
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
