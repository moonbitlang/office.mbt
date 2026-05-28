///|
fn dict_add_entries(
  entries : ArrayView[(PdfName, PdfObject)],
  key : PdfName,
  value : PdfObject,
) -> Array[(PdfName, PdfObject)] {
  let output : Array[(PdfName, PdfObject)] = Array::new(
    capacity=entries.length() + 1,
  )
  for i in 0..<entries.length() {
    let (name, old_value) = entries[i]
    if name == key {
      output.push((key, value))
      for j in (i + 1)..<entries.length() {
        output.push(entries[j])
      }
      break output
    } else {
      output.push((name, old_value))
    }
  } nobreak {
    let reversed : Array[(PdfName, PdfObject)] = Array::new(
      capacity=entries.length() + 1,
    )
    reversed.push((key, value))
    for offset in 0..<entries.length() {
      let i = entries.length() - 1 - offset
      reversed.push(entries[i])
    }
    reversed
  }
}

///|
fn pdf_object_unique_key_candidate(prefix : String, index : Int) -> PdfName {
  let prefix_bytes = @ascii.encode(prefix)
  let index_bytes = @ascii.encode(index.to_string())
  let output = Array::make(
    1 + prefix_bytes.length() + index_bytes.length(),
    b'\x00',
  )
  output[0] = 47
  let mut position = 1
  for byte in prefix_bytes {
    output[position] = byte
    position += 1
  }
  for byte in index_bytes {
    output[position] = byte
    position += 1
  }
  pdf_name_of_bytes(Bytes::from_array(output))
}

///|
fn pdf_object_dictionary_has_key(
  entries : ArrayView[(PdfName, PdfObject)],
  key : PdfName,
) -> Bool {
  for entry in entries {
    if entry.0 == key {
      break true
    }
  } nobreak {
    false
  }
}

///|
/// Generate a dictionary key with the form `/<prefix><n>` that is not in use.
///
/// The scan starts at `n = 0` and increments until the name is absent from the
/// dictionary or stream dictionary. Non-dictionary-like objects raise
/// `PdfError::DictionaryExpected`.
pub fn PdfObject::unique_key(
  self : PdfObject,
  prefix : String,
) -> PdfName raise PdfError {
  match self.dictionary_view() {
    Some(entries) => {
      let mut index = 0
      let mut candidate = pdf_object_unique_key_candidate(prefix, index)
      while pdf_object_dictionary_has_key(entries, candidate) {
        index += 1
        candidate = pdf_object_unique_key_candidate(prefix, index)
      }
      candidate
    }
    None => raise DictionaryExpected
  }
}

///|
fn dict_replace_entries(
  entries : ArrayView[(PdfName, PdfObject)],
  key : PdfName,
  value : PdfObject,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  let output : Array[(PdfName, PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for i in 0..<entries.length() {
    let (name, old_value) = entries[i]
    if name == key {
      output.push((key, value))
      for j in (i + 1)..<entries.length() {
        output.push(entries[j])
      }
      break output
    } else {
      output.push((name, old_value))
    }
  } nobreak {
    raise DictionaryKeyNotFound(key)
  }
}

///|
fn dict_remove_entries(
  entries : ArrayView[(PdfName, PdfObject)],
  key : PdfName,
) -> Array[(PdfName, PdfObject)] {
  let output : Array[(PdfName, PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    let (name, value) = entry
    if name != key {
      output.push((name, value))
    }
  }
  output
}

///|
/// Add or replace a dictionary entry.
///
/// `PdfNull` is promoted to a one-entry dictionary. Existing keys are replaced
/// in place. New keys are inserted using the historical CamlPDF order, which
/// places the new entry before existing entries. Stream objects mutate their
/// stream dictionary and return the same stream object.
pub fn PdfObject::add_dict_entry(
  self : PdfObject,
  key : PdfName,
  value : PdfObject,
) -> PdfObject raise PdfError {
  match self {
    PdfNull => PdfDictionary([(key, value)])
    PdfDictionary(entries) =>
      PdfDictionary(dict_add_entries(entries, key, value))
    PdfStreamObject(stream) => {
      stream.dictionary = stream.dictionary.add_dict_entry(key, value)
      self
    }
    _ => raise DictionaryExpected
  }
}

///|
/// Replace an existing dictionary entry.
///
/// The key must already exist in a plain dictionary or stream dictionary.
/// Missing keys and non-dictionary inputs raise `PdfError::DictionaryKeyNotFound`.
pub fn PdfObject::replace_dict_entry(
  self : PdfObject,
  key : PdfName,
  value : PdfObject,
) -> PdfObject raise PdfError {
  match self {
    PdfDictionary(entries) =>
      PdfDictionary(dict_replace_entries(entries, key, value))
    PdfStreamObject(stream) => {
      stream.dictionary = stream.dictionary.replace_dict_entry(key, value)
      self
    }
    _ => raise DictionaryKeyNotFound(key)
  }
}

///|
/// Remove a dictionary entry if present.
///
/// Missing keys are ignored for dictionaries. Stream objects mutate their stream
/// dictionary and return the same stream object. Non-dictionary inputs raise
/// `PdfError::DictionaryExpected`.
pub fn PdfObject::remove_dict_entry(
  self : PdfObject,
  key : PdfName,
) -> PdfObject raise PdfError {
  match self {
    PdfDictionary(entries) => PdfDictionary(dict_remove_entries(entries, key))
    PdfStreamObject(stream) => {
      stream.dictionary = stream.dictionary.remove_dict_entry(key)
      self
    }
    _ => raise DictionaryExpected
  }
}
