///|
let pdf_object_length_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  @ascii.encode("/Length"),
)

///|
/// Return the canonical `/Length` name used by stream dictionaries.
pub fn pdf_object_length_name() -> @core.PdfName {
  pdf_object_length_key_name
}

///|
/// Return whether this stream crypt policy leaves bytes unchanged.
pub fn PdfStreamDataCrypt::is_identity(self : PdfStreamDataCrypt) -> Bool {
  match self {
    PdfStreamDataNoCrypt => true
    _ => false
  }
}

///|
/// Decrypt one deferred stream-data view using this stream crypt policy.
pub fn PdfStreamDataCrypt::decrypt(
  self : PdfStreamDataCrypt,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
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
fn pdf_stream_to_get_raw_view(to_get : ToGet) -> BytesView raise @core.PdfError {
  let input = to_get.input()
  if to_get.position() < 0 {
    raise InvalidCursorPosition(to_get.position())
  }
  input.view_at(to_get.position(), to_get.length())
}

///|
/// Borrow or materialize stream data as a byte view.
pub fn pdf_stream_data_view(
  data : PdfStreamData,
) -> BytesView raise @core.PdfError {
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
/// Return stream data as owned bytes, decrypting deferred data when needed.
pub fn pdf_stream_data_bytes(
  data : PdfStreamData,
) -> @core.PdfBytes raise @core.PdfError {
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
/// Non-stream objects raise `@core.PdfError::ParseStreamExpected`.
pub fn PdfObject::stream_bytes(
  self : PdfObject,
) -> @core.PdfBytes raise @core.PdfError {
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
/// Non-stream objects raise `@core.PdfError::ParseStreamExpected`.
pub fn PdfObject::get_stream(self : PdfObject) -> Unit raise @core.PdfError {
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
