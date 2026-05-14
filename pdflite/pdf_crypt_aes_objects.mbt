///|
/// Decrypt AESV2 object data bytes with the derived object key.
///
/// `data` must include the leading CBC IV as stored in encrypted PDF strings
/// and streams.
fn pdf_aesv2_decrypt_object_data(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_aes_cbc_decrypt(object_key, data)
}

///|
/// Encrypt bytes as AESV2 object data with an explicit CBC IV.
///
/// The returned bytes include the IV prefix expected by PDF AESV2 strings and
/// streams.
fn pdf_aesv2_encrypt_object_data(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  data : BytesView,
  iv : BytesView,
) -> PdfBytes raise PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_aes_cbc_encrypt_with_iv(object_key, iv, data)
}

///|
/// Decrypt AESV3 object data bytes with the document file key.
///
/// `data` must include the leading CBC IV.
fn pdf_aesv3_decrypt_object_data(
  file_key : BytesView,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_aes_cbc_decrypt(file_key, data)
}

///|
/// Encrypt bytes as AESV3 object data with an explicit CBC IV.
///
/// The returned bytes include the IV prefix expected by PDF AES strings and
/// streams.
fn pdf_aesv3_encrypt_object_data(
  file_key : BytesView,
  data : BytesView,
  iv : BytesView,
) -> PdfBytes raise PdfError {
  pdf_aes_cbc_encrypt_with_iv(file_key, iv, data)
}

///|
fn pdf_aes_next_iv(
  iv_provider : (Int) -> PdfBytes raise PdfError,
  iv_index : Ref[Int],
) -> PdfBytes raise PdfError {
  let iv = iv_provider(iv_index.val)
  iv_index.val += 1
  iv
}

///|
fn pdf_aes_encrypt_pdf_object_with_data_encryptor(
  object : PdfObject,
  iv_provider : (Int) -> PdfBytes raise PdfError,
  iv_index : Ref[Int],
  encrypt_data : (BytesView, BytesView) -> PdfBytes raise PdfError,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  match object {
    PdfString(bytes) => {
      let iv = pdf_aes_next_iv(iv_provider, iv_index)
      PdfString(encrypt_data(bytes, iv))
    }
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(
          pdf_aes_encrypt_pdf_object_with_data_encryptor(
            value,
            iv_provider,
            iv_index,
            encrypt_data,
            no_encrypt_metadata~,
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
            pdf_aes_encrypt_pdf_object_with_data_encryptor(
              value,
              iv_provider,
              iv_index,
              encrypt_data,
              no_encrypt_metadata~,
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
        let dictionary = pdf_aes_encrypt_pdf_object_with_data_encryptor(
          stream.dictionary,
          iv_provider,
          iv_index,
          encrypt_data,
          no_encrypt_metadata~,
        )
        let data = pdf_stream_data_bytes(stream.data)
        let iv = pdf_aes_next_iv(iv_provider, iv_index)
        let encrypted_data = encrypt_data(data, iv)
        PdfStreamObject({
          dictionary: dictionary.add_dict_entry(
            pdf_crypt_stream_length_key(),
            PdfInteger(encrypted_data.length()),
          ),
          data: StreamGot(encrypted_data),
        })
      }
    _ => object
  }
}

///|
/// Encrypt a PDF object using AESV2 with per-object derived keys.
///
/// The IV provider is called with a zero-based index for each encrypted string
/// or stream inside the object. Identity crypt-filter streams are preserved.
fn pdf_aesv2_encrypt_pdf_object_with_iv_provider(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  iv_provider : (Int) -> PdfBytes raise PdfError,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  let iv_index : Ref[Int] = { val: 0 }
  pdf_aes_encrypt_pdf_object_with_data_encryptor(
    object,
    iv_provider,
    iv_index,
    fn(data, iv) raise PdfError {
      pdf_aesv2_encrypt_object_data(
        object_number, generation, file_key, key_length_bits, data, iv,
      )
    },
    no_encrypt_metadata~,
  )
}

///|
/// Encrypt a PDF object using AESV3 with the file key directly.
///
/// The IV provider is called with a zero-based index for each encrypted string
/// or stream inside the object. Identity crypt-filter streams are preserved.
fn pdf_aesv3_encrypt_pdf_object_with_iv_provider(
  file_key : BytesView,
  object : PdfObject,
  iv_provider : (Int) -> PdfBytes raise PdfError,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  let iv_index : Ref[Int] = { val: 0 }
  pdf_aes_encrypt_pdf_object_with_data_encryptor(
    object,
    iv_provider,
    iv_index,
    fn(data, iv) raise PdfError {
      pdf_aesv3_encrypt_object_data(file_key, data, iv)
    },
    no_encrypt_metadata~,
  )
}

///|
fn pdf_aes_decrypt_pdf_object_with_key(
  key : BytesView,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
  deferred_stream_crypt? : PdfStreamDataCrypt = PdfStreamDataNoCrypt,
) -> PdfObject raise PdfError {
  match object {
    PdfString(bytes) => PdfString(pdf_aes_cbc_decrypt(key, bytes))
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(
          pdf_aes_decrypt_pdf_object_with_key(
            key,
            value,
            no_encrypt_metadata~,
            deferred_stream_crypt~,
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
            pdf_aes_decrypt_pdf_object_with_key(
              key,
              value,
              no_encrypt_metadata~,
              deferred_stream_crypt~,
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
        let dictionary = pdf_aes_decrypt_pdf_object_with_key(
          key,
          stream.dictionary,
          no_encrypt_metadata~,
          deferred_stream_crypt~,
        )
        match stream.data {
          StreamToGet(to_get) if to_get.crypt().is_identity() &&
            !deferred_stream_crypt.is_identity() =>
            PdfStreamObject({
              dictionary,
              data: StreamToGet({
                input: to_get.input,
                position: to_get.position,
                length: to_get.length,
                crypt: deferred_stream_crypt.deep_copy(),
              }),
            })
          _ => {
            let data = pdf_stream_data_bytes(stream.data)
            let decrypted_data = pdf_aes_cbc_decrypt(key, data)
            PdfStreamObject({
              dictionary: dictionary.add_dict_entry(
                pdf_crypt_stream_length_key(),
                PdfInteger(decrypted_data.length()),
              ),
              data: StreamGot(decrypted_data),
            })
          }
        }
      }
    _ => object
  }
}

///|
/// Decrypt a PDF object using AESV2 with per-object derived keys.
///
/// Deferred stream data is annotated with AESV2 crypt state so it can be
/// decrypted lazily when the stream bytes are loaded.
fn pdf_aesv2_decrypt_pdf_object(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  pdf_aes_decrypt_pdf_object_with_key(
    object_key,
    object,
    no_encrypt_metadata~,
    deferred_stream_crypt=PdfStreamDataAesV2Decrypt(
      object_number,
      generation,
      file_key.to_owned(),
      key_length_bits,
    ),
  )
}

///|
/// Decrypt a PDF object using AESV3 with the file key directly.
///
/// Deferred stream data is annotated with AESV3 crypt state so it can be
/// decrypted lazily when the stream bytes are loaded.
fn pdf_aesv3_decrypt_pdf_object(
  file_key : BytesView,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  pdf_aes_decrypt_pdf_object_with_key(
    file_key,
    object,
    no_encrypt_metadata~,
    deferred_stream_crypt=PdfStreamDataAesV3Decrypt(file_key.to_owned()),
  )
}
