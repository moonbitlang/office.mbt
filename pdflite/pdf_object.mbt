///|
pub(all) struct ToGet {
  input : ByteCursor
  position : Int
  length : Int
  crypt : PdfStreamDataCrypt
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfStreamData {
  StreamGot(PdfBytes)
  StreamToGet(ToGet)
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfStreamDataCrypt {
  PdfStreamDataNoCrypt
  PdfStreamDataArc4Decrypt(Int, Int, PdfBytes, Int)
  PdfStreamDataAesV2Decrypt(Int, Int, PdfBytes, Int)
  PdfStreamDataAesV3Decrypt(PdfBytes)
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
fn pdf_bytes_physical_copy(bytes : PdfBytes) -> PdfBytes {
  Bytes::makei(bytes.length(), i => bytes[i])
}

///|
fn ByteCursor::deep_copy(self : ByteCursor) -> ByteCursor {
  {
    data: self.data,
    position: self.position,
    offset: self.offset,
    source: self.source,
  }
}

///|
fn PdfStreamDataCrypt::deep_copy(
  self : PdfStreamDataCrypt,
) -> PdfStreamDataCrypt {
  match self {
    PdfStreamDataNoCrypt => PdfStreamDataNoCrypt
    PdfStreamDataArc4Decrypt(
      object_number,
      generation,
      file_key,
      key_length_bits
    ) =>
      PdfStreamDataArc4Decrypt(
        object_number,
        generation,
        pdf_bytes_physical_copy(file_key),
        key_length_bits,
      )
    PdfStreamDataAesV2Decrypt(
      object_number,
      generation,
      file_key,
      key_length_bits
    ) =>
      PdfStreamDataAesV2Decrypt(
        object_number,
        generation,
        pdf_bytes_physical_copy(file_key),
        key_length_bits,
      )
    PdfStreamDataAesV3Decrypt(file_key) =>
      PdfStreamDataAesV3Decrypt(pdf_bytes_physical_copy(file_key))
  }
}

///|
fn PdfStreamData::deep_copy(self : PdfStreamData) -> PdfStreamData {
  match self {
    StreamGot(bytes) => StreamGot(pdf_bytes_physical_copy(bytes))
    StreamToGet(to_get) =>
      StreamToGet({
        input: to_get.input.deep_copy(),
        position: to_get.position,
        length: to_get.length,
        crypt: to_get.crypt.deep_copy(),
      })
  }
}

///|
fn PdfObject::deep_copy(self : PdfObject) -> PdfObject {
  match self {
    PdfArray(values) => PdfArray([ for value in values => value.deep_copy() ])
    PdfDictionary(entries) =>
      PdfDictionary([ for entry in entries => (entry.0, entry.1.deep_copy()) ])
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: stream.dictionary.deep_copy(),
        data: stream.data.deep_copy(),
      })
    _ => self
  }
}

///|
pub fn pdf_array(values : ArrayView[PdfObject]) -> PdfObject {
  PdfArray([ for value in values => value ])
}

///|
pub fn pdf_dictionary(entries : ArrayView[(PdfName, PdfObject)]) -> PdfObject {
  PdfDictionary([ for entry in entries => entry ])
}

///|
pub fn pdf_recurse_array(
  transform : (PdfObject) -> PdfObject,
  values : ArrayView[PdfObject],
) -> PdfObject {
  PdfArray([ for value in values => transform(value) ])
}

///|
pub fn pdf_recurse_dict(
  transform : (PdfObject) -> PdfObject,
  entries : ArrayView[(PdfName, PdfObject)],
  preserve_order? : Bool = false,
) -> PdfObject {
  let transformed : Array[(PdfName, PdfObject)] = [
    for entry in entries => (entry.0, transform(entry.1))
  ]
  if preserve_order {
    PdfDictionary(transformed)
  } else {
    PdfDictionary(transformed.rev())
  }
}

///|
pub fn pdf_stream(dictionary : PdfObject, data : PdfStreamData) -> PdfObject {
  PdfStreamObject({ dictionary, data })
}

///|
pub fn stream_to_get(input : ByteCursor, position : Int, length : Int) -> ToGet {
  { input, position, length, crypt: PdfStreamDataNoCrypt }
}

///|
let pdf_object_length_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Length"),
)

///|
fn pdf_object_length_name() -> PdfName {
  pdf_object_length_key_name
}

///|
fn PdfStreamDataCrypt::is_identity(self : PdfStreamDataCrypt) -> Bool {
  match self {
    PdfStreamDataNoCrypt => true
    _ => false
  }
}

///|
fn PdfStreamDataCrypt::decrypt(
  self : PdfStreamDataCrypt,
  data : BytesView,
) -> PdfBytes raise PdfError {
  match self {
    PdfStreamDataNoCrypt => data.to_owned()
    PdfStreamDataArc4Decrypt(
      object_number,
      generation,
      file_key,
      key_length_bits
    ) =>
      pdf_arc4_crypt_object(
        object_number,
        generation,
        file_key[:],
        key_length_bits,
        data,
      )
    PdfStreamDataAesV2Decrypt(
      object_number,
      generation,
      file_key,
      key_length_bits
    ) =>
      pdf_aesv2_decrypt_object_data(
        object_number,
        generation,
        file_key[:],
        key_length_bits,
        data,
      )
    PdfStreamDataAesV3Decrypt(file_key) =>
      pdf_aesv3_decrypt_object_data(file_key[:], data)
  }
}

///|
fn pdf_stream_to_get_raw_view(to_get : ToGet) -> BytesView raise PdfError {
  let input = to_get.input()
  let start = to_get.position() + input.offset
  let length = to_get.length()
  if start < 0 {
    raise InvalidCursorPosition(to_get.position())
  }
  if length < 0 {
    raise InvalidReadLength(length)
  }
  let end = start + length
  if end > input.data.length() {
    raise EndOfInput
  }
  input.data[start:end]
}

///|
fn pdf_stream_data_view(data : PdfStreamData) -> BytesView raise PdfError {
  match data {
    StreamGot(bytes) => bytes[:]
    StreamToGet(to_get) => {
      let raw = pdf_stream_to_get_raw_view(to_get)
      if to_get.crypt().is_identity() {
        raw
      } else {
        to_get.crypt().decrypt(raw)[:]
      }
    }
  }
}

///|
fn pdf_stream_data_bytes(data : PdfStreamData) -> PdfBytes raise PdfError {
  match data {
    StreamGot(bytes) => bytes
    StreamToGet(to_get) => {
      let raw = pdf_stream_to_get_raw_view(to_get)
      if to_get.crypt().is_identity() {
        raw.to_owned()
      } else {
        to_get.crypt().decrypt(raw)
      }
    }
  }
}

///|
pub fn PdfObject::stream_bytes(self : PdfObject) -> PdfBytes raise PdfError {
  match self {
    PdfStreamObject(stream) => pdf_stream_data_bytes(stream.data)
    _ => raise ParseStreamExpected
  }
}

///|
pub fn PdfObject::get_stream(self : PdfObject) -> Unit raise PdfError {
  match self {
    PdfStreamObject(stream) =>
      match stream.data {
        StreamGot(_) => ()
        StreamToGet(_) => {
          let data = pdf_stream_data_bytes(stream.data)
          match stream.dictionary {
            PdfDictionary(_) =>
              stream.dictionary = stream.dictionary.replace_dict_entry(
                pdf_object_length_name(),
                PdfInteger(data.length()),
              )
            _ => ()
          }
          stream.data = StreamGot(data)
        }
      }
    _ => raise ParseStreamExpected
  }
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
pub fn ToGet::crypt(self : ToGet) -> PdfStreamDataCrypt {
  self.crypt
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
fn pdf_object_unique_key_candidate(prefix : String, index : Int) -> PdfName {
  let output : Array[Byte] = [47]
  for byte in @ascii.encode(prefix) {
    output.push(byte)
  }
  for byte in @ascii.encode(index.to_string()) {
    output.push(byte)
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
