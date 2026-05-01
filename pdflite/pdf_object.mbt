///|
pub(all) struct ToGet {
  input : ByteCursor
  position : Int
  length : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfStreamData {
  StreamGot(PdfBytes)
  StreamToGet(ToGet)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfStream {
  mut dictionary : PdfObject
  mut data : PdfStreamData
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfObject {
  PdfNull
  PdfBoolean(Bool)
  PdfInteger(Int)
  PdfReal(Double)
  PdfString(PdfBytes)
  PdfNameObject(PdfName)
  PdfArray(Array[PdfObject])
  PdfDictionary(Array[(PdfName, PdfObject)])
  PdfStreamObject(PdfStream)
  PdfIndirect(Int)
} derive(Debug, Eq, ToJson)

///|
pub fn pdf_array(values : ArrayView[PdfObject]) -> PdfObject {
  PdfArray([ for value in values => value ])
}

///|
pub fn pdf_dictionary(entries : ArrayView[(PdfName, PdfObject)]) -> PdfObject {
  PdfDictionary([ for entry in entries => entry ])
}

///|
pub fn pdf_stream(dictionary : PdfObject, data : PdfStreamData) -> PdfObject {
  PdfStreamObject({ dictionary, data })
}

///|
pub fn stream_to_get(input : ByteCursor, position : Int, length : Int) -> ToGet {
  { input, position, length }
}

///|
pub fn ToGet::input(self : ToGet) -> ByteCursor {
  self.input
}

///|
pub fn ToGet::position(self : ToGet) -> Int {
  self.position
}

///|
pub fn ToGet::length(self : ToGet) -> Int {
  self.length
}

///|
pub fn PdfObject::dictionary_view(
  self : PdfObject,
) -> ArrayView[(PdfName, PdfObject)]? {
  match self {
    PdfDictionary(entries) => Some(entries[:])
    PdfStreamObject(stream) =>
      match stream.dictionary {
        PdfDictionary(entries) => Some(entries[:])
        _ => None
      }
    _ => None
  }
}

///|
pub fn PdfObject::lookup_immediate(
  self : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match self.dictionary_view() {
    Some(entries) =>
      for i = 0; i < entries.length(); i = i + 1 {
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
fn dict_add_entries(
  entries : ArrayView[(PdfName, PdfObject)],
  key : PdfName,
  value : PdfObject,
) -> Array[(PdfName, PdfObject)] {
  let output : Array[(PdfName, PdfObject)] = []
  for i = 0; i < entries.length(); i = i + 1 {
    let (name, old_value) = entries[i]
    if name == key {
      output.push((key, value))
      for j = i + 1; j < entries.length(); j = j + 1 {
        output.push(entries[j])
      }
      break output
    } else {
      output.push((name, old_value))
    }
  } nobreak {
    let reversed : Array[(PdfName, PdfObject)] = [(key, value)]
    for i = entries.length() - 1; i >= 0; i = i - 1 {
      reversed.push(entries[i])
    }
    reversed
  }
}

///|
fn dict_replace_entries(
  entries : ArrayView[(PdfName, PdfObject)],
  key : PdfName,
  value : PdfObject,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  let output : Array[(PdfName, PdfObject)] = []
  for i = 0; i < entries.length(); i = i + 1 {
    let (name, old_value) = entries[i]
    if name == key {
      output.push((key, value))
      for j = i + 1; j < entries.length(); j = j + 1 {
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
  let output : Array[(PdfName, PdfObject)] = []
  for entry in entries {
    let (name, value) = entry
    if name != key {
      output.push((name, value))
    }
  }
  output
}

///|
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
