///|
fn pdf_arc4_crypt_pdf_object_with_stream_policy(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  no_encrypt_metadata : Bool,
  defer_stream_decryption : Bool,
) -> PdfObject raise PdfError {
  match object {
    PdfString(bytes) =>
      PdfString(
        @crypt_core.pdf_arc4_crypt_object(
          object_number, generation, file_key, key_length_bits, bytes,
        ),
      )
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(
          pdf_arc4_crypt_pdf_object_with_stream_policy(
            object_number, generation, file_key, key_length_bits, value, no_encrypt_metadata,
            defer_stream_decryption,
          ),
        )
      }
      PdfArray(output)
    }
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (name, value) = entry
        output.push(
          (
            name,
            pdf_arc4_crypt_pdf_object_with_stream_policy(
              object_number, generation, file_key, key_length_bits, value, no_encrypt_metadata,
              defer_stream_decryption,
            ),
          ),
        )
      }
      PdfDictionary(output)
    }
    PdfStreamObject(stream) =>
      if pdf_crypt_stream_is_identity(no_encrypt_metadata, stream.dictionary) {
        object
      } else {
        let dictionary = pdf_arc4_crypt_pdf_object_with_stream_policy(
          object_number,
          generation,
          file_key,
          key_length_bits,
          stream.dictionary,
          no_encrypt_metadata,
          defer_stream_decryption,
        )
        match stream.data {
          StreamToGet(to_get) if defer_stream_decryption &&
            to_get.crypt().is_identity() =>
            PdfStreamObject({
              dictionary,
              data: StreamToGet({
                input: to_get.input,
                position: to_get.position,
                length: to_get.length,
                crypt: PdfStreamDataArc4Decrypt(
                  object_number,
                  generation,
                  file_key.to_owned(),
                  key_length_bits,
                ),
              }),
            })
          _ => {
            let data = pdf_stream_data_bytes(stream.data)
            let encrypted_data = @crypt_core.pdf_arc4_crypt_object(
              object_number, generation, file_key, key_length_bits, data,
            )
            PdfStreamObject({
              dictionary: dictionary.add_dict_entry(
                pdf_crypt_stream_length_key(),
                PdfInteger(encrypted_data.length()),
              ),
              data: StreamGot(encrypted_data),
            })
          }
        }
      }
    _ => object
  }
}

///|
/// Apply ARC4 object encryption or decryption to a PDF object.
///
/// ARC4 is symmetric. The object key is derived from object number,
/// generation, file key, and key length. Streams using identity crypt filters,
/// and metadata streams when `no_encrypt_metadata=true`, are left unchanged.
fn pdf_arc4_crypt_pdf_object(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  no_encrypt_metadata : Bool,
) -> PdfObject raise PdfError {
  pdf_arc4_crypt_pdf_object_with_stream_policy(
    object_number, generation, file_key, key_length_bits, object, no_encrypt_metadata,
    false,
  )
}
