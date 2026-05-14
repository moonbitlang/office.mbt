///|
fn pdf_crypt_stream_length_key() -> PdfName {
  pdf_name_of_bytes(@ascii.encode("/Length"))
}

///|
fn pdf_crypt_stream_filter_key() -> PdfName {
  pdf_crypt_filter_name
}

///|
fn pdf_crypt_stream_decodeparms_key() -> PdfName {
  pdf_crypt_decodeparms_name
}

///|
fn pdf_crypt_stream_name_key() -> PdfName {
  pdf_crypt_name_key_name
}

///|
fn pdf_crypt_stream_type_key() -> PdfName {
  pdf_crypt_type_name
}

///|
fn pdf_crypt_object_is_name(object : PdfObject?, expected : PdfName) -> Bool {
  match object {
    Some(PdfNameObject(name)) => name == expected
    _ => false
  }
}

///|
fn pdf_crypt_first_filter_is_crypt(dictionary : PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_crypt_stream_filter_key()) {
    Some(PdfNameObject(name)) => name == pdf_crypt_crypt_name
    Some(PdfArray([PdfNameObject(name), ..])) => name == pdf_crypt_crypt_name
    _ => false
  }
}

///|
fn pdf_crypt_decodeparms_is_identity(dictionary : PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_crypt_stream_decodeparms_key()) {
    Some(PdfDictionary(_) as decodeparms)
    | Some(PdfArray([PdfDictionary(_) as decodeparms, ..])) =>
      match decodeparms.lookup_immediate(pdf_crypt_stream_name_key()) {
        Some(PdfNameObject(name)) => name == pdf_crypt_identity_name
        None => true
        _ => false
      }
    _ => true
  }
}

///|
fn pdf_crypt_stream_is_identity(
  no_encrypt_metadata : Bool,
  dictionary : PdfObject,
) -> Bool {
  if no_encrypt_metadata &&
    pdf_crypt_object_is_name(
      dictionary.lookup_immediate(pdf_crypt_stream_type_key()),
      pdf_crypt_metadata_name,
    ) {
    true
  } else {
    pdf_crypt_first_filter_is_crypt(dictionary) &&
    pdf_crypt_decodeparms_is_identity(dictionary)
  }
}

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
        pdf_arc4_crypt_object(
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
            let encrypted_data = pdf_arc4_crypt_object(
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
pub fn pdf_arc4_crypt_pdf_object(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  pdf_arc4_crypt_pdf_object_with_stream_policy(
    object_number, generation, file_key, key_length_bits, object, no_encrypt_metadata,
    false,
  )
}

///|
/// Decrypt AESV2 object data bytes with the derived object key.
///
/// `data` must include the leading CBC IV as stored in encrypted PDF strings
/// and streams.
pub fn pdf_aesv2_decrypt_object_data(
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
pub fn pdf_aesv2_encrypt_object_data(
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
pub fn pdf_aesv3_decrypt_object_data(
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
pub fn pdf_aesv3_encrypt_object_data(
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
fn pdf_aes_encrypt_pdf_object_with_key(
  key : BytesView,
  object : PdfObject,
  iv_provider : (Int) -> PdfBytes raise PdfError,
  iv_index : Ref[Int],
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  match object {
    PdfString(bytes) => {
      let iv = pdf_aes_next_iv(iv_provider, iv_index)
      PdfString(pdf_aes_cbc_encrypt_with_iv(key, iv, bytes))
    }
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(
          pdf_aes_encrypt_pdf_object_with_key(
            key,
            value,
            iv_provider,
            iv_index,
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
            pdf_aes_encrypt_pdf_object_with_key(
              key,
              value,
              iv_provider,
              iv_index,
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
        let dictionary = pdf_aes_encrypt_pdf_object_with_key(
          key,
          stream.dictionary,
          iv_provider,
          iv_index,
          no_encrypt_metadata~,
        )
        let data = pdf_stream_data_bytes(stream.data)
        let iv = pdf_aes_next_iv(iv_provider, iv_index)
        let encrypted_data = pdf_aes_cbc_encrypt_with_iv(key, iv, data)
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
pub fn pdf_aesv2_encrypt_pdf_object_with_iv_provider(
  object_number : Int,
  generation : Int,
  file_key : BytesView,
  key_length_bits : Int,
  object : PdfObject,
  iv_provider : (Int) -> PdfBytes raise PdfError,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  let object_key = pdf_encryption_object_key(
    PdfCryptAESV2,
    object_number,
    generation,
    file_key,
    key_length_bits,
  )
  let iv_index : Ref[Int] = { val: 0 }
  pdf_aes_encrypt_pdf_object_with_key(
    object_key,
    object,
    iv_provider,
    iv_index,
    no_encrypt_metadata~,
  )
}

///|
/// Encrypt a PDF object using AESV3 with the file key directly.
///
/// The IV provider is called with a zero-based index for each encrypted string
/// or stream inside the object. Identity crypt-filter streams are preserved.
pub fn pdf_aesv3_encrypt_pdf_object_with_iv_provider(
  file_key : BytesView,
  object : PdfObject,
  iv_provider : (Int) -> PdfBytes raise PdfError,
  no_encrypt_metadata? : Bool = false,
) -> PdfObject raise PdfError {
  let iv_index : Ref[Int] = { val: 0 }
  pdf_aes_encrypt_pdf_object_with_key(
    file_key,
    object,
    iv_provider,
    iv_index,
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
pub fn pdf_aesv2_decrypt_pdf_object(
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
pub fn pdf_aesv3_decrypt_pdf_object(
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
