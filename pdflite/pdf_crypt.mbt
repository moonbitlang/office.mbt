///|
fn pdf_password_padding_fixed() -> FixedArray[Byte] {
  [
    0x28, 0xbf, 0x4e, 0x5e, 0x4e, 0x75, 0x8a, 0x41, 0x64, 0x00, 0x4e, 0x56, 0xff,
    0xfa, 0x01, 0x08, 0x2e, 0x2e, 0x00, 0xb6, 0xd0, 0x68, 0x3e, 0x80, 0x2f, 0x0c,
    0xa9, 0xfe, 0x64, 0x53, 0x69, 0x7a,
  ]
}

///|
/// Return the standard 32-byte PDF password padding sequence.
pub fn pdf_password_padding() -> PdfBytes {
  Bytes::from_array(pdf_password_padding_fixed())
}

///|
/// Pad or truncate a raw PDF password to 32 bytes.
///
/// Passwords are byte sequences. Inputs longer than 32 bytes are truncated;
/// shorter inputs are filled with the standard PDF padding sequence.
pub fn pdf_pad_password(password : BytesView) -> PdfBytes {
  let padding = pdf_password_padding_fixed()
  let output : Array[Byte] = []
  let copied = if password.length() < 32 { password.length() } else { 32 }
  for index in 0..<copied {
    output.push(password[index])
  }
  for index in copied..<32 {
    output.push(padding[index - copied])
  }
  Bytes::from_array(output)
}

///|
fn pdf_crypt_low_byte(value : Int, shift : Int) -> Byte {
  ((value >> shift) & 0xff).to_byte()
}

///|
fn pdf_crypt_push_view(output : Array[Byte], data : BytesView) -> Unit {
  for byte in data {
    output.push(byte)
  }
}

///|
/// Derive the standard-security file key from a user password.
///
/// This implements revisions 2-4 key derivation. AESV3 uses wrapped file keys
/// instead and should go through the `PdfEncryptionValues` helpers.
pub fn pdf_encryption_file_key(
  no_encrypt_metadata : Bool,
  password : BytesView,
  revision : Int,
  owner_entry : BytesView,
  permissions : Int,
  file_id : BytesView,
  key_length_bits : Int,
) -> PdfBytes {
  let padded_password = pdf_pad_password(password)
  let digest_input : Array[Byte] = []
  pdf_crypt_push_view(digest_input, padded_password)
  pdf_crypt_push_view(digest_input, owner_entry)
  let permissions_bytes : FixedArray[Byte] = [
    pdf_crypt_low_byte(permissions, 0),
    pdf_crypt_low_byte(permissions, 8),
    pdf_crypt_low_byte(permissions, 16),
    pdf_crypt_low_byte(permissions, 24),
  ]
  for byte in permissions_bytes {
    digest_input.push(byte)
  }
  pdf_crypt_push_view(digest_input, file_id)
  if revision >= 4 && no_encrypt_metadata {
    let no_metadata_marker : FixedArray[Byte] = [0xff, 0xff, 0xff, 0xff]
    for byte in no_metadata_marker {
      digest_input.push(byte)
    }
  }
  let key_length = key_length_bits / 8
  let mut hashed = pdf_md5_digest(Bytes::from_array(digest_input))
  if revision >= 3 {
    for _ in 0..<50 {
      hashed = pdf_md5_digest(hashed[:key_length])
    }
  }
  hashed[:key_length].to_owned()
}

///|
fn pdf_key_xor_iteration(key : BytesView, iteration : Int) -> PdfBytes {
  Bytes::makei(key.length(), index => {
    (key[index].to_int() ^ iteration).to_byte()
  })
}

///|
/// Build the `/U` user-password entry for revisions 2-4.
///
/// The entry is derived from the user password, owner entry, permission mask,
/// file ID, key length, and metadata-encryption flag.
pub fn pdf_make_user_password_entry(
  no_encrypt_metadata : Bool,
  user_password : BytesView,
  revision : Int,
  owner_entry : BytesView,
  permissions : Int,
  file_id : BytesView,
  key_length_bits : Int,
) -> PdfBytes raise PdfError {
  let key = pdf_encryption_file_key(
    no_encrypt_metadata, user_password, revision, owner_entry, permissions, file_id,
    key_length_bits,
  )
  if revision == 2 {
    pdf_arc4_crypt(key, pdf_password_padding())
  } else {
    let digest_input : Array[Byte] = []
    pdf_crypt_push_view(digest_input, pdf_password_padding())
    pdf_crypt_push_view(digest_input, file_id)
    let digest = pdf_md5_digest(Bytes::from_array(digest_input))
    let mut encrypted = pdf_arc4_crypt(key, digest)
    for iteration in 1..<20 {
      let iteration_key = pdf_key_xor_iteration(key, iteration)
      encrypted = pdf_arc4_crypt(iteration_key, encrypted)
    }
    let output : Array[Byte] = [ for byte in encrypted => byte ]
    for _ in 0..<16 {
      output.push(0)
    }
    Bytes::from_array(output)
  }
}

///|
fn pdf_bytes_prefix_equal(
  left : BytesView,
  right : BytesView,
  length : Int,
) -> Bool {
  guard left.length() >= length && right.length() >= length else {
    return false
  }
  for index in 0..<length {
    if left[index] != right[index] {
      break false
    }
  } nobreak {
    true
  }
}

///|
/// Authenticate a revision 2-4 user password against a `/U` entry.
pub fn pdf_authenticate_user_password(
  no_encrypt_metadata : Bool,
  user_password : BytesView,
  revision : Int,
  user_entry : BytesView,
  owner_entry : BytesView,
  permissions : Int,
  file_id : BytesView,
  key_length_bits : Int,
) -> Bool raise PdfError {
  let expected = pdf_make_user_password_entry(
    no_encrypt_metadata, user_password, revision, owner_entry, permissions, file_id,
    key_length_bits,
  )
  if revision >= 3 {
    pdf_bytes_prefix_equal(user_entry, expected, 16)
  } else {
    pdf_bytes_prefix_equal(user_entry, expected, expected.length()) &&
    user_entry.length() == expected.length()
  }
}

///|
fn pdf_owner_password_key(
  owner_password : BytesView,
  revision : Int,
  key_length_bits : Int,
) -> PdfBytes {
  let padded_owner = pdf_pad_password(owner_password)
  let mut digest = pdf_md5_digest(padded_owner)
  if revision >= 3 {
    for _ in 0..<50 {
      digest = pdf_md5_digest(digest)
    }
  }
  digest[:key_length_bits / 8].to_owned()
}

///|
/// Build the `/O` owner-password entry for revisions 2-4.
///
/// A blank owner password follows PDF behavior by using the user password as
/// the owner-password source.
pub fn pdf_make_owner_password_entry(
  revision : Int,
  owner_password : BytesView,
  user_password : BytesView,
  key_length_bits : Int,
) -> PdfBytes raise PdfError {
  let source_password = if owner_password.length() == 0 {
    user_password
  } else {
    owner_password
  }
  let key = pdf_owner_password_key(source_password, revision, key_length_bits)
  let padded_user = pdf_pad_password(user_password)
  if revision == 2 {
    pdf_arc4_crypt(key, padded_user)
  } else {
    let mut encrypted = pdf_arc4_crypt(key, padded_user)
    for iteration in 1..<20 {
      let iteration_key = pdf_key_xor_iteration(key, iteration)
      encrypted = pdf_arc4_crypt(iteration_key, encrypted)
    }
    encrypted
  }
}

///|
/// Recover the padded user-password bytes from a revision 2-4 owner password.
///
/// The returned bytes are the padded/truncated internal password form, not a
/// decoded MoonBit string.
pub fn pdf_user_password_from_owner_password(
  revision : Int,
  owner_password : BytesView,
  owner_entry : BytesView,
  key_length_bits : Int,
) -> PdfBytes raise PdfError {
  let key = pdf_owner_password_key(owner_password, revision, key_length_bits)
  if revision == 2 {
    pdf_arc4_crypt(key, owner_entry)
  } else {
    let mut decrypted = owner_entry.to_owned()
    let mut iteration = 19
    while iteration >= 0 {
      let iteration_key = pdf_key_xor_iteration(key, iteration)
      decrypted = pdf_arc4_crypt(iteration_key, decrypted)
      iteration -= 1
    }
    decrypted
  }
}

///|
/// Authenticate a revision 2-4 owner password.
///
/// This decrypts the owner entry to recover the padded user password and then
/// validates that recovered password against the user entry.
pub fn pdf_authenticate_owner_password(
  no_encrypt_metadata : Bool,
  owner_password : BytesView,
  revision : Int,
  user_entry : BytesView,
  owner_entry : BytesView,
  permissions : Int,
  file_id : BytesView,
  key_length_bits : Int,
) -> Bool raise PdfError {
  let user_password = pdf_user_password_from_owner_password(
    revision, owner_password, owner_entry, key_length_bits,
  )
  pdf_authenticate_user_password(
    no_encrypt_metadata, user_password, revision, user_entry, owner_entry, permissions,
    file_id, key_length_bits,
  )
}

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

///|
/// Apply ARC4 crypt to all parsed objects in a copied document.
///
/// `skip_object_number` is used to leave the encryption dictionary itself
/// unencrypted. Deferred and object-stream placeholders are left untouched.
pub fn PdfDocument::arc4_crypt_parsed_objects(
  self : PdfDocument,
  file_key : BytesView,
  key_length_bits : Int,
  no_encrypt_metadata? : Bool = false,
  skip_object_number? : Int = 0,
) -> PdfDocument raise PdfError {
  let output = self.copy()
  for number in output.object_numbers() {
    if number != skip_object_number {
      let entry = output.objects.get_entry(number).unwrap()
      match entry.data {
        ObjectParsed(object) =>
          output.objects.set_entry(number, {
            data: ObjectParsed(
              pdf_arc4_crypt_pdf_object_with_stream_policy(
                number,
                entry.generation,
                file_key,
                key_length_bits,
                object,
                no_encrypt_metadata,
                true,
              ),
            ),
            generation: entry.generation,
          })
        ObjectParsedAlreadyDecrypted(_)
        | ObjectToParse
        | ObjectToParseFromObjectStream(_) => ()
      }
    }
  }
  output
}

///|
/// AESV2-encrypt all parsed objects in a copied document.
///
/// The IV provider receives object number, generation, and per-object IV index.
/// `skip_object_number` leaves the encryption dictionary unencrypted.
pub fn PdfDocument::aesv2_encrypt_parsed_objects_with_iv_provider(
  self : PdfDocument,
  file_key : BytesView,
  key_length_bits : Int,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  no_encrypt_metadata? : Bool = false,
  skip_object_number? : Int = 0,
) -> PdfDocument raise PdfError {
  let output = self.copy()
  for number in output.object_numbers() {
    if number != skip_object_number {
      let entry = output.objects.get_entry(number).unwrap()
      match entry.data {
        ObjectParsed(object) =>
          output.objects.set_entry(number, {
            data: ObjectParsed(
              pdf_aesv2_encrypt_pdf_object_with_iv_provider(
                number,
                entry.generation,
                file_key,
                key_length_bits,
                object,
                fn(index) raise PdfError {
                  iv_provider(number, entry.generation, index)
                },
                no_encrypt_metadata~,
              ),
            ),
            generation: entry.generation,
          })
        ObjectParsedAlreadyDecrypted(_)
        | ObjectToParse
        | ObjectToParseFromObjectStream(_) => ()
      }
    }
  }
  output
}

///|
/// AESV2-decrypt all parsed objects in a copied document.
///
/// Parsed streams may retain deferred crypt metadata so stream bytes can be
/// decrypted lazily. `skip_object_number` leaves the encryption dictionary
/// untouched.
pub fn PdfDocument::aesv2_decrypt_parsed_objects(
  self : PdfDocument,
  file_key : BytesView,
  key_length_bits : Int,
  no_encrypt_metadata? : Bool = false,
  skip_object_number? : Int = 0,
) -> PdfDocument raise PdfError {
  let output = self.copy()
  for number in output.object_numbers() {
    if number != skip_object_number {
      let entry = output.objects.get_entry(number).unwrap()
      match entry.data {
        ObjectParsed(object) =>
          output.objects.set_entry(number, {
            data: ObjectParsed(
              pdf_aesv2_decrypt_pdf_object(
                number,
                entry.generation,
                file_key,
                key_length_bits,
                object,
                no_encrypt_metadata~,
              ),
            ),
            generation: entry.generation,
          })
        ObjectParsedAlreadyDecrypted(_)
        | ObjectToParse
        | ObjectToParseFromObjectStream(_) => ()
      }
    }
  }
  output
}

///|
/// AESV3-encrypt all parsed objects in a copied document.
///
/// The IV provider receives object number, generation, and per-object IV index.
/// `skip_object_number` leaves the encryption dictionary unencrypted.
pub fn PdfDocument::aesv3_encrypt_parsed_objects_with_iv_provider(
  self : PdfDocument,
  file_key : BytesView,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  no_encrypt_metadata? : Bool = false,
  skip_object_number? : Int = 0,
) -> PdfDocument raise PdfError {
  let output = self.copy()
  for number in output.object_numbers() {
    if number != skip_object_number {
      let entry = output.objects.get_entry(number).unwrap()
      match entry.data {
        ObjectParsed(object) =>
          output.objects.set_entry(number, {
            data: ObjectParsed(
              pdf_aesv3_encrypt_pdf_object_with_iv_provider(
                file_key,
                object,
                fn(index) raise PdfError {
                  iv_provider(number, entry.generation, index)
                },
                no_encrypt_metadata~,
              ),
            ),
            generation: entry.generation,
          })
        ObjectParsedAlreadyDecrypted(_)
        | ObjectToParse
        | ObjectToParseFromObjectStream(_) => ()
      }
    }
  }
  output
}

///|
/// AESV3-decrypt all parsed objects in a copied document.
///
/// Parsed streams may retain deferred crypt metadata so stream bytes can be
/// decrypted lazily. `skip_object_number` leaves the encryption dictionary
/// untouched.
pub fn PdfDocument::aesv3_decrypt_parsed_objects(
  self : PdfDocument,
  file_key : BytesView,
  no_encrypt_metadata? : Bool = false,
  skip_object_number? : Int = 0,
) -> PdfDocument raise PdfError {
  let output = self.copy()
  for number in output.object_numbers() {
    if number != skip_object_number {
      let entry = output.objects.get_entry(number).unwrap()
      match entry.data {
        ObjectParsed(object) =>
          output.objects.set_entry(number, {
            data: ObjectParsed(
              pdf_aesv3_decrypt_pdf_object(
                file_key,
                object,
                no_encrypt_metadata~,
              ),
            ),
            generation: entry.generation,
          })
        ObjectParsedAlreadyDecrypted(_)
        | ObjectToParse
        | ObjectToParseFromObjectStream(_) => ()
      }
    }
  }
  output
}
