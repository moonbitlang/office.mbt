///|
/// An empty key sequence returns `Some(start)`. If any step cannot be resolved,
/// the result is `None`.
pub fn PdfDocument::lookup_chain(
  self : PdfDocument,
  start : @syntax.PdfObject,
  keys : ArrayView[PdfName],
) -> @syntax.PdfObject? {
  let mut current = start
  for i in 0..<keys.length() {
    match self.lookup_direct_or_array(keys[i], current) {
      Some(next) => current = next
      None => break None
    }
  } nobreak {
    Some(current)
  }
}

///|
/// Read a PDF numeric object as a `Double`.
