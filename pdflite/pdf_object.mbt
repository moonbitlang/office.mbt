///|
/// A deferred stream-data slice read from an input cursor.
///
/// `position` and `length` identify the raw byte range in `input`; `crypt`
/// records the decryption operation to apply when the bytes are materialized.
/// This lets the reader keep large stream bodies lazy until a caller requests
/// their bytes.
pub(all) struct ToGet {
  input : ByteCursor
  position : Int
  length : Int
  crypt : PdfStreamDataCrypt
} derive(Debug, Eq, ToJson)

///|
/// Storage state for a PDF stream body.
///
/// `StreamGot` stores already materialized bytes. `StreamToGet` stores a
/// deferred slice of an input buffer, optionally with stream decryption metadata
/// that is applied when the data is read.
pub(all) enum PdfStreamData {
  StreamGot(PdfBytes)
  StreamToGet(ToGet)
} derive(Debug, Eq, ToJson)

///|
/// Decryption metadata associated with deferred stream data.
///
/// The variants correspond to the stream ciphers supported by the PDF security
/// handler. Object-specific ciphers store object number, generation, file key,
/// and key length; AES-V3 stores the already derived file key.
pub(all) enum PdfStreamDataCrypt {
  PdfStreamDataNoCrypt
  PdfStreamDataArc4Decrypt(Int, Int, PdfBytes, Int)
  PdfStreamDataAesV2Decrypt(Int, Int, PdfBytes, Int)
  PdfStreamDataAesV3Decrypt(PdfBytes)
} derive(Debug, Eq, ToJson)

///|
/// A PDF stream object: dictionary metadata plus stream bytes.
///
/// The dictionary and data fields are mutable because helpers such as
/// `get_stream` and the dictionary update methods materialize stream data and
/// update stream dictionaries in place.
pub(all) struct PdfStream {
  mut dictionary : PdfObject
  mut data : PdfStreamData
} derive(Debug, Eq, ToJson)

///|
/// The core in-memory representation of a parsed PDF object.
///
/// Strings and names are byte-oriented PDF values, not MoonBit Unicode strings.
/// `PdfIndirect(number)` is an unresolved reference by object number; callers
/// that need the referenced object should resolve it through a `PdfDocument`.
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
/// Construct a PDF array from a read-only view of object values.
///
/// The outer array is newly allocated, but the contained `PdfObject` values are
/// copied by value rather than deep-copied.
pub fn pdf_array(values : ArrayView[PdfObject]) -> PdfObject {
  PdfArray([ for value in values => value ])
}

///|
/// Construct a PDF dictionary from a read-only view of name/value entries.
///
/// Entry order is preserved exactly as supplied. Duplicate keys are not
/// normalized by this constructor; lookup helpers return the first matching
/// entry.
pub fn pdf_dictionary(entries : ArrayView[(PdfName, PdfObject)]) -> PdfObject {
  PdfDictionary([ for entry in entries => entry ])
}

///|
/// Apply a one-level transformation to array elements.
///
/// This helper does not recursively traverse nested dictionaries or arrays by
/// itself; callers provide a `transform` that decides how each child object is
/// rewritten.
pub fn pdf_recurse_array(
  transform : (PdfObject) -> PdfObject,
  values : ArrayView[PdfObject],
) -> PdfObject {
  PdfArray([ for value in values => transform(value) ])
}

///|
/// Apply a one-level transformation to dictionary values.
///
/// By default the resulting dictionary entries are reversed to match the
/// historical CamlPDF construction order. Pass `preserve_order=true` when the
/// incoming order must be retained.
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
/// Construct a PDF stream object from a dictionary object and stream data.
///
/// The dictionary is stored as supplied. It is normally a `PdfDictionary`, but
/// malformed inputs can carry other objects and will be reported by helpers that
/// require dictionary metadata.
pub fn pdf_stream(dictionary : PdfObject, data : PdfStreamData) -> PdfObject {
  PdfStreamObject({ dictionary, data })
}

///|
/// Construct a deferred stream-data descriptor without encryption.
///
/// The returned value references `input` and reads `length` bytes starting at
/// `position` when materialized.
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
      @crypt_core.pdf_arc4_crypt_object(
        object_number, generation, file_key, key_length_bits, data,
      )
    PdfStreamDataAesV2Decrypt(
      object_number,
      generation,
      file_key,
      key_length_bits
    ) =>
      @crypt_core.pdf_aesv2_decrypt_object_data(
        object_number, generation, file_key, key_length_bits, data,
      )
    PdfStreamDataAesV3Decrypt(file_key) =>
      @crypt_core.pdf_aesv3_decrypt_object_data(file_key, data)
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
    StreamGot(bytes) => bytes
    StreamToGet(to_get) => {
      let raw = pdf_stream_to_get_raw_view(to_get)
      if to_get.crypt().is_identity() {
        raw
      } else {
        to_get.crypt().decrypt(raw)
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
/// Return a stream object's materialized bytes.
///
/// `StreamGot` data is returned directly. Deferred `StreamToGet` data is read
/// from its source cursor and decrypted if necessary, but this method does not
/// mutate the stream object or update `/Length`; use `get_stream` for that.
/// Non-stream objects raise `PdfError::ParseStreamExpected`.
pub fn PdfObject::stream_bytes(self : PdfObject) -> PdfBytes raise PdfError {
  match self {
    PdfStreamObject(stream) => pdf_stream_data_bytes(stream.data)
    _ => raise ParseStreamExpected
  }
}

///|
/// Materialize a stream in place.
///
/// Deferred stream data is read, decrypted if needed, stored back as
/// `StreamGot`, and `/Length` is corrected when the stream dictionary is a PDF
/// dictionary. Calling this on an already materialized stream is a no-op.
/// Non-stream objects raise `PdfError::ParseStreamExpected`.
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
/// Return the source cursor used by a deferred stream slice.
pub fn ToGet::input(self : ToGet) -> ByteCursor {
  self.input
}

///|
/// Return the start position of a deferred stream slice.
///
/// The value is interpreted relative to the `ByteCursor`'s offset when the
/// stream is materialized.
pub fn ToGet::position(self : ToGet) -> Int {
  self.position
}

///|
/// Return the byte length of a deferred stream slice.
pub fn ToGet::length(self : ToGet) -> Int {
  self.length
}

///|
/// Return the decryption metadata for a deferred stream slice.
pub fn ToGet::crypt(self : ToGet) -> PdfStreamDataCrypt {
  self.crypt
}

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
