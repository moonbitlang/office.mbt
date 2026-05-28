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
    PdfArray(values) => {
      let output : Array[PdfObject] = Array::new(capacity=values.length())
      for value in values {
        output.push(value.deep_copy())
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        output.push((entry.0, entry.1.deep_copy()))
      }
      PdfDictionary(output)
    }
    PdfStreamObject(stream) =>
      PdfStreamObject({
        dictionary: stream.dictionary.deep_copy(),
        data: stream.data.deep_copy(),
      })
    _ => self
  }
}
