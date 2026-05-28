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
  let raw_entries = pdf_tree_raw_entries(self, tree)
  let parsed : Array[(PdfBytes, PdfObject)] = Array::new(
    capacity=raw_entries.length(),
  )
  let mut malformed = false
  for entry in raw_entries {
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
  let raw_entries = pdf_tree_raw_entries(self, tree)
  let parsed : Array[(Int, PdfObject)] = Array::new(
    capacity=raw_entries.length(),
  )
  let mut malformed = false
  for entry in raw_entries {
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
  let number_entries = document.read_number_tree(tree)
  let output : Array[(PdfBytes, PdfObject)] = Array::new(
    capacity=number_entries.length(),
  )
  for entry in number_entries {
    output.push((pdf_tree_number_key_bytes(entry.0), entry.1))
  }
  output
}
