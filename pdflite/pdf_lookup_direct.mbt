///|
fn PdfDocument::direct_depth(
  self : PdfDocument,
  object : PdfObject,
  depth : Int,
) -> PdfObject {
  if depth > 1024 {
    PdfNull
  } else {
    match object {
      PdfIndirect(number) =>
        match self.objects.get_entry(number) {
          Some({ data: ObjectParsed(value), .. }) =>
            self.direct_depth(value, depth + 1)
          Some({ data: ObjectParsedAlreadyDecrypted(value), .. }) =>
            self.direct_depth(value, depth + 1)
          _ => PdfNull
        }
      _ => object
    }
  }
}

///|
/// Resolve an object through the document object table.
///
/// Direct objects are returned unchanged. Indirect references are followed
/// recursively through parsed entries in `self.objects`; missing, unparsed, or
/// excessively deep references resolve to `PdfNull` rather than raising.
pub fn PdfDocument::direct(self : PdfDocument, object : PdfObject) -> PdfObject {
  self.direct_depth(object, 0)
}

///|
/// Look up `key` in a dictionary or stream dictionary and resolve the value.
///
/// The containing object is first passed through `direct`. If the object is not
/// dictionary-like, the key is absent, or the resolved value is `PdfNull`, this
/// returns `None`.
pub fn PdfDocument::lookup_direct(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
) -> PdfObject? {
  match self.direct(object).dictionary_view() {
    Some(entries) =>
      for i in 0..<entries.length() {
        let (name, value) = entries[i]
        if name == key {
          let direct_value = self.direct(value)
          break if direct_value == PdfNull { None } else { Some(direct_value) }
        }
      } nobreak {
        None
      }
    None => None
  }
}

///|
/// Look up a required dictionary entry and resolve the value.
///
/// This is the raising counterpart to `lookup_direct`: it raises the caller
/// supplied `error` when the containing object is not dictionary-like, when the
/// key is absent, or when the resolved value is `PdfNull`.
pub fn PdfDocument::lookup_required(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
  error : PdfError,
) -> PdfObject raise PdfError {
  match self.direct(object).dictionary_view() {
    Some(entries) =>
      for entry in entries {
        if entry.0 == key {
          let direct_value = self.direct(entry.1)
          break if direct_value == PdfNull { raise error } else { direct_value }
        }
      } nobreak {
        raise error
      }
    None => raise error
  }
}

///|
/// Look up either of two alternative dictionary keys.
///
/// `first_key` is preferred. `second_key` is checked only when the first lookup
/// is absent or resolves to `PdfNull`.
pub fn PdfDocument::lookup_direct_or_else(
  self : PdfDocument,
  first_key : PdfName,
  second_key : PdfName,
  object : PdfObject,
) -> PdfObject? {
  match self.lookup_direct(first_key, object) {
    Some(value) => Some(value)
    None => self.lookup_direct(second_key, object)
  }
}

///|
fn pdf_lookup_array_index_name(name : PdfName) -> Int? {
  let bytes = name.bytes()
  guard bytes.length() >= 3 &&
    bytes[0].to_int() == 47 &&
    bytes[1].to_int() == 91 else {
    return None
  }
  let first = bytes[2].to_int()
  guard first >= 48 && first <= 57 else { return None }
  let mut value = 0
  let mut index = 2
  while index < bytes.length() {
    let byte = bytes[index].to_int()
    if byte < 48 || byte > 57 {
      break
    }
    value = value * 10 + byte - 48
    index += 1
  }
  Some(value)
}

///|
/// Look up a dictionary entry, or address an array by a pseudo-key.
///
/// Names that begin with `/[` followed by decimal digits are treated as array
/// indexes when `object` is a `PdfArray`; other names are resolved with
/// `lookup_direct`. The returned value is resolved through `direct`.
pub fn PdfDocument::lookup_direct_or_array(
  self : PdfDocument,
  name : PdfName,
  object : PdfObject,
) -> PdfObject? {
  match pdf_lookup_array_index_name(name) {
    Some(index) =>
      match object {
        PdfArray(values) =>
          match values.get(index) {
            Some(value) => Some(self.direct(value))
            None => None
          }
        _ => None
      }
    None => self.lookup_direct(name, object)
  }
}

///|
/// Return the indirect object number stored under a dictionary key.
///
/// The containing object is resolved before lookup, but the entry itself is
/// inspected before dereferencing. This returns `Some(number)` only when the
/// immediate entry value is `PdfIndirect(number)`.
pub fn PdfDocument::indirect_number(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
) -> Int? {
  match self.direct(object).dictionary_view() {
    Some(entries) =>
      for entry in entries {
        if entry.0 == key {
          break match entry.1 {
            PdfIndirect(number) => Some(number)
            _ => None
          }
        }
      } nobreak {
        None
      }
    None => None
  }
}
