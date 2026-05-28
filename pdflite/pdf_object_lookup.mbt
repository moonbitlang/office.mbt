///|
/// Borrow the dictionary entries of a dictionary-like object.
///
/// Plain dictionaries return their entries. Stream objects return the entries of
/// their stream dictionary when that dictionary is itself a `PdfDictionary`.
/// Other objects return `None`.
pub fn PdfObject::dictionary_view(
  self : PdfObject,
) -> ArrayView[(PdfName, PdfObject)]? {
  match self {
    PdfDictionary(entries) => Some(entries)
    PdfStreamObject(stream) =>
      match stream.dictionary {
        PdfDictionary(entries) => Some(entries)
        _ => None
      }
    _ => None
  }
}

///|
/// Look up a key without resolving indirect references.
///
/// Dictionary and stream-dictionary entries are searched in stored order. The
/// returned object is the immediate value stored under `key`; use document-level
/// lookup helpers when indirect references should be resolved.
pub fn PdfObject::lookup_immediate(
  self : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match self.dictionary_view() {
    Some(entries) =>
      for i in 0..<entries.length() {
        let (name, value) = entries[i]
        if name == key {
          break Some(value)
        }
      } nobreak {
        None
      }
    None => None
  }
}

///|
/// Return the object number of an immediate indirect dictionary entry.
///
/// Only plain dictionaries are accepted. Missing keys and non-indirect values
/// return `None`; non-dictionary inputs raise `PdfError::DictionaryExpected`.
pub fn PdfObject::find_indirect(
  self : PdfObject,
  key : PdfName,
) -> Int? raise PdfError {
  match self {
    PdfDictionary(_) =>
      match self.lookup_immediate(key) {
        Some(PdfIndirect(number)) => Some(number)
        _ => None
      }
    _ => raise DictionaryExpected
  }
}
